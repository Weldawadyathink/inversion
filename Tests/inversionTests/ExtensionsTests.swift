import CryptoKit
import Foundation
import Testing

@testable import inversion

struct ExtensionsTests {

  // MARK: - Data Extension Tests

  @Test("Data getBit returns correct bit values")
  func testDataGetBit() {
    // Test with known binary data: 10110100 (0xB4 = 180)
    let data = Data([0xB4])

    // Test each bit position
    #expect(data.getBit(0) == 1)  // MSB
    #expect(data.getBit(1) == 0)
    #expect(data.getBit(2) == 1)
    #expect(data.getBit(3) == 1)
    #expect(data.getBit(4) == 0)
    #expect(data.getBit(5) == 1)
    #expect(data.getBit(6) == 0)
    #expect(data.getBit(7) == 0)  // LSB
  }

  @Test("Data getBit works with multiple bytes")
  func testDataGetBitMultipleBytes() {
    // Test with two bytes: 0xFF (11111111), 0x00 (00000000)
    let data = Data([0xFF, 0x00])

    // First byte - all bits should be 1
    for i in 0..<8 {
      #expect(data.getBit(i) == 1, "Bit \(i) should be 1")
    }

    // Second byte - all bits should be 0
    for i in 8..<16 {
      #expect(data.getBit(i) == 0, "Bit \(i) should be 0")
    }
  }

  @Test("Data setBit correctly sets bits to 1")
  func testDataSetBitToOne() {
    var data = Data([0x00])  // 00000000

    // Set various bits to 1
    data.setBit(at: 0, to: 1)  // Should become 10000000 (0x80)
    #expect(data[0] == 0x80)

    data.setBit(at: 7, to: 1)  // Should become 10000001 (0x81)
    #expect(data[0] == 0x81)

    data.setBit(at: 3, to: 1)  // Should become 10010001 (0x91)
    #expect(data[0] == 0x91)
  }

  @Test("Data setBit correctly sets bits to 0")
  func testDataSetBitToZero() {
    var data = Data([0xFF])  // 11111111

    // Clear various bits
    data.setBit(at: 0, to: 0)  // Should become 01111111 (0x7F)
    #expect(data[0] == 0x7F)

    data.setBit(at: 7, to: 0)  // Should become 01111110 (0x7E)
    #expect(data[0] == 0x7E)

    data.setBit(at: 3, to: 0)  // Should become 01101110 (0x6E)
    #expect(data[0] == 0x6E)
  }

  @Test("Data setBit works with multiple bytes")
  func testDataSetBitMultipleBytes() {
    var data = Data([0x00, 0x00])  // Two zero bytes

    // Set bits in first byte
    data.setBit(at: 0, to: 1)  // MSB of first byte
    data.setBit(at: 7, to: 1)  // LSB of first byte

    // Set bits in second byte
    data.setBit(at: 8, to: 1)  // MSB of second byte
    data.setBit(at: 15, to: 1)  // LSB of second byte

    #expect(data[0] == 0x81)  // 10000001
    #expect(data[1] == 0x81)  // 10000001
  }

  @Test("Data binaryString returns correct binary representation")
  func testDataBinaryString() {
    // Test single byte - each byte is padded to 8 bits
    let singleByte = Data([0xB4])  // 10110100
    #expect(singleByte.binaryString == "10110100")

    // Test multiple bytes - each byte gets padded to 8 bits
    let multipleBytes = Data([0xFF, 0x00, 0xAA])
    // Each byte becomes: "11111111", "00000000", "10101010"
    let expected = "111111110000000010101010"
    #expect(multipleBytes.binaryString == expected)

    // Test empty data
    let emptyData = Data()
    #expect(emptyData.binaryString == "")

    // Test zero byte
    let zeroByte = Data([0x00])
    #expect(zeroByte.binaryString == "00000000")
  }

  @Test("Data sha256 returns correct hash")
  func testDataSHA256() {
    // Test with known data
    let testData = "Hello, World!".data(using: .utf8)!
    let expectedHash = "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f"

    #expect(testData.sha256 == expectedHash)

    // Test with empty data
    let emptyData = Data()
    let emptyHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    #expect(emptyData.sha256 == emptyHash)

    // Test hash consistency
    let data1 = "test".data(using: .utf8)!
    let data2 = "test".data(using: .utf8)!
    #expect(data1.sha256 == data2.sha256)
  }

