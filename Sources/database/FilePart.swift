import Foundation
import GRDB

class FilePart: Codable, FetchableRecord, PersistableRecord, TableRecord,
  CustomDebugStringConvertible
{
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
    return
      "FilePart(fileId: \(fileId), blockNumber: \(blockNumber), parityBits: \(parityBits), dataBits: \(dataBits))"
  }
}
