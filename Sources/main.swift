// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import GRDB

let hams = try HammingFile(filename: "test-initial.txt")
hams.prettyPrint()

// for (i, block) in blocks.enumerated() {
//     let (parityBits, dataBits) = block
//     let dataText =
//         String(data: dataBits, encoding: .utf8)
//         ?? dataBits.map { String(format: "%02x", $0) }.joined()
//     print("Block \(i): \(parityBits.binaryString) | \(dataText)")
// }

// // Save parity bits to the database
// try dbPool.write { db in
//     try db.execute(sql: "DELETE FROM blocks")
//     for (i, block) in blocks.enumerated() {
//         let (parityBits, _) = block
//         // Convert Data to hex string for SQLite
//         let parityHex = parityBits.map { String(format: "%02x", $0) }.joined()
//         try db.execute(
//             sql: "INSERT INTO blocks (block_number, parity_bits) VALUES (?, ?)",
//             arguments: [i, parityHex])
//     }
// }

// // Helper to load parity bits from DB
// func loadParityBitsFromDB() throws -> [Data] {
//     var parityBitsArray: [Data] = []
//     try dbPool.read { db in
//         let rows = try Row.fetchAll(
//             db, sql: "SELECT block_number, parity_bits FROM blocks ORDER BY block_number ASC")
//         for row in rows {
//             let hexString: String = row["parity_bits"]
//             // Convert hex string back to Data
//             var bytes = [UInt8]()
//             var index = hexString.startIndex
//             while index < hexString.endIndex {
//                 let nextIndex = hexString.index(index, offsetBy: 2)
//                 let byteString = hexString[index..<nextIndex]
//                 if let byte = UInt8(byteString, radix: 16) {
//                     bytes.append(byte)
//                 }
//                 index = nextIndex
//             }
//             parityBitsArray.append(Data(bytes))
//         }
//     }
//     return parityBitsArray
// }

// // Load parity bits from DB
// let storedParityBits = try loadParityBitsFromDB()

// // Check both files
// try Hamming.checkFileParity(filename: "test-initial.txt", parity: storedParityBits)
// try Hamming.checkFileParity(filename: "test-bitrot.txt", parity: storedParityBits)
