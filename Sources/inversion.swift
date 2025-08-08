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
      Check.self,
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

  @Argument(help: "The filename(s) to add to the database.")
  var filename: [String]

  func run() async throws {
    for filename in self.filename {
      var file = try File(filename: filename)
      try file.calculateParity()
      try await file.save()
      debugPrint(file)
    }
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

struct Check: AsyncParsableCommand {

  @Argument(help: "The filename(s) to check.")
  var filename: [String]

  func run() async throws {
    for filename in self.filename {
      var file = try await File.loadFromDatabase(filename: filename)
      if file != nil {
        try await file!.loadFilePartsFromDatabase()
        try file!.checkParity()
      }
    }
  }
}
