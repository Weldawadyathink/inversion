// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import GRDB

let blocks = try Hamming.calculateFileParity(from: "test.txt")
for (i, block) in blocks.enumerated() {
    let (parityBits, dataBits) = block
    let dataText =
        String(data: dataBits, encoding: .utf8)
        ?? dataBits.map { String(format: "%02x", $0) }.joined()
    print("Block \(i): \(parityBits.binaryString) | \(dataText)")
}

// Save parity bits to the database
try dbPool.write { db in
    for (i, block) in blocks.enumerated() {
        let (parityBits, _) = block
        // Convert Data to hex string for SQLite
        let parityHex = parityBits.map { String(format: "%02x", $0) }.joined()
        try db.execute(
            sql: "INSERT INTO blocks (block_number, parity_bits) VALUES (?, ?)",
            arguments: [i, parityHex])
    }
}
