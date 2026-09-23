//
//  ColorHistoryRepository.swift
//  Tools
//
//  Created by ZX on 2026/9/21.
//

import Foundation
import GRDB

enum ColorHistoryRepository {
    static func fetchRecent(limit: Int = 10) throws -> [ColorHistoryRecord] {
        try DatabaseManager.shared.read { db in
            try ColorHistoryRecord
                .order(Column("createdAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    static func save(_ record: ColorHistoryRecord) throws {
        try DatabaseManager.shared.write { db in
            try db.execute(
                sql: "DELETE FROM \(ColorHistoryRecord.databaseTableName) WHERE lower(hex) = lower(?)",
                arguments: [record.hex]
            )
            try record.insert(db)
        }
    }

    static func delete(id: String) throws {
        try DatabaseManager.shared.write { db in
            _ = try ColorHistoryRecord.deleteOne(db, key: id)
        }
    }

    static func deleteAll() throws {
        try DatabaseManager.shared.write { db in
            _ = try ColorHistoryRecord.deleteAll(db)
        }
    }
}
