import Foundation
import GRDB

public let dbPool: DatabasePool = {
    do {
        let pool = try DatabasePool(path: "inversion.db")
        try pool.writeWithoutTransaction { db in
            for pragma in Migrations.pragmas {
                try db.execute(sql: pragma)
            }
        }
        try runMigrations(pool)
        return pool
    } catch {
        fatalError("Failed to initialize database: \(error)")
    }
}()

private func runMigrations(_ pool: DatabasePool) throws {
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
                sql: "INSERT INTO migrations (name) VALUES (?)", arguments: [firstMigration.name])
        }
        let applied: Set<String> = Set(try String.fetchAll(db, sql: "SELECT name FROM migrations"))
        for migration in migrations where !applied.contains(migration.name) {
            print("Running database migration: \(migration.name)")
            try db.execute(sql: migration.sql)
            try db.execute(
                sql: "INSERT INTO migrations (name) VALUES (?)", arguments: [migration.name])
        }
        print("All database migrations complete.")
    }
}
