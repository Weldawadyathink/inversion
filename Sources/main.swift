// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

let blocks = try Hamming.calculateFileParity(from: "test.txt")
for (i, block) in blocks.enumerated() {
    let (parityBits, dataBits) = block
    let dataText =
        String(data: dataBits, encoding: .utf8)
        ?? dataBits.map { String(format: "%02x", $0) }.joined()
    print("Block \(i): \(parityBits.binaryString) | \(dataText)")
}

try dbPool.read { db in
    let version = try String.fetchAll(db, sql: "select sqlite_version();")
    print(version)
}
