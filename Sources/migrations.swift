import Foundation

public struct Migration: Sendable {
    public let name: String
    public let sql: String
    public init(name: String, sql: String) {
        self.name = name
        self.sql = sql
    }
}

public enum Migrations {
    public static let all: [Migration] = [
        Migration(
            name: "000_create_migrations_table",
            sql: #"""
                CREATE TABLE migrations (
                  name TEXT PRIMARY KEY,
                  created_at TIMESTAMP NOT NULL DEFAULT NOW()
                );
                """#
        ),
        Migration(
            name: "001_create_hamming_parity_storage",
            sql: #"""
                CREATE TABLE blocks (
                  id UUID PRIMARY KEY,
                  name TEXT NOT NULL,
                  email TEXT UNIQUE NOT NULL,
                  created_at TIMESTAMP NOT NULL DEFAULT NOW()
                );
                """#
        ),
    ]
}
