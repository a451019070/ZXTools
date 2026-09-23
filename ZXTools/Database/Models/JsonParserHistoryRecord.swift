//
//  JsonParserHistoryRecord.swift
//  Tools
//
//  Created by ZX on 2026/9/22.
//

import Foundation
import GRDB


struct JsonParserHistoryRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "jsonParserHistory"

    var id: String
    var content: String
    var summary: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        content: String,
        summary: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.summary = summary
        self.createdAt = createdAt
    }
}
