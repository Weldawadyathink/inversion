// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import GRDB

let db = Database()

let hams = try HammingFileProvider(filename: "test-initial.txt")
print("Initial:")
hams.prettyPrint()

try db.saveParity(parities: hams.parities)

let parities = try db.getParities()

let hams2 = try HammingFileProvider(filename: "test-initial.txt", parities: parities)
print("Initial (reloaded):")
hams2.prettyPrint()

let hams3 = try HammingFileProvider(filename: "test-bitrot.txt", parities: parities)
print("Bitrot:")
hams3.prettyPrint()
let results = hams3.checkParity(repair: true)
print(results)
