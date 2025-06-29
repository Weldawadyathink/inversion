import Foundation
import GRDB

@globalActor
enum DBActor {
  static let shared = Actor()
  actor Actor {}
}

struct DBFileBlock: Codable, FetchableRecord, PersistableRecord, Sendable {
  let fileId: Int64?
  let blockNumber: Int64?
  let parityBits: Data?
  static let databaseTableName = "file_block"
}

// let pragmas: [String] = [
//     "PRAGMA foreign_keys = ON;",
//     "PRAGMA journal_mode = WAL;",
//     "PRAGMA synchronous = NORMAL;",
//     "PRAGMA cache_size = -2048;",
//     "PRAGMA temp_store = MEMORY;",
//     "PRAGMA mmap_size = 268435456;",
//     "PRAGMA recursive_triggers = ON;",
//     "PRAGMA case_sensitive_like = ON;",
//     "PRAGMA integrity_check;",
// ]

@DBActor
final class Database {
  private static var _pool: DatabasePool?

  private static var migrator: DatabaseMigrator = {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("create_hamming_parity_storage") { db in
      try db.create(table: "file") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("filename", .text).notNull()
        t.column("size", .integer).notNull()
        t.column("hash", .text).notNull()
      }
      try db.create(table: "file_part") { t in
        t.column("file_id", .integer).notNull().references("file", onDelete: .cascade)
        t.column("block_number", .integer).notNull()
        t.column("parity_bits", .blob).notNull()
      }
      try db.create(
        indexOn: "file_part", columns: ["file_id", "block_number"], options: .unique)
    }
    return migrator
  }()

  init() throws {
    if Database._pool == nil {
      Database._pool = try DatabasePool(path: "inversion.db")
      try Database.migrator.migrate(Database._pool!)
    }
  }

  var pool: DatabasePool {
    return Database._pool!
  }
}
