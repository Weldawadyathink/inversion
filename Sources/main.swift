// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import GRDB

let db = Database()

let hams = try HammingFile(filename: "test-initial.txt")
hams.prettyPrint()

try db.saveParity(parities: hams.parities)

let parities = try db.getParities()

let hams2 = try HammingFile(filename: "test-initial.txt", parities: parities)
hams2.prettyPrint()

let hams3 = try HammingFile(filename: "test-bitrot.txt", parities: parities)
hams3.prettyPrint()
