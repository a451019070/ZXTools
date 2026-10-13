//
//  ImageCompressViewModel.swift
//  ZXTools
//
//  Created by ZX on 2026/10/13.
//

import AppKit
import Combine
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 选项枚举

enum ImageOutputFormat: String, CaseIterable, Identifiable {
    case keep
    case png
    case jpeg
    case webp
    case avif
    case smallest

    var id: Self { self }

    var title: String {
        switch self {
        case .keep: return "保持原格式"
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .webp: return "WebP"
        case .avif: return "AVIF"
        case .smallest: return "自动选最小（保留透明）"
        }
    }

    var mimeTypes: [String] {
        switch self {
        case .keep: return []
        case .png: return ["image/png"]
        case .jpeg: return ["image/jpeg"]
        case .webp: return ["image/webp"]
        case .avif: return ["image/avif"]
        case .smallest: return ["image/webp", "image/avif", "image/png"]
        }
    }
}

enum ImageResizeMode: String, CaseIterable, Identifiable {
    case none
    case scale
    case fit
    case cover
    case thumb

    var id: Self { self }

    var title: String {
        switch self {
        case .none: return "不缩放"
        case .scale: return "等比缩放（宽或高二选一）"
        case .fit: return "适应（不超过宽高）"
        case .cover: return "填充裁剪"
        case .thumb: return "智能缩略图"
        }
    }

    var needsBothSides: Bool {
        self == .fit || self == .cover || self == .thumb
    }
}

// MARK: - 列表项

struct ImageCompressItem: Identifiable {
    enum Status: Equatable {
        case waiting
        case compressing
        case done
        case failed(String)
    }

    let id = UUID()
    let fileURL: URL
    let fileName: String
    let originalData: Data
    let thumbnail: NSImage?
    var status: Status = .waiting
    var result: TinyPNGResult?

    var originalSize: Int { originalData.count }
    var compressedSize: Int? { result?.outputSize }

    var savedRatio: Double? {
        guard let compressedSize, originalSize > 0 else { return nil }
        return 1 - Double(compressedSize) / Double(originalSize)
    }
}

// MARK: - ViewModel

