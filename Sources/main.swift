// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import GRDB

extension Data {
    func bit(at bitIndex: Int) -> UInt8 {
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

func buildHammingParityBlock(data: Data, parity: Data) throws -> Data {
    // Combines raw data and parity data into a properly formatted hamming parity block SECDED(128,120)
    guard data.count == 15 else {
        print("Data must be 120 bits, got \(data.count * 8)")
        throw NSError(
            domain: "HammingParityError", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Data must be 120 bits"])
    }
    guard parity.count == 1 else {
        print("Parity must be 8 bits, got \(parity.count * 8)")
        throw NSError(
            domain: "HammingParityError", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Parity must be 8 bits"])
    }
    var output = Data(count: 16)
    var nextDataBitToRead = 0
    for i in 0..<128 {
        if i == 0 {
            // Overall parity bit
            output.setBit(at: i, to: parity.bit(at: 0))
        } else if (i & (i - 1)) == 0 {
            // Hamming parity bits (powers of 2)
            output.setBit(at: i, to: parity.bit(at: i.trailingZeroBitCount + 1))
        } else {
            // Data bits
            output.setBit(at: i, to: data.bit(at: nextDataBitToRead))
            nextDataBitToRead += 1
        }
    }
    return output
}

func generateHammingParityBits(_ input: Data) throws -> Data {
    // Takes a 120 bit data block and generates the 8 extended hamming parity bits
    // Returns the block with hamming parity integrated
    guard input.count == 15 else {
        print("Input must be 120 bits, got \(input.count * 8)")
        throw NSError(
            domain: "HammingParityError", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Input must be 120 bits"])
    }

    var bits = try buildHammingParityBlock(data: input, parity: Data(count: 1))

    for p in 0..<7 {
        let parityPosition = 1 << p  // 1,2,4,8,16,32,64
        var parityValue: UInt8 = 0
        for i in 1..<128 {  // skip overall parity at 0
            if (i & parityPosition) != 0 {
                parityValue ^= bits.bit(at: i)
            }
        }
        bits.setBit(at: parityPosition, to: parityValue)
    }
    return bits
}

func calculateFileParity(from filename: String) throws -> [(parityBits: Data, dataBits: Data)] {
    print("Calculating parity for file: \(filename)")
    let url = URL(fileURLWithPath: filename)
    let fileData = try Data(contentsOf: url)
    let chunkSize = 15  // 120 bits
    var blocks: [(parityBits: Data, dataBits: Data)] = []
    var offset = 0
    while offset < fileData.count {
        let end = min(offset + chunkSize, fileData.count)
        var chunk = fileData.subdata(in: offset..<end)
        if chunk.count < chunkSize {
            // Pad the last chunk with zeros
            chunk.append(contentsOf: [UInt8](repeating: 0, count: chunkSize - chunk.count))
        }
        let parity = try generateHammingParityBits(chunk)
        let (parityBits, dataBits) = try extractParityBits(parity)
        blocks.append((parityBits, dataBits))
        offset += chunkSize
    }
    return blocks
}

func extractParityBits(_ input: Data) throws -> (parityBits: Data, dataBits: Data) {
    guard input.count == 16 else {
        print("Block must be 16 bits, got \(input.count * 8)")
        throw NSError(
            domain: "HammingParityError", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Block must be 16 bits"])
    }
    var parityBits: Data = Data(count: 1)
    var dataBits: Data = Data(count: 15)
    var dataBitToSetNext = 0
    for i in 0..<128 {
        if i == 0 {
            // Overall parity bit
            parityBits.setBit(at: 0, to: input.bit(at: 0))
        } else if (i & (i - 1)) == 0 {
            // Hamming parity bits (powers of 2)
            parityBits.setBit(
                at: i.trailingZeroBitCount + 1, to: input.bit(at: i.trailingZeroBitCount + 1))
        } else {
            // Data bits
            dataBits.setBit(at: dataBitToSetNext, to: input.bit(at: i))
            dataBitToSetNext += 1
        }
    }
    return (parityBits, dataBits)
}

let blocks = try calculateFileParity(from: "test.txt")
for (i, block) in blocks.enumerated() {
    let (parityBits, dataBits) = block
    let dataText =
        String(data: dataBits, encoding: .utf8)
        ?? dataBits.map { String(format: "%02x", $0) }.joined()
    print("Block \(i): \(parityBits.binaryString) | \(dataText)")
}

let dbPool = try DatabasePool(path: "inversion.db")

try dbPool.read { db in
    let version = try String.fetchAll(db, sql: "select sqlite_version();")
    print(version)
}
