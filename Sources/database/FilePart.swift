import Foundation
import GRDB

struct DBFilePart: TableRecord, FetchableRecord, PersistableRecord, Sendable {
  let fileId: Int64
  let blockNumber: Int64
  let parityBits: Data
  static let databaseTableName = "file_part"

  enum Columns {
    static let fileId = Column("file_id")
    static let blockNumber = Column("block_number")
    static let parityBits = Column("parity_bits")
  }

  func encode(to container: inout PersistenceContainer) {
    container[Columns.fileId] = fileId
    container[Columns.blockNumber] = blockNumber
    container[Columns.parityBits] = parityBits
  }

  init(fileId: Int64, blockNumber: Int64, parityBits: Data) {
    self.fileId = fileId
    self.blockNumber = blockNumber
    self.parityBits = parityBits
  }

  init(row: Row) {
    self.fileId = row[Columns.fileId]
    self.blockNumber = row[Columns.blockNumber]
    self.parityBits = row[Columns.parityBits]
  }
}

enum HammingCheckResult {
  case valid
  case recoverableErrorInData(bitIndex: Int)
  case recoverableErrorInParity(bitIndex: Int)
  case nonRecoverableError
}

final class FilePartError: Error, CustomDebugStringConvertible {
  let message: String

  static let invalidDataSize = FilePartError(
    "Invalid data size: messageData does not match File.chunkSize.")
  static let parityBitsNotSet = FilePartError("Parity bits not set: parityBits is nil.")
  static let invalidParitySize = FilePartError(
    "Invalid parity size: hammingData does not match expected size.")
  static let fileIdNotSet = FilePartError("File ID not set: fileId is nil.")
  static let blockNumberNotSet = FilePartError("Block number not set: blockNumber is nil.")

  init(_ message: String) {
    self.message = message
  }

  var debugDescription: String {
    return "FilePartError: \(message)"
  }
}

class FilePart: CustomDebugStringConvertible {
  var fileId: Int64?
  var blockNumber: Int64
  var parityBits: Data?

  private static let paritySize = 1
  private static let parityBitOffset = 100
  private static let hammingLookupTable: [Int] = (0..<128).map { i in
    if i == 0 {
      return 0 - parityBitOffset
    } else if (i & (i - 1)) == 0 {
      // Negative numbers represent parity bits
      return i.trailingZeroBitCount + 1 - parityBitOffset
    } else {
      var parityCount = 0
      var p = 1
      while p <= i {
        parityCount += 1
        p <<= 1
      }
      return i - parityCount - 1  // -1 because the first data bit should be bit 0
    }
  }

  func dbRow() throws -> DBFilePart {
    guard let fileId = self.fileId else {
      throw FilePartError.fileIdNotSet
    }
    guard let parityBits = self.parityBits else {
      throw FilePartError.parityBitsNotSet
    }
    return DBFilePart(
      fileId: fileId,
      blockNumber: self.blockNumber,
      parityBits: parityBits
    )
  }

  func getHammingInterlacedData(messageData: Data) throws -> Data {
    guard messageData.count == File.chunkSize else {
      throw FilePartError.invalidDataSize
    }
    guard self.parityBits != nil else {
      throw FilePartError.parityBitsNotSet
    }
    var output = Data(count: 16)
    for i in 0..<128 {
      let bitIndex = FilePart.hammingLookupTable[i]
      if bitIndex < 0 {
        output.setBit(at: i, to: self.parityBits!.getBit(bitIndex + FilePart.parityBitOffset))
      } else {
        output.setBit(at: i, to: messageData.getBit(bitIndex))
      }
    }
    return output
  }

  init(dbFilePart: DBFilePart) {
    self.fileId = dbFilePart.fileId
    self.blockNumber = dbFilePart.blockNumber
    self.parityBits = dbFilePart.parityBits
  }

  init(fileId: Int64?, blockNumber: Int64) {
    self.fileId = fileId
    self.blockNumber = blockNumber
  }

  func calculateParity(messageData: Data) throws {
    guard messageData.count == File.chunkSize else {
      debugPrint("calculateParity invalid data state. \(messageData.count) != \(File.chunkSize)")
      throw FilePartError.invalidDataSize
    }
    if self.parityBits == nil {
      self.parityBits = Data(count: 1)
    }
    var hammingData = try self.getHammingInterlacedData(messageData: messageData)
    for p in 0..<7 {
      let parityPosition = 1 << p
      var parityValue: UInt8 = 0
      for i in 1..<128 {
        if (i & parityPosition) != 0 {
          parityValue ^= hammingData.getBit(i)
        }
      }
      hammingData.setBit(at: parityPosition, to: parityValue)

      var overallParity: UInt8 = 0
      for i in 0..<128 {
        overallParity ^= hammingData.getBit(i)
      }
      hammingData.setBit(at: 0, to: overallParity)
    }
    try self.setParity(hammingData: hammingData)
  }

  func setParity(hammingData: Data) throws {
    guard hammingData.count == File.chunkSize + FilePart.paritySize else {
      throw FilePartError.invalidParitySize
    }
    self.parityBits = Data(count: 1)
    for i in 0..<128 {
      let bitIndex = FilePart.hammingLookupTable[i]
      if bitIndex < 0 {
        self.parityBits!.setBit(at: bitIndex + FilePart.parityBitOffset, to: hammingData.getBit(i))
      }
    }
  }

  func checkParity(messageData: Data) throws -> HammingCheckResult {
    guard messageData.count == File.chunkSize else {
      throw FilePartError.invalidDataSize
    }
    let hammingData = try self.getHammingInterlacedData(messageData: messageData)
    var syndrome = 0
    var overallParity: UInt8 = hammingData.getBit(0)
    for i in 1..<128 {
      if hammingData.getBit(i) == 1 {
        syndrome ^= i
        overallParity ^= 1
      }
    }
    if syndrome == 0 && overallParity == 0 {
      return .valid
    } else if syndrome != 0 && overallParity == 1 {
      let flippedBit = FilePart.hammingLookupTable[syndrome]
      if flippedBit < 0 {
        return .recoverableErrorInParity(bitIndex: flippedBit + FilePart.parityBitOffset)
      } else {
        return .recoverableErrorInData(bitIndex: flippedBit)
      }
    } else {
      return .nonRecoverableError
    }
  }

  var debugDescription: String {
    return """
      FilePart Object Debug --
        fileId: \(fileId.map { String($0) } ?? "nil")
        blockNumber: \(blockNumber)
        parityBits: \(parityBits.map { String(describing: $0) } ?? "nil")
      """
  }
}
