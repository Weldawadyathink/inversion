import CryptoKit
import Foundation
import GRDB

enum FileError: Error {
  case filePartsNotLoaded
  case fileNotFound(filename: String)
}

struct File: TableRecord, FetchableRecord, PersistableRecord, Sendable {
  var id: Int64?
  var filename: String
  var size: Int64
  var hash: String
  var fileParts: [FilePart]?

  static let databaseTableName = "file"

  var numChunksInFile: Int {
    return Int(ceil(Double(size) / Double(HammingDefaults.payloadSize)))
  }

  init(filename: String) throws {
    let fileData = try Data(contentsOf: URL(fileURLWithPath: filename))
    self.filename = filename
    self.size = Int64(fileData.count)
    self.hash = fileData.sha256
    self.fileParts = []
    for i in 0..<numChunksInFile {
      let filePart = FilePart(blockNumber: Int64(i))
      // File id may not exist yet
      self.fileParts!.append(filePart)
    }
  }

  init(row: Row) {
    self.id = row[Columns.id]
    self.filename = row[Columns.filename]
    self.size = row[Columns.size]
    self.hash = row[Columns.hash]
  }

  enum Columns {
    static let id = Column("id")
    static let filename = Column("filename")
    static let size = Column("size")
    static let hash = Column("hash")
  }

  func encode(to container: inout PersistenceContainer) {
    if let id = id {
      container[Columns.id] = id
    }
    container[Columns.filename] = filename
    container[Columns.size] = size
    container[Columns.hash] = hash
  }

  static func loadFromDatabase(filename: String) async throws -> File? {
    let db = try await Database()
    let file = try await db.pool.read { db in
      return try File.fetchOne(
        db, sql: "SELECT * FROM file WHERE filename = ?", arguments: [filename])
    }
    return file
  }

  mutating func loadFilePartsFromDatabase() async throws {
    let fileId = self.id
    let db = try await Database()
    let dbFileParts = try await db.pool.read { db in
      return try FilePart.fetchAll(
        db, sql: "SELECT * FROM file_part WHERE file_id = ? ORDER BY block_number ASC",
        arguments: [fileId])
    }
    self.fileParts = dbFileParts
  }

  mutating func calculateParity() throws {
    guard var fileParts = self.fileParts else {
      throw FileError.filePartsNotLoaded
    }

    let chunks = try FileChunkSequence(
      fileName: self.filename, chunkSize: HammingDefaults.payloadSize)

    var index = 0
    for chunk in chunks {
      try fileParts[index].calculateParity(payloadBits: chunk)
      index += 1
    }
  }

  func checkParity() throws -> [HammingCheckResult] {
    guard let fileParts = self.fileParts else {
      throw FileError.filePartsNotLoaded
    }

    let chunks = try FileChunkSequence(
      fileName: self.filename, chunkSize: HammingDefaults.payloadSize)

    var index = 0
    var results: [HammingCheckResult] = []
    for chunk in chunks {
      let partResult = try fileParts[index].checkParity(payloadBits: chunk)
      results.append(partResult)
      index += 1
    }
    debugPrint(results)
    return results
  }

  mutating func save() async throws {
    guard let fileParts = self.fileParts else {
      throw FileError.filePartsNotLoaded
    }
    let db = try await Database()
    let oldFile = self
    let newFiles = try await db.pool.write { db in
      let newFile = try oldFile.upsertAndFetch(db)
      var newParts: [FilePart] = []
      for var part in fileParts {
        part.fileId = newFile.id
        newParts.append(try part.upsertAndFetch(db))
      }
      return (file: newFile, parts: newParts)
    }
    self.id = newFiles.file.id
    self.filename = newFiles.file.filename
    self.size = newFiles.file.size
    self.hash = newFiles.file.hash
    self.fileParts = newFiles.parts
  }
}

