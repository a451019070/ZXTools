//
//  JsonParserHistoryRepository.swift
//  Tools
//
//  Created by CodeBuddy on 2026/9/22.
//

import Foundation
import GRDB

enum JsonParserHistoryRepository {
    static func fetchRecent(limit: Int = 50) throws -> [JsonParserHistoryRecord] {
        try DatabaseManager.shared.read { db in
            try JsonParserHistoryRecord
                .order(Column("createdAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    static func save(_ record: JsonParserHistoryRecord, maximumCount: Int = 50) throws {
        try DatabaseManager.shared.write { db in
            try db.execute(
                sql: "DELETE FROM \(JsonParserHistoryRecord.databaseTableName) WHERE content = ?",
                arguments: [record.content]
            )
            try record.insert(db)
            try db.execute(
                sql: """
                    DELETE FROM \(JsonParserHistoryRecord.databaseTableName)
                    WHERE id NOT IN (
                        SELECT id FROM \(JsonParserHistoryRecord.databaseTableName)
                        ORDER BY createdAt DESC
                        LIMIT ?
                    )
                    """,
                arguments: [maximumCount]
            )
        }
    }

    static func delete(id: String) throws {
        try DatabaseManager.shared.write { db in
            _ = try JsonParserHistoryRecord.deleteOne(db, key: id)
        }
    }

    static func deleteAll() throws {
        try DatabaseManager.shared.write { db in
            _ = try JsonParserHistoryRecord.deleteAll(db)
        }
    }
}
