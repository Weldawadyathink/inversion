// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import GRDB

let db = try await Database()

let version = try await db.pool.read { db in
    let rows = try Row.fetchAll(db, sql: "SELECT sqlite_version()")
    return rows
}
print(version)

// let hams = try HammingFileProvider(external_filename: "test-initial.txt")
// print("Initial:")
// hams.prettyPrint()

// try db.saveParity(parities: hams.parities)

// let parities = try db.getParities()

// let hams2 = try HammingFileProvider(external_filename: "test-initial.txt")
// print("Initial (reloaded):")
// hams2.prettyPrint()

// let hams3 = try HammingFileProvider(external_filename: "test-bitrot.txt")
// print("Bitrot:")
// hams3.prettyPrint()
// let results = hams3.checkParity(repair: true)
// print(results)
