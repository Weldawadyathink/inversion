// The Swift Programming Language
// https://docs.swift.org/swift-book

import ArgumentParser
import Foundation
import GRDB

// let db = try await Database()

// let version = try await db.pool.read { db in
//     let rows = try Row.fetchAll(db, sql: "SELECT sqlite_version()")
//     return rows
// }
// print(version)

@main
struct Inversion: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "A version control system for files with Hamming parity.",
    subcommands: [
      Add.self,
      Commit.self,
      Status.self,
      Log.self,
      Init.self,
    ],
    defaultSubcommand: Status.self
  )
}

struct Status: ParsableCommand {
  func run() throws {
    print("Status")
  }
}

struct Add: AsyncParsableCommand {
  func run() async throws {
    // For now, adds a new file without checking database for moves
    let filename = "test-initial.txt"
    let file = try File(externalFilename: filename)
    try await file.save()
    debugPrint(file)
  }
}

struct Commit: ParsableCommand {
  func run() throws {
    print("Commit")
  }
}

struct Init: ParsableCommand {
  func run() throws {
    print("Init")
  }
}

struct Log: ParsableCommand {
  func run() throws {
    print("Log")
  }
}