  // MARK: - String Extension Tests

  @Test("String leftPad pads correctly when string is shorter")
  func testStringLeftPadShorter() {
    let original = "123"
    let padded = original.leftPad(toLength: 6, withPad: "0")
    #expect(padded == "000123")

    // Test with different pad character
    let paddedWithSpace = original.leftPad(toLength: 5, withPad: " ")
    #expect(paddedWithSpace == "  123")
  }

  @Test("String leftPad returns original when string is equal length")
  func testStringLeftPadEqualLength() {
    let original = "12345"
    let result = original.leftPad(toLength: 5, withPad: "0")
    #expect(result == "12345")
  }

  @Test("String leftPad returns original when string is longer")
  func testStringLeftPadLonger() {
    let original = "1234567"
    let result = original.leftPad(toLength: 5, withPad: "0")
    #expect(result == "1234567")
  }

  @Test("String leftPad works with empty string")
  func testStringLeftPadEmpty() {
    let empty = ""
    let padded = empty.leftPad(toLength: 3, withPad: "x")
    #expect(padded == "xxx")
  }

  @Test("String leftPad works with zero length")
  func testStringLeftPadZeroLength() {
    let original = "test"
    let result = original.leftPad(toLength: 0, withPad: "0")
    #expect(result == "test")
  }

  @Test("String leftPad works with various characters")
  func testStringLeftPadVariousCharacters() {
    let original = "42"

    // Test with different padding characters
    #expect(original.leftPad(toLength: 4, withPad: "0") == "0042")
    #expect(original.leftPad(toLength: 4, withPad: " ") == "  42")
    #expect(original.leftPad(toLength: 4, withPad: "*") == "**42")
    #expect(original.leftPad(toLength: 4, withPad: "-") == "--42")
  }

  // MARK: - Integration Tests

  @Test("Data bit operations work together correctly")
  func testDataBitOperationsIntegration() {
    var data = Data([0x00])

    // Set some bits
    data.setBit(at: 0, to: 1)
    data.setBit(at: 2, to: 1)
    data.setBit(at: 4, to: 1)
    data.setBit(at: 6, to: 1)

    // Verify the bits are set correctly
    #expect(data.getBit(0) == 1)
    #expect(data.getBit(1) == 0)
    #expect(data.getBit(2) == 1)
    #expect(data.getBit(3) == 0)
    #expect(data.getBit(4) == 1)
    #expect(data.getBit(5) == 0)
    #expect(data.getBit(6) == 1)
    #expect(data.getBit(7) == 0)

    // Check the final byte value (10101010 = 0xAA)
    #expect(data[0] == 0xAA)

    // Check binary string representation
    #expect(data.binaryString == "10101010")
  }

  @Test("Binary string formatting with leftPad integration")
  func testBinaryStringWithLeftPad() {
    let data = Data([0x0F])  // 00001111
    let binaryStr = data.binaryString

    // Test that we can pad the binary string
    let paddedBinary = binaryStr.leftPad(toLength: 16, withPad: "0")
    #expect(paddedBinary == "0000000000001111")
  }

  // MARK: - Edge Cases and Error Conditions

  @Test("Data operations handle boundary conditions")
  func testDataBoundaryConditions() {
    let data = Data([0xFF, 0x00, 0xFF])

    // Test first bit of first byte
    #expect(data.getBit(0) == 1)

    // Test last bit of first byte
    #expect(data.getBit(7) == 1)

    // Test first bit of second byte
    #expect(data.getBit(8) == 0)

    // Test last bit of last byte
    #expect(data.getBit(23) == 1)
  }

  @Test("SHA256 produces consistent results")
  func testSHA256Consistency() {
    let testCases = [
      ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
      ("a", "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb"),
      ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
    ]

    for (input, expectedHash) in testCases {
      let data = input.data(using: .utf8)!
      #expect(data.sha256 == expectedHash, "SHA256 mismatch for input '\(input)'")
    }
  }
}
