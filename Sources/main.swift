// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

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
}

func calculateHammingEncoding(_ input: Data) -> Data {
    // Extended Hamming(256,247): 0-based. Bit 0: overall parity, bits 1,2,4,8,16,32,64,128: Hamming parity, rest: data
    var output = Data(count: 32)
    let parityPositions: [Int] = [1,2,4,8,16,32,64,128] // 0-based
    var dataBit = 0
    for i in 0..<256 {
        if i == 0 || parityPositions.contains(i) {
            // Parity bits, set to 0 for now
            output.setBit(at: i, to: 0)
        } else {
            // Data bits
            let value = input.bit(at: dataBit)
            output.setBit(at: i, to: value)
            dataBit += 1
        }
    }
    // Calculate Hamming parity bits (skip overall parity at 0)
    for pPos in parityPositions {
        var parity: UInt8 = 0
        for i in 1..<256 { // skip overall parity at 0
            if (i & pPos) != 0 {
                parity ^= output.bit(at: i)
            }
        }
        output.setBit(at: pPos, to: parity)
    }
    // Calculate overall parity (even parity for all 255 bits except bit 0)
    var overallParity: UInt8 = 0
    for i in 1..<256 {
        overallParity ^= output.bit(at: i)
    }
    output.setBit(at: 0, to: overallParity)
    return output
}

func calculateFileParity(from filename: String) throws -> [Data] {
    print("Calculating parity for file: \(filename)")
    let url = URL(fileURLWithPath: filename)
    let fileData = try Data(contentsOf: url)
    let chunkSize = 31 // 247 bits
    var blocks: [Data] = []
    var offset = 0
    while offset < fileData.count {
        let end = min(offset + chunkSize, fileData.count)
        var chunk = fileData.subdata(in: offset..<end)
        if chunk.count < chunkSize {
            // Pad the last chunk with zeros
            chunk.append(contentsOf: [UInt8](repeating: 0, count: chunkSize - chunk.count))
        }
        let parityBlock = calculateHammingEncoding(chunk)
        blocks.append(parityBlock)
        offset += chunkSize
    }
    return blocks
}

func extractParityBits(_ block: Data) -> (parityBits: [UInt8], dataBits: [UInt8]) {
    // 0-based: bit 0 = overall parity, bits 1,2,4,8,16,32,64,128 = Hamming parities, rest = data
    let parityPositions: [Int] = [0, 1, 2, 4, 8, 16, 32, 64, 128] // overall first
    var parityBits: [UInt8] = []
    var dataBits: [UInt8] = []
    for i in 0..<256 {
        if parityPositions.contains(i) {
            parityBits.append(block.bit(at: i))
        } else {
            dataBits.append(block.bit(at: i))
        }
    }
    return (parityBits, dataBits)
}

// Example usage:
let blocks = try calculateFileParity(from: "test.txt")
for (i, block) in blocks.enumerated() {
    let (parityBits, dataBits) = extractParityBits(block)
    // Parity bits as string
    let parityString = parityBits.map { String($0) }.joined()
    // Data bits as bytes
    var dataBytes: [UInt8] = []
    for byteIdx in 0..<(dataBits.count/8) {
        var byte: UInt8 = 0
        for bit in 0..<8 {
            byte |= (dataBits[byteIdx*8 + bit] << (7-bit))
        }
        dataBytes.append(byte)
    }
    let message = String(bytes: dataBytes, encoding: .utf8) ?? "<non-UTF8 data>"
    print("Block \(i): \(parityString) | \(message)")
}