/*

struct DBFile: TableRecord, FetchableRecord, PersistableRecord, Sendable {
  let id: Int64?
  let filename: String
  let size: Int64?
  let hash: String?
  static let databaseTableName = "file"

  enum Columns {
    static let id = Column("id")
    static let filename = Column("filename")
    static let size = Column("size")
    static let hash = Column("hash")
  }

  func encode(to container: inout PersistenceContainer) {
    if let id = id {
      container[Columns.id] = id
    }
    container[Columns.filename] = filename
    if let size = size {
      container[Columns.size] = size
    }
    if let hash = hash {
      container[Columns.hash] = hash
    }
  }

  init(
    id: Int64?, filename: String, size: Int64?, hash: String?
  ) {
    self.id = id
    self.filename = filename
    self.size = size
    self.hash = hash
  }

  init(row: Row) {
    self.id = row[Columns.id]
    self.filename = row[Columns.filename]
    self.size = row[Columns.size]
    self.hash = row[Columns.hash]
  }
}

class File: CustomDebugStringConvertible {
  static let databaseTableName = "file"
  static let chunkSize = 15

  var id: Int64?
  var filename: String
  var size: Int64?
  var hash: String?
  var fileParts: [FilePart] = []

  var numChunks: Int {
    return Int(ceil(Double(size ?? 0) / Double(File.chunkSize)))
  }

  static func loadFromDatabase(filename: String) async throws -> (hasFileMoved: Bool, file: File) {
    let fileData = try Data(contentsOf: URL(fileURLWithPath: filename))
    let hash = fileData.sha256
    let size = Int64(fileData.count)

    let db = try await Database()
    let dbFile = try await db.pool.read { db in
      return try DBFile.fetchOne(
        db, sql: "SELECT * FROM file WHERE hash = ? AND size = ?",
        arguments: [hash, size])
    }
    if dbFile == nil {
      throw FileNotFoundError(filename: filename)
    }
    return (
      hasFileMoved: dbFile?.filename != filename,
      file: try await File(dbFile: dbFile!)
    )
  }

  init(dbFile: DBFile) async throws {
    self.id = dbFile.id
    self.filename = dbFile.filename
    self.size = dbFile.size
    self.hash = dbFile.hash
    try await self.loadFilePartsFromDatabase()
  }

  init(filename: String) throws {
    self.filename = filename
    let fileData = try Data(contentsOf: URL(fileURLWithPath: filename))
    self.hash = fileData.sha256
    self.size = Int64(fileData.count)

    // Assumes the file is new, generates new parity data
    for i in 0..<numChunks {
      let filePart = FilePart(fileId: self.id, blockNumber: Int64(i))
      // File id may not exist yet
      fileParts.append(filePart)
    }
  }

  func calculateParity() throws {
    let fileData = try Data(contentsOf: URL(fileURLWithPath: self.filename))
    var offset = 0
    var index = 0
    while offset < fileData.count {
      let end = min(offset + File.chunkSize, fileData.count)
      var chunk = fileData.subdata(in: offset..<end)
      if chunk.count < File.chunkSize {
        // Pad end of file with zeros
        chunk.append(
          contentsOf: [UInt8](
            repeating: 0, count: File.chunkSize - chunk.count))
      }
      try self.fileParts[index].calculateParity(messageData: chunk)
      index += 1
      offset += File.chunkSize
    }
  }

  func checkParity() throws {
    guard self.fileParts.count == self.numChunks else {
      debugPrint("checkParity invalid data state. \(self.fileParts.count) != \(self.numChunks)")
      throw FileError.invalidFilePartsCount
    }

    let fileData = try Data(contentsOf: URL(fileURLWithPath: self.filename))
    var offset = 0
    var index = 0
    var parityResults = [HammingCheckResult]()
    while offset < fileData.count {
      let end = min(offset + File.chunkSize, fileData.count)
      var chunk = fileData.subdata(in: offset..<end)
      if chunk.count < File.chunkSize {
        // Pad end of file with zeros
        chunk.append(
          contentsOf: [UInt8](
            repeating: 0, count: File.chunkSize - chunk.count))
      }
      let results = try self.fileParts[index].checkParity(messageData: chunk)
      parityResults.append(results)
      index += 1
      offset += File.chunkSize
    }
    debugPrint(parityResults)
  }

  func loadFilePartsFromDatabase() async throws {
    let fileId = self.id
    let db = try await Database()
    let dbFileParts = try await db.pool.read { db in
      return try DBFilePart.fetchAll(
        db, sql: "SELECT * FROM file_part WHERE file_id = ?", arguments: [fileId])
    }
    self.fileParts = dbFileParts.map { FilePart(dbFilePart: $0) }
  }

  var dbRow: DBFile {
    return DBFile(
      id: id,
      filename: filename,
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
    self.filename = newRow.filename
    self.size = newRow.size
    self.hash = newRow.hash
    //TODO: Do this in one transaction
    self.fileParts.forEach { $0.fileId = self.id }
    let parts = try self.fileParts.map { try $0.dbRow() }
    try await db.pool.write { db in
      for part in parts {
        try part.upsert(db)
      }
    }
  }

  var debugDescription: String {
    return """
      File Object Debug --
        id: \(id.map { String($0) } ?? "nil")
        filename: \(filename)
        size: \(size.map { String($0) } ?? "nil")
        hash: \(hash ?? "nil")
        numChunks: \(numChunks)
      """
  }
}

*/
