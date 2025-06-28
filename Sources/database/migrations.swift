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
    public static let pragmas: [String] = [
        "PRAGMA foreign_keys = ON;",
        "PRAGMA journal_mode = WAL;",
        "PRAGMA synchronous = NORMAL;",
        "PRAGMA cache_size = -2048;",
        "PRAGMA temp_store = MEMORY;",
        "PRAGMA mmap_size = 268435456;",
        "PRAGMA recursive_triggers = ON;",
        "PRAGMA case_sensitive_like = ON;",
    ]
    public static let all: [Migration] = [
        Migration(
            name: "000_create_migrations_table",
            sql: #"""
                CREATE TABLE migrations (
                    name TEXT PRIMARY KEY,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                """#
        ),
        Migration(
            name: "001_create_hamming_parity_storage",
            sql: #"""
                CREATE TABLE blocks (
                    block_number INTEGER NOT NULL,
                    parity_bits BLOB NOT NULL
                );
                """#
        ),
    ]
}
