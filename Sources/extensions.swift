import Foundation

extension Data {
  func getBit(_ bitIndex: Int) -> UInt8 {
    let byteIndex = bitIndex / 8
    let bitInByte = 7 - (bitIndex % 8)
    return (self[byteIndex] >> bitInByte) & 1
  }
  mutating func setBit(at bitIndex: Int, to value: UInt8) {
    let byteIndex = bitIndex / 8
    let bitInByte = 7 - (bitIndex % 8)
    if value == 1 {
      self[byteIndex] |= (1 << bitInByte)
    } else {
      self[byteIndex] &= ~(1 << bitInByte)
    }
  }
  var binaryString: String {
    self.map { String($0, radix: 2).leftPad(toLength: self.count * 8, withPad: "0") }.joined()
  }
}

extension String {
  func leftPad(toLength: Int, withPad character: Character) -> String {
    if self.count < toLength {
      return String(repeatElement(character, count: toLength - self.count)) + self
    } else {
      return self
    }
  }
}
