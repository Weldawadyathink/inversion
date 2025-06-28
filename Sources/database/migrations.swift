import Foundation

struct Migration: Sendable {
    let name: String
    let sql: String
    init(name: String, sql: String) {
        self.name = name
        self.sql = sql
    }
}

enum Migrations {
    static let pragmas: [String] = [
        "PRAGMA foreign_keys = ON;",
        "PRAGMA journal_mode = WAL;",
        "PRAGMA synchronous = NORMAL;",
        "PRAGMA cache_size = -2048;",
        "PRAGMA temp_store = MEMORY;",
        "PRAGMA mmap_size = 268435456;",
        "PRAGMA recursive_triggers = ON;",
        "PRAGMA case_sensitive_like = ON;",
        "PRAGMA integrity_check;",
    ]
    static let all: [Migration] = [
        Migration(
            name: "000_create_migrations_table",
            sql: #"""
                CREATE TABLE migrations (
                    name TEXT PRIMARY KEY,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                ) STRICT;
                """#
        ),
        Migration(
            name: "001_create_hamming_parity_storage",
            sql: #"""
                CREATE TABLE blocks (
                    block_number INTEGER NOT NULL,
                    parity_bits BLOB NOT NULL
                ) STRICT;
                """#
        ),
    ]
}
