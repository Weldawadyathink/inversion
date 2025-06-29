import Foundation
import GRDB

struct DBFilePart: TableRecord, FetchableRecord, PersistableRecord, Sendable {
  let fileId: Int64?
  let blockNumber: Int64?
  let parityBits: Data?
  let dataBits: Data?
  static let databaseTableName = "file_part"

  enum Columns {
    static let fileId = Column("file_id")
    static let blockNumber = Column("block_number")
    static let parityBits = Column("parity_bits")
    static let dataBits = Column("data_bits")
  }

  func encode(to container: inout PersistenceContainer) {
    if let fileId = fileId {
      container[Columns.fileId] = fileId
    }
    if let blockNumber = blockNumber {
      container[Columns.blockNumber] = blockNumber
    }
    if let parityBits = parityBits {
      container[Columns.parityBits] = parityBits
    }
    if let dataBits = dataBits {
      container[Columns.dataBits] = dataBits
    }
  }

  init(fileId: Int64?, blockNumber: Int64?, parityBits: Data?, dataBits: Data?) {
    self.fileId = fileId
    self.blockNumber = blockNumber
    self.parityBits = parityBits
    self.dataBits = dataBits
  }

  init(row: Row) {
    self.fileId = row[Columns.fileId]
    self.blockNumber = row[Columns.blockNumber]
    self.parityBits = row[Columns.parityBits]
    self.dataBits = row[Columns.dataBits]
  }
}

class FilePart: CustomDebugStringConvertible {
  static let databaseTableName = "file_part"
  var fileId: Int64?
  var blockNumber: Int64?
  var parityBits: Data?
  var dataBits: Data?

  init(fileId: Int64?, blockNumber: Int64?, dataBits: Data?) {
    self.fileId = fileId
    self.blockNumber = blockNumber
    self.dataBits = dataBits
  }

  var canCheckParity: Bool {
    return parityBits != nil && dataBits != nil
  }

  var debugDescription: String {
    return """
      FilePart Object Debug --
        fileId: \(fileId.map { String($0) } ?? "nil")
        blockNumber: \(blockNumber.map { String($0) } ?? "nil")
        parityBits: \(parityBits.map { String(describing: $0) } ?? "nil")
        dataBits: \(dataBits.map { String(describing: $0) } ?? "nil")
      """
  }
}