@MainActor
final class ImageCompressViewModel: ObservableObject {
    private static let keychainAccount = "tinypng-api-key"
    private static let maxConcurrent = 4
    private static let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "avif"]

    // API Key
    @Published var apiKey: String
    @Published private(set) var keyMessage: String?
    @Published private(set) var keyMessageIsError = false
    @Published private(set) var isValidatingKey = false
    @Published private(set) var compressionCount: Int?

    // 选项
    @Published var outputFormat: ImageOutputFormat = .keep
    @Published var resizeMode: ImageResizeMode = .none
    @Published var resizeWidth = ""
    @Published var resizeHeight = ""
    @Published var preserveCopyright = false
    @Published var preserveCreation = false
    @Published var preserveLocation = false
    @Published var appendSuffix = true

    // 状态
    @Published private(set) var items: [ImageCompressItem] = []
    @Published private(set) var isCompressing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var infoMessage: String?

    // 链接添加
    @Published var linkInput = ""
    @Published private(set) var isDownloading = false

    private var compressTask: Task<Void, Never>?

    // 压缩记录
    @Published private(set) var history: [ImageCompressHistoryRecord] = []

    init() {
        apiKey = KeychainStore.read(account: Self.keychainAccount) ?? ""
    }

    // MARK: - 压缩记录

    func loadHistory() {
        do {
            history = try ImageCompressHistoryRepository.fetchRecent()
        } catch {
            history = []
            errorMessage = "读取压缩记录失败：\(error.localizedDescription)"
        }
    }

    func deleteHistory(_ record: ImageCompressHistoryRecord) {
        do {
            try ImageCompressHistoryRepository.delete(id: record.id)
            history.removeAll { $0.id == record.id }
        } catch {
            errorMessage = "删除压缩记录失败：\(error.localizedDescription)"
        }
    }

    func clearHistory() {
        do {
            try ImageCompressHistoryRepository.deleteAll()
            history = []
        } catch {
            errorMessage = "清空压缩记录失败：\(error.localizedDescription)"
        }
    }

    func copySource(of record: ImageCompressHistoryRecord) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(record.source, forType: .string)
        infoMessage = record.isRemote ? "已复制图片链接" : "已复制文件路径"
    }

    /// 点击记录：网络图片复制链接，本地图片在 Finder 中选中该文件
    func openSource(of record: ImageCompressHistoryRecord) {
        if record.isRemote {
            copySource(of: record)
        } else {
            revealInFinder(record)
        }
    }

    func revealInFinder(_ record: ImageCompressHistoryRecord) {
        guard !record.isRemote else { return }
        let url = URL(fileURLWithPath: record.source)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            errorMessage = nil
            return
        }

        // 原文件被移动或删除时，退而打开它原来所在的文件夹
        let folder = url.deletingLastPathComponent()
        if fileManager.fileExists(atPath: folder.path) {
            NSWorkspace.shared.open(folder)
            errorMessage = "原文件已不存在，已打开它原来所在的文件夹"
        } else {
            errorMessage = "原文件和所在文件夹都已不存在或已被移动"
        }
    }

    /// 压缩成功后写入一条记录；缩略图在后台生成，写库完成后刷新列表
    private func recordHistory(for id: UUID) {
        guard let item = items.first(where: { $0.id == id }), let result = item.result else { return }

        let source = item.fileURL.isFileURL ? item.fileURL.path : item.fileURL.absoluteString
        let fileName = item.fileName
        let originalSize = item.originalSize
        let compressedSize = result.outputSize
        let format = result.fileExtension
        let data = item.originalData

        Task {
            let thumbnail = await Self.makeHistoryThumbnail(from: data)
            let record = ImageCompressHistoryRecord(
                fileName: fileName,
                source: source,
                originalSize: originalSize,
                compressedSize: compressedSize,
                outputFormat: format,
                thumbnail: thumbnail
            )
            do {
                try ImageCompressHistoryRepository.save(record)
                loadHistory()
            } catch {
                errorMessage = "保存压缩记录失败：\(error.localizedDescription)"
            }
        }
    }

    /// 最长边 96px、白底 JPEG，仅用于在记录里辨认图片
    private nonisolated static func makeHistoryThumbnail(from data: Data) async -> Data? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 96
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
                  let context = CGContext(
                    data: nil,
                    width: cgImage.width,
                    height: cgImage.height,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return nil }

            let rect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(rect)
            context.draw(cgImage, in: rect)

            guard let flattened = context.makeImage() else { return nil }
            return NSBitmapImageRep(cgImage: flattened)
                .representation(using: .jpeg, properties: [.compressionFactor: 0.7])
        }.value
    }

    // MARK: - 统计

    var doneItems: [ImageCompressItem] { items.filter { $0.status == .done && $0.result != nil } }

    var pendingCount: Int {
        items.filter {
            switch $0.status {
            case .waiting, .failed: return true
            default: return false
            }
        }.count
    }

    var totalOriginalSize: Int { doneItems.reduce(0) { $0 + $1.originalSize } }
    var totalCompressedSize: Int { doneItems.reduce(0) { $0 + ($1.compressedSize ?? 0) } }

    var totalSavedRatio: Double? {
        guard totalOriginalSize > 0 else { return nil }
        return 1 - Double(totalCompressedSize) / Double(totalOriginalSize)
    }

    var hasKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - API Key

    func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = trimmed
        if trimmed.isEmpty {
            KeychainStore.delete(account: Self.keychainAccount)
            setKeyMessage("已清除 API Key", isError: false)
        } else if KeychainStore.save(trimmed, account: Self.keychainAccount) {
            setKeyMessage("已保存到钥匙串", isError: false)
        } else {
            setKeyMessage("保存到钥匙串失败", isError: true)
        }
    }

    func validateKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setKeyMessage(TinyPNGError.missingKey.localizedDescription, isError: true)
            return
        }
        apiKey = trimmed
        isValidatingKey = true
        keyMessage = nil

        Task {
            defer { isValidatingKey = false }
            do {
                let count = try await TinyPNGClient(apiKey: trimmed).validate()
                if let count { compressionCount = count }
                KeychainStore.save(trimmed, account: Self.keychainAccount)
                setKeyMessage("API Key 有效，已保存到钥匙串", isError: false)
            } catch {
                setKeyMessage(error.localizedDescription, isError: true)
            }
        }
    }

    private func setKeyMessage(_ message: String, isError: Bool) {
        keyMessage = message
        keyMessageIsError = isError
    }

    // MARK: - 添加文件

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "选择要压缩的图片或文件夹"
        panel.prompt = "添加"
        guard panel.runModal() == .OK else { return }
        addFiles(panel.urls)
    }

    func addFiles(_ urls: [URL]) {
        let candidates = expand(urls)
        guard !candidates.isEmpty else {
            errorMessage = "没有找到可压缩的图片（支持 PNG / JPEG / WebP / AVIF）"
            return
        }
        errorMessage = nil
        infoMessage = nil

        let existing = Set(items.map(\.fileURL))
        let fresh = candidates.filter { !existing.contains($0) }

        Task {
            var failedNames: [String] = []
            for url in fresh {
                let data = await Self.readData(at: url)
                guard let data, !data.isEmpty else {
                    failedNames.append(url.lastPathComponent)
                    continue
                }
                items.append(
                    ImageCompressItem(
                        fileURL: url,
                        fileName: url.lastPathComponent,
                        originalData: data,
                        thumbnail: Self.makeThumbnail(from: data)
                    )
                )
            }
            if !failedNames.isEmpty {
                errorMessage = "无法读取：" + failedNames.prefix(3).joined(separator: "、")
                    + (failedNames.count > 3 ? " 等 \(failedNames.count) 个文件" : "")
            }
        }
    }

    private func expand(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        let fileManager = FileManager.default

        for url in urls {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }

            if isDirectory.boolValue {
                let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
                while let child = enumerator?.nextObject() as? URL {
                    if Self.isSupported(child) { result.append(child) }
                }
            } else if Self.isSupported(url) {
                result.append(url)
            }
        }
        return result
    }

    private static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - 通过链接添加

    /// 支持一次粘贴多个链接，用换行、空格或逗号分隔
    func addRemoteLinks() {
        let urls = Self.parseLinks(linkInput)
        guard !urls.isEmpty else {
            errorMessage = "请输入有效的图片链接（需以 http:// 或 https:// 开头）"
            return
        }
        guard !isDownloading else { return }

        let existing = Set(items.map(\.fileURL))
        let fresh = urls.filter { !existing.contains($0) }
        guard !fresh.isEmpty else {
            errorMessage = "这些链接已经在列表中"
            return
        }

        errorMessage = nil
        infoMessage = nil
        isDownloading = true

        Task {
            defer { isDownloading = false }
            var failures: [String] = []
            var added = 0

            for url in fresh {
                switch await Self.download(url) {
                case .success(let data):
                    items.append(
                        ImageCompressItem(
                            fileURL: url,
                            fileName: Self.remoteFileName(for: url, data: data),
                            originalData: data,
                            thumbnail: Self.makeThumbnail(from: data)
                        )
                    )
                    added += 1
                case .failure(let error):
                    failures.append("\(url.host() ?? url.absoluteString)：\(error.localizedDescription)")
                }
            }

            if added > 0, failures.isEmpty {
                linkInput = ""
            }
            if !failures.isEmpty {
                errorMessage = "有 \(failures.count) 个链接下载失败 — "
                    + failures.prefix(2).joined(separator: "；")
                    + (failures.count > 2 ? " 等" : "")
            }
            if added > 0 {
                infoMessage = "已从链接添加 \(added) 张图片"
            }
        }
    }

    private static func parseLinks(_ text: String) -> [URL] {
        var seen = Set<URL>()
        return text
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",，")))
            .compactMap { token -> URL? in
                let trimmed = token.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty,
                      let url = URL(string: trimmed),
                      let scheme = url.scheme?.lowercased(),
                      scheme == "http" || scheme == "https",
                      url.host() != nil else { return nil }
                return url
            }
            .filter { seen.insert($0).inserted }
    }

    private enum DownloadError: LocalizedError {
        case status(Int)
        case notImage
        case unsupported(String)
        case empty

        var errorDescription: String? {
            switch self {
            case .status(let code): return "服务器返回 \(code)"
            case .notImage: return "链接内容不是图片"
            case .unsupported(let ext): return "不支持的图片格式（\(ext)）"
            case .empty: return "内容为空"
            }
        }
    }

    private nonisolated static func download(_ url: URL) async -> Result<Data, Error> {
        do {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 180
            let session = URLSession(configuration: configuration)
            defer { session.finishTasksAndInvalidate() }

            var request = URLRequest(url: url)
            request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
                forHTTPHeaderField: "User-Agent"
            )

            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return .failure(DownloadError.status(http.statusCode))
            }
            guard !data.isEmpty else { return .failure(DownloadError.empty) }

            // 以实际内容判断类型，避免把 HTML 页面或错误页当作图片
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let typeIdentifier = CGImageSourceGetType(source) as String? else {
                return .failure(DownloadError.notImage)
            }
            let ext = UTType(typeIdentifier)?.preferredFilenameExtension?.lowercased() ?? ""
            guard supportedExtensions.contains(ext) else {
                return .failure(DownloadError.unsupported(ext.isEmpty ? typeIdentifier : ext))
            }
            return .success(data)
        } catch {
            return .failure(error)
        }
    }

    private static func remoteFileName(for url: URL, data: Data) -> String {
        var name = url.lastPathComponent
        if name.isEmpty || name == "/" {
            name = url.host() ?? "image"
        }
        if !supportedExtensions.contains((name as NSString).pathExtension.lowercased()),
           let source = CGImageSourceCreateWithData(data as CFData, nil),
           let identifier = CGImageSourceGetType(source) as String?,
           let ext = UTType(identifier)?.preferredFilenameExtension {
            name = (name as NSString).deletingPathExtension + "." + ext
        }
        return name
    }

    private nonisolated static func readData(at url: URL) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            return try? Data(contentsOf: url)
        }.value
    }

    private static func makeThumbnail(from data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 128
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    // MARK: - 列表管理

    func remove(_ item: ImageCompressItem) {
        guard !isCompressing else { return }
        items.removeAll { $0.id == item.id }
    }

    func clearAll() {
        cancelCompression()
        items.removeAll()
        errorMessage = nil
        infoMessage = nil
    }

    /// 把已完成 / 失败的项重置为待压缩（修改选项后重新压缩）
    func resetAll() {
        guard !isCompressing else { return }
        for index in items.indices {
            items[index].status = .waiting
            items[index].result = nil
        }
    }

    // MARK: - 压缩

    func startCompression() {
        guard !isCompressing else { return }
        guard hasKey else {
            errorMessage = TinyPNGError.missingKey.localizedDescription
            return
        }

        let options: TinyPNGOptions
        do {
            options = try buildOptions()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let jobs = items
            .filter { $0.status == .waiting || { if case .failed = $0.status { return true } else { return false } }($0) }
            .map { (id: $0.id, data: $0.originalData) }
        guard !jobs.isEmpty else {
            errorMessage = "没有待压缩的图片"
            return
        }

        errorMessage = nil
        infoMessage = nil
        isCompressing = true

        let client = TinyPNGClient(apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        let limit = Self.maxConcurrent

        compressTask = Task {
            await run(jobs: jobs, client: client, options: options, limit: limit)
            isCompressing = false
            compressTask = nil
        }
    }

    func cancelCompression() {
        compressTask?.cancel()
    }

    private func run(
        jobs: [(id: UUID, data: Data)],
        client: TinyPNGClient,
        options: TinyPNGOptions,
        limit: Int
    ) async {
        var iterator = jobs.makeIterator()
        var halted = false

        await withTaskGroup(of: (UUID, Result<TinyPNGResult, Error>).self) { group in
            for _ in 0..<limit {
                guard let job = iterator.next() else { break }
                update(job.id) { $0.status = .compressing }
                group.addTask { await Self.process(job, client: client, options: options) }
            }

            for await (id, outcome) in group {
                switch outcome {
                case .success(let result):
                    update(id) {
                        $0.result = result
                        $0.status = .done
                    }
                    if let count = result.compressionCount { compressionCount = count }
                    recordHistory(for: id)

                case .failure(let error):
                    if Self.isCancellation(error) {
                        update(id) { $0.status = .waiting }
                    } else {
                        update(id) { $0.status = .failed(error.localizedDescription) }
                        if Self.isFatal(error), !halted {
                            halted = true
                            errorMessage = error.localizedDescription
                            group.cancelAll()
                        }
                    }
                }

                if !halted, !Task.isCancelled, let job = iterator.next() {
                    update(job.id) { $0.status = .compressing }
                    group.addTask { await Self.process(job, client: client, options: options) }
                }
            }
        }
    }

    private nonisolated static func process(
        _ job: (id: UUID, data: Data),
        client: TinyPNGClient,
        options: TinyPNGOptions
    ) async -> (UUID, Result<TinyPNGResult, Error>) {
        do {
            let result = try await client.compress(job.data, options: options)
            return (job.id, .success(result))
        } catch {
            return (job.id, .failure(error))
        }
    }

    private func update(_ id: UUID, _ change: (inout ImageCompressItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        if case TinyPNGError.network(let inner) = error {
            return isCancellation(inner)
        }
        return false
    }

    /// 这类错误继续请求没有意义，直接停止整个批次
    private static func isFatal(_ error: Error) -> Bool {
        switch error as? TinyPNGError {
        case .missingKey, .unauthorized, .limitReached: return true
        default: return false
        }
    }

    // MARK: - 选项校验

    private func buildOptions() throws -> TinyPNGOptions {
        var options = TinyPNGOptions()
        options.convertTypes = outputFormat.mimeTypes

        var preserve: [String] = []
        if preserveCopyright { preserve.append("copyright") }
        if preserveCreation { preserve.append("creation") }
        if preserveLocation { preserve.append("location") }
        options.preserve = preserve

        guard resizeMode != .none else { return options }

        let widthText = resizeWidth.trimmingCharacters(in: .whitespaces)
        let heightText = resizeHeight.trimmingCharacters(in: .whitespaces)
        let width = Int(widthText)
        let height = Int(heightText)

        if !widthText.isEmpty, (width ?? 0) <= 0 {
            throw OptionError.invalid("宽度必须是大于 0 的整数")
        }
        if !heightText.isEmpty, (height ?? 0) <= 0 {
            throw OptionError.invalid("高度必须是大于 0 的整数")
        }

        if resizeMode.needsBothSides {
            guard width != nil, height != nil else {
                throw OptionError.invalid("当前缩放方式需要同时填写宽度和高度")
            }
        } else {
            guard (width != nil) != (height != nil) else {
                throw OptionError.invalid("等比缩放只能填写宽度或高度其中之一")
            }
        }

        options.resize = TinyPNGOptions.Resize(method: resizeMode.rawValue, width: width, height: height)
        return options
    }

    private enum OptionError: LocalizedError {
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .invalid(let message): return message
            }
        }
    }

    // MARK: - 保存

    func saveAll() {
        let finished = doneItems
        guard !finished.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择保存压缩结果的文件夹"
        panel.prompt = "保存到此处"
        guard panel.runModal() == .OK, let directory = panel.url else { return }

        var usedNames = Set<String>()
        var savedURLs: [URL] = []
        var failedCount = 0

        for item in finished {
            guard let result = item.result else { continue }
            let name = uniqueName(for: item, result: result, used: &usedNames)
            let target = directory.appendingPathComponent(name)
            do {
                try result.data.write(to: target, options: .atomic)
                savedURLs.append(target)
            } catch {
                failedCount += 1
            }
        }

        if !savedURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(savedURLs)
        }
        if failedCount > 0 {
            errorMessage = "有 \(failedCount) 个文件保存失败，请确认文件夹的写入权限"
        } else {
            errorMessage = nil
            infoMessage = "已保存 \(savedURLs.count) 个文件"
        }
    }

    func save(_ item: ImageCompressItem) {
        guard let result = item.result else { return }
        var used = Set<String>()

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = uniqueName(for: item, result: result, used: &used)
        panel.message = "保存压缩后的图片"
        guard panel.runModal() == .OK, let target = panel.url else { return }

        do {
            try result.data.write(to: target, options: .atomic)
            errorMessage = nil
            infoMessage = "已保存 \(target.lastPathComponent)"
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func uniqueName(
        for item: ImageCompressItem,
        result: TinyPNGResult,
        used: inout Set<String>
    ) -> String {
        let base = (item.fileName as NSString).deletingPathExtension
        let stem = appendSuffix ? base + "-tiny" : base
        var candidate = "\(stem).\(result.fileExtension)"
        var index = 2
        while used.contains(candidate.lowercased()) {
            candidate = "\(stem)-\(index).\(result.fileExtension)"
            index += 1
        }
        used.insert(candidate.lowercased())
        return candidate
    }

    // MARK: - 展示辅助

    static func formatSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    static func formatPercent(_ ratio: Double) -> String {
        let percent = Int((ratio * 100).rounded())
        return percent >= 0 ? "-\(percent)%" : "+\(-percent)%"
    }
}
