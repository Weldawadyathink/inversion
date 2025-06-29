import Foundation
import GRDB

// Class isn't real, should never be initialized. All functions are static
final class Database {
    static let pool: DatabasePool = {
        do {
            let pool = try DatabasePool(path: "inversion.db")
            try pool.writeWithoutTransaction { db in
                for pragma in Migrations.pragmas {
                    try db.execute(sql: pragma)
                }
            }
            try Database.runMigrations(pool)
            return pool
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }()

    private static func runMigrations(_ pool: DatabasePool) throws {
        let migrations = Migrations.all
        guard let firstMigration = migrations.first else { return }
        try pool.write { db in
            let tableExists =
                try Bool.fetchOne(
                    db, sql: "SELECT 1 FROM sqlite_master WHERE type='table' AND name='migrations'")
                ?? false
            if !tableExists {
                print("Running database migration: \(firstMigration.name)")
                try db.execute(sql: firstMigration.sql)
                try db.execute(
                    sql: "INSERT INTO migrations (name) VALUES (?)",
                    arguments: [firstMigration.name])
            }
            let applied: Set<String> = Set(
                try String.fetchAll(db, sql: "SELECT name FROM migrations"))
            for migration in migrations where !applied.contains(migration.name) {
                print("Running database migration: \(migration.name)")
                try db.execute(sql: migration.sql)
                try db.execute(
                    sql: "INSERT INTO migrations (name) VALUES (?)", arguments: [migration.name])
            }
        }
    }

    static func saveParity(parities: [Data]) throws {
        try Database.pool.write { db in
            try db.execute(sql: "DELETE FROM blocks")
            for (i, parity) in parities.enumerated() {
                try db.execute(
                    sql: "INSERT INTO blocks (block_number, parity_bits) VALUES (?, ?)",
                    arguments: [i, parity])
            }
        }
    }

    static func getParities() throws -> [Data] {
        try Database.pool.read { db in
            let rows = try Row.fetchAll(
                db, sql: "SELECT block_number, parity_bits FROM blocks ORDER BY block_number ASC")
            return rows.map { $0["parity_bits"] }
        }
    }
}
