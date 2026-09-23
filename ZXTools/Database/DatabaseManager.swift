//
//  DatabaseManager.swift
//  Tools
//
//  Created by ZX on 2026/9/21.
//

import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    let databasePool: DatabasePool
    
    private init() {
        do {
            let databaseURL = try Self.makeDatabaseURL()
            databasePool = try DatabasePool(path: databaseURL.path)
            try Self.makeMigrator().migrate(databasePool)
        } catch {
            fatalError("数据库初始化失败：\(error.localizedDescription)")
        }
    }
    
    func read<T>(_ block: (Database) throws -> T) throws -> T {
        try databasePool.read(block)
    }
    
    func write<T>(_ block: (Database) throws -> T) throws -> T {
        try databasePool.write(block)
    }
    
    private static func makeDatabaseURL() throws -> URL {
        let fileManager = FileManager.default
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "ZX.Tools"
        let databaseDirectory = applicationSupportURL.appendingPathComponent(
            bundleIdentifier,
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: databaseDirectory,
            withIntermediateDirectories: true
        )
        return databaseDirectory.appendingPathComponent("Tools.sqlite")
    }
    
}

extension DatabaseManager {
    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        createColorTable(&migrator)
        createJsonParserTable(&migrator)

        return migrator
    }
    
    private static func createColorTable(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("createColorHistory") { db in
            try db.create(table: ColorHistoryRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("hex", .text).notNull().unique(onConflict: .replace)
                table.column("rgb", .text).notNull()
                table.column("red", .integer).notNull()
                table.column("green", .integer).notNull()
                table.column("blue", .integer).notNull()
                table.column("createdAt", .datetime).notNull().indexed()
            }
        }
    }

    private static func createJsonParserTable(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("createJsonParserHistory") { db in
            try db.create(table: JsonParserHistoryRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("content", .text).notNull()
                table.column("summary", .text).notNull()
                table.column("createdAt", .datetime).notNull().indexed()
            }
        }
    }

}
