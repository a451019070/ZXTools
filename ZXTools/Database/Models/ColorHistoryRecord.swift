//
//  ColorHistoryRecord.swift
//  Tools
//
//  Created by ZX on 2026/9/21.
//

import Foundation
import GRDB

struct ColorHistoryRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "colorHistory"

    var id: String
    var hex: String
    var rgb: String
    var red: Int
    var green: Int
    var blue: Int
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        hex: String,
        rgb: String,
        red: Int,
        green: Int,
        blue: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hex = hex
        self.rgb = rgb
        self.red = red
        self.green = green
        self.blue = blue
        self.createdAt = createdAt
    }
}
