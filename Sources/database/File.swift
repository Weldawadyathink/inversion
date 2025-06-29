import Foundation
import GRDB

struct DBFile: TableRecord, FetchableRecord, PersistableRecord, Sendable {
  let id: Int64?
  let externalFilename: String?
  let internalFilename: String?
  let size: Int64?
  let hash: String?
  static let databaseTableName = "file"

  enum Columns {
    static let id = Column("id")
    static let externalFilename = Column("external_filename")
    static let internalFilename = Column("internal_filename")
    static let size = Column("size")
    static let hash = Column("hash")
  }

  func encode(to container: inout PersistenceContainer) {
    if let id = id {
      container[Columns.id] = id
    }
    if let externalFilename = externalFilename {
      container[Columns.externalFilename] = externalFilename
    }
    if let internalFilename = internalFilename {
      container[Columns.internalFilename] = internalFilename
    }
    if let size = size {
      container[Columns.size] = size
    }
    if let hash = hash {
      container[Columns.hash] = hash
    }
  }

  init(
    id: Int64?, externalFilename: String?, internalFilename: String?, size: Int64?, hash: String?
  ) {
    self.id = id
    self.externalFilename = externalFilename
    self.internalFilename = internalFilename
    self.size = size
    self.hash = hash
  }

  init(row: Row) {
    self.id = row[Columns.id]
    self.externalFilename = row[Columns.externalFilename]
    self.internalFilename = row[Columns.internalFilename]
    self.size = row[Columns.size]
    self.hash = row[Columns.hash]
  }
}

class File: CustomDebugStringConvertible {
  static let databaseTableName = "file"
  static let chunkSize = 15

  var id: Int64?
  var externalFilename: String?
  var internalFilename: String?
  var size: Int64?
  var hash: String?
  var fileParts: [FilePart] = []

  var numChunks: Int {
    return Int(ceil(Double(size ?? 0) / Double(File.chunkSize)))
  }

  init(externalFilename: String) throws {
    self.externalFilename = externalFilename
    let fileData = try Data(contentsOf: URL(fileURLWithPath: externalFilename))
    self.hash = fileData.sha256
    self.size = Int64(fileData.count)
    self.internalFilename = UUID().uuidString

    // Assumes the file is new, generates new parity data
    for i in 0..<numChunks {
      let filePart = FilePart(fileId: id, blockNumber: Int64(i), dataBits: Data())
      // File id may not exist yet
      fileParts.append(filePart)
    }
  }

  var dbRow: DBFile {
    return DBFile(
      id: id,
      externalFilename: externalFilename,
      internalFilename: internalFilename,
      size: size,
      hash: hash
    )
  }

  func save() async throws {
    let db = try await Database()
    let row = self.dbRow
    let newRow = try await db.pool.write { db in
      return try row.upsertAndFetch(db)
    }
    self.id = newRow.id
    self.externalFilename = newRow.externalFilename
    self.internalFilename = newRow.internalFilename
    self.size = newRow.size
    self.hash = newRow.hash
  }

  var debugDescription: String {
    return """
      File Object Debug --
        id: \(id.map { String($0) } ?? "nil")
        externalFilename: \(externalFilename ?? "nil")
        internalFilename: \(internalFilename ?? "nil")
        size: \(size.map { String($0) } ?? "nil")
        hash: \(hash ?? "nil")
        numChunks: \(numChunks)
      """
  }
}
