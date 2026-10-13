//
//  ImageCompressHistoryRepository.swift
//  ZXTools
//
//  Created by ZX on 2026/10/13.
//

import Foundation
import GRDB

enum ImageCompressHistoryRepository {
    /// 记录上限，超出后最早的记录会被顶掉
    static let maximumCount = 200

    static func fetchRecent(limit: Int = maximumCount) throws -> [ImageCompressHistoryRecord] {
        try DatabaseManager.shared.read { db in
            try ImageCompressHistoryRecord
                .order(Column("createdAt").desc, Column("rowid").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    static func save(_ record: ImageCompressHistoryRecord, maximumCount: Int = maximumCount) throws {
        try DatabaseManager.shared.write { db in
            try record.insert(db)
            try db.execute(
                sql: """
                    DELETE FROM \(ImageCompressHistoryRecord.databaseTableName)
                    WHERE id NOT IN (
                        SELECT id FROM \(ImageCompressHistoryRecord.databaseTableName)
                        ORDER BY createdAt DESC, rowid DESC
                        LIMIT ?
                    )
                    """,
                arguments: [maximumCount]
            )
        }
    }

    static func delete(id: String) throws {
        try DatabaseManager.shared.write { db in
            _ = try ImageCompressHistoryRecord.deleteOne(db, key: id)
        }
    }

    static func deleteAll() throws {
        try DatabaseManager.shared.write { db in
            _ = try ImageCompressHistoryRecord.deleteAll(db)
        }
    }
}
