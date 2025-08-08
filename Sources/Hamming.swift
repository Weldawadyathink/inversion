import Foundation

// payloadBits is not permanently stored to reduce memory usage
protocol Hamming {
  var parityBits: Data { get set }
  var paritySize: Int { get }
  var payloadSize: Int { get }
  var parityBitOffset: Int { get }
  var hammingLookupTable: [Int] { get }

  func getHammingInterlacedData(payloadBits: Data) throws -> Data
  mutating func calculateParity(payloadBits: Data) throws
  mutating func setParity(hammingData: Data) throws
  func checkParity(payloadBits: Data) throws -> HammingCheckResult
}

enum HammingError: Swift.Error {
  case payloadBitsNotSet
  case parityBitsNotSet
  case invalidDataSize(expectedPayloadSize: Int, expectedParitySize: Int, actualDataSize: Int)
  case invalidPayloadSize
}

enum HammingCheckResult {
  case valid
  case recoverableErrorInParity(bitIndex: Int)
  case recoverableErrorInData(bitIndex: Int)
  case nonRecoverableError
}

// ----------------------Implementation----------------------

struct HammingDefaults {
  static let parityBitOffset = 100
  static let paritySize = 1
  static let payloadSize = 15

  static let hammingLookupTable: [Int] = (0..<128).map { i in
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
}

extension Hamming {
  private static var parityBitOffset: Int { HammingDefaults.parityBitOffset }
  private static var paritySize: Int { HammingDefaults.paritySize }
  private static var payloadSize: Int { HammingDefaults.payloadSize }
  private static var hammingLookupTable: [Int] { HammingDefaults.hammingLookupTable }

  func getHammingInterlacedData(payloadBits: Data) throws -> Data {
    guard payloadBits.count == self.payloadSize else {
      throw HammingError.invalidPayloadSize
    }
    var output = Data(count: 16)
    for i in 0..<128 {
      let bitIndex = self.hammingLookupTable[i]
      if bitIndex < 0 {
        output.setBit(at: i, to: self.parityBits.getBit(bitIndex + self.parityBitOffset))
      } else {
        output.setBit(at: i, to: payloadBits.getBit(bitIndex))
      }
    }
    return output
  }

  mutating func calculateParity(payloadBits: Data) throws {
    guard payloadBits.count == self.payloadSize else {
      throw HammingError.invalidPayloadSize
    }
    self.parityBits = Data(count: 1)

    // Calculate parity bits
    var hammingData = try self.getHammingInterlacedData(payloadBits: payloadBits)
    for p in 0..<7 {
      let parityPosition = 1 << p
      var parityValue: UInt8 = 0
      for i in 1..<128 {
        if (i & parityPosition) != 0 {
          parityValue ^= hammingData.getBit(i)
        }
      }
      hammingData.setBit(at: parityPosition, to: parityValue)
    }

    // Calculate overall parity
    var overallParity: UInt8 = 0
    for i in 0..<128 {
      overallParity ^= hammingData.getBit(i)
    }
    hammingData.setBit(at: 0, to: overallParity)

    try self.setParity(hammingData: hammingData)
  }

  mutating func setParity(hammingData: Data) throws {
    let expectedSize = self.payloadSize + self.paritySize
    guard hammingData.count == expectedSize else {
      throw HammingError.invalidDataSize(
        expectedPayloadSize: self.payloadSize,
        expectedParitySize: self.paritySize,
        actualDataSize: hammingData.count
      )
    }
    self.parityBits = Data(count: 1)
    for i in 0..<128 {
      let bitIndex = self.hammingLookupTable[i]
      if bitIndex < 0 {
        self.parityBits.setBit(at: bitIndex + self.parityBitOffset, to: hammingData.getBit(i))
      }
    }
  }

  func checkParity(payloadBits: Data) throws -> HammingCheckResult {
    guard payloadBits.count == self.payloadSize else {
      throw HammingError.invalidPayloadSize
    }
    let hammingData = try self.getHammingInterlacedData(payloadBits: payloadBits)
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
      let flippedBit = self.hammingLookupTable[syndrome]
      if flippedBit < 0 {
        return .recoverableErrorInParity(bitIndex: flippedBit + self.parityBitOffset)
      } else {
        return .recoverableErrorInData(bitIndex: flippedBit)
      }
    } else {
      return .nonRecoverableError
    }
  }
}
