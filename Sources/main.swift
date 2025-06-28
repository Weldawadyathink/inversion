// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import GRDB

// Calculate and store parity bits for test-initial.txt
let blocks = try Hamming.calculateFileParity(from: "test-initial.txt")
for (i, block) in blocks.enumerated() {
    let (parityBits, dataBits) = block
    let dataText =
        String(data: dataBits, encoding: .utf8)
        ?? dataBits.map { String(format: "%02x", $0) }.joined()
    print("Block \(i): \(parityBits.binaryString) | \(dataText)")
}

// Save parity bits to the database
try dbPool.write { db in
    try db.execute(sql: "DELETE FROM blocks")
    for (i, block) in blocks.enumerated() {
        let (parityBits, _) = block
        // Convert Data to hex string for SQLite
        let parityHex = parityBits.map { String(format: "%02x", $0) }.joined()
        try db.execute(
            sql: "INSERT INTO blocks (block_number, parity_bits) VALUES (?, ?)",
            arguments: [i, parityHex])
    }
}

// Helper to load parity bits from DB
func loadParityBitsFromDB() throws -> [Data] {
    var parityBitsArray: [Data] = []
    try dbPool.read { db in
        let rows = try Row.fetchAll(
            db, sql: "SELECT block_number, parity_bits FROM blocks ORDER BY block_number ASC")
        for row in rows {
            let hexString: String = row["parity_bits"]
            // Convert hex string back to Data
            var bytes = [UInt8]()
            var index = hexString.startIndex
            while index < hexString.endIndex {
                let nextIndex = hexString.index(index, offsetBy: 2)
                let byteString = hexString[index..<nextIndex]
                if let byte = UInt8(byteString, radix: 16) {
                    bytes.append(byte)
                }
                index = nextIndex
            }
            parityBitsArray.append(Data(bytes))
        }
    }
    return parityBitsArray
}

// Check parity for a file using stored parity bits
func checkFileParity(filename: String, parityBitsArray: [Data]) throws {
    let url = URL(fileURLWithPath: filename)
    let fileData = try Data(contentsOf: url)
    let chunkSize = 15
    var offset = 0
    var blockIndex = 0
    print("\nChecking parity for \(filename):")
    while offset < fileData.count && blockIndex < parityBitsArray.count {
        let end = min(offset + chunkSize, fileData.count)
        var chunk = fileData.subdata(in: offset..<end)
        if chunk.count < chunkSize {
            chunk.append(contentsOf: [UInt8](repeating: 0, count: chunkSize - chunk.count))
        }
        let parityBits = parityBitsArray[blockIndex]
        let block = try Hamming.buildParityBlock(data: chunk, parity: parityBits)
        let result = try Hamming.checkParityBlock(block)
        let dataText =
            String(data: chunk, encoding: .utf8)
            ?? chunk.map { String(format: "%02x", $0) }.joined()
        print("Block \(blockIndex): \(result) | \(dataText)")
        offset += chunkSize
        blockIndex += 1
    }
}

// Load parity bits from DB
let storedParityBits = try loadParityBitsFromDB()

// Check both files
try checkFileParity(filename: "test-initial.txt", parityBitsArray: storedParityBits)
try checkFileParity(filename: "test-bitrot.txt", parityBitsArray: storedParityBits)
