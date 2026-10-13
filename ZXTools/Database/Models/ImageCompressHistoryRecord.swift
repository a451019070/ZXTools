//
//  ImageCompressHistoryRecord.swift
//  ZXTools
//
//  Created by ZX on 2026/10/13.
//

import Foundation
import GRDB

struct ImageCompressHistoryRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "imageCompressHistory"

    var id: String
    /// 压缩前的文件名
    var fileName: String
    /// 压缩前的来源：本地文件路径，或图片链接
    var source: String
    var originalSize: Int
    var compressedSize: Int
    /// 输出格式扩展名，例如 png / webp
    var outputFormat: String
    /// 约 96px 的 JPEG 缩略图，仅用于辨认
    var thumbnail: Data?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        fileName: String,
        source: String,
        originalSize: Int,
        compressedSize: Int,
        outputFormat: String,
        thumbnail: Data?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.source = source
        self.originalSize = originalSize
        self.compressedSize = compressedSize
        self.outputFormat = outputFormat
        self.thumbnail = thumbnail
        self.createdAt = createdAt
    }

    var isRemote: Bool {
        let lowercased = source.lowercased()
        return lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
    }

    var savedRatio: Double? {
        guard originalSize > 0 else { return nil }
        return 1 - Double(compressedSize) / Double(originalSize)
    }
}
