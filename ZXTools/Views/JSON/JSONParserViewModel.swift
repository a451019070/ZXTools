//
//  JSONParserViewModel.swift
//  Tools
//
//  Created by CodeBuddy on 2026/9/22.
//

import AppKit
import Combine
import Foundation

// MARK: - JSON 数据模型
struct JSONMember: Hashable {
    let key: String
    let value: JSONValue
}

indirect enum JSONValue: Hashable {
    case object([JSONMember])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    var isContainer: Bool {
        switch self {
        case .object, .array: return true
        default: return false
        }
    }
}

extension JSONValue {
    /// 把 JSONSerialization 解析后的 Any 转成 JSONValue
    static func from(_ any: Any) -> JSONValue {
        if any is NSNull { return .null }

        if let dict = any as? [String: Any] {
            let ordered: [JSONMember] = dict.keys.sorted().map { key in
                JSONMember(key: key, value: JSONValue.from(dict[key]!))
            }
            return .object(ordered)
        }

        if let arr = any as? [Any] {
            return .array(arr.map(JSONValue.from))
        }

        // 区分 Bool 和数字：检查 CFBoolean 类型
        if let number = any as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        }

        if let string = any as? String { return .string(string) }
        return .string(String(describing: any))
    }

    static func formatNumber(_ n: Double) -> String {
        if n.rounded() == n && abs(n) < 1e15 {
            return String(Int64(n))
        }
        return String(n)
    }

    /// 叶子节点显示的文本（用于搜索 value）
    var leafText: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return JSONValue.formatNumber(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        default: return nil
        }
    }

    /// 按文档顺序收集 key 或 value 命中的节点路径（路径规则与树展开一致）
    func collectMatches(query: String,
                        label: String? = nil,
                        path: String = "root",
                        into result: inout [String]) {
        let keyHit = label?.range(of: query, options: .caseInsensitive) != nil
        let valueHit = leafText?.range(of: query, options: .caseInsensitive) != nil
        if keyHit || valueHit { result.append(path) }

        switch self {
        case .object(let pairs):
            for (index, member) in pairs.enumerated() {
                member.value.collectMatches(query: query, label: member.key,
                                            path: "\(path).o\(index)", into: &result)
            }
        case .array(let items):
            for (index, item) in items.enumerated() {
                item.collectMatches(query: query, label: nil,
                                    path: "\(path).a\(index)", into: &result)
            }
        default:
            break
        }
    }

    func containerNodes(path: String = "root", depth: Int = 0) -> [(path: String, depth: Int)] {
        switch self {
        case .object(let pairs):
            return [(path, depth)] + pairs.enumerated().flatMap { index, member in
                member.value.containerNodes(path: "\(path).o\(index)", depth: depth + 1)
            }
        case .array(let items):
            return [(path, depth)] + items.enumerated().flatMap { index, item in
                item.containerNodes(path: "\(path).a\(index)", depth: depth + 1)
            }
        default:
            return []
        }
    }
}

enum JSONParser {
    /// 自动解包被 JSON 字符串包裹的内容
    static func unwrapString(
        _ raw: Any,
        depth: Int = 0,
        limit: Int = 16
    ) -> (value: Any, unwrapped: Int) {
        guard depth < limit,
              let string = raw as? String else {
            return (raw, depth)
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first,
              first == "{" || first == "[" || first == "\"",
              let data = trimmed.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) else {
            return (raw, depth)
        }

        return unwrapString(parsed, depth: depth + 1, limit: limit)
    }

    /// 处理缺少外层引号、但内部带 \" 转义的 JSON 文本，例如 [{\"a\":1}]。
    /// 补上外层引号后当作 JSON 字符串去转义，仅当结果确实能解包成对象/数组时才返回。
    static func parseEscapedText(_ text: String) -> Any? {
        guard text.contains("\\\""),
              let data = ("\"" + text + "\"").data(using: .utf8),
              let unescaped = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? String
        else {
            return nil
        }
        let result = unwrapString(unescaped)
        guard result.unwrapped > 0,
              result.value is [String: Any] || result.value is [Any] else {
            return nil
        }
        return unescaped
    }

    static func rootDescription(of value: Any) -> String {
        if let array = value as? [Any] {
            return "根节点类型：数组，共 \(array.count) 项"
        }
        if let dictionary = value as? [String: Any] {
            return "根节点类型：对象，共 \(dictionary.count) 个键"
        }
        if value is NSNull {
            return "根节点类型：null"
        }
        if let number = value as? NSNumber {
            return CFGetTypeID(number) == CFBooleanGetTypeID()
                ? "根节点类型：布尔值"
                : "根节点类型：数字"
        }
        if let string = value as? String {
            return string.count > 60
                ? "根节点类型：字符串（长度 \(string.count)）"
                : "根节点类型：字符串"
        }
        return "根节点类型：未知"
    }
}

// MARK: - 示例数据

let jsonSample: [String: Any] = [
    "user": [
        "id": 1024,
        "name": "Alice",
        "active": true,
        "roles": ["admin", "editor"],
        "profile": [
            "city": "Shanghai",
            "score": 98.5,
            "tags": ["frontend", "json", "tools"]
        ]
    ],
    "meta": [
        "version": 1,
        "generatedAt": "2026-04-21T22:00:00+08:00"
    ]
]

@MainActor
final class JSONParserViewModel: ObservableObject {
    @Published var inputText = ""
    @Published private(set) var statusMessage = "支持对象、数组、布尔值、数字和字符串"
    @Published private(set) var isError = false
    @Published private(set) var metaMessage = ""
    @Published private(set) var tree: JSONValue?
    @Published var expansions: [String: Bool] = [:]
    @Published private(set) var deepestLevel = 0
    @Published private(set) var history: [JsonParserHistoryRecord] = []
    @Published var searchText = "" {
        didSet {
            if oldValue != searchText { refreshSearch() }
        }
    }
    @Published private(set) var searchMatches: [String] = []
    @Published private(set) var currentMatchIndex = 0
    @Published private(set) var scrollToken = 0

    var currentMatchID: String? {
        searchMatches.indices.contains(currentMatchIndex) ? searchMatches[currentMatchIndex] : nil
    }

    func refreshSearch() {
        guard let tree, !searchText.isEmpty else {
            searchMatches = []
            currentMatchIndex = 0
            return
        }
        var result: [String] = []
        tree.collectMatches(query: searchText, into: &result)
        searchMatches = result
        currentMatchIndex = 0
        guard !result.isEmpty else { return }
        expandAncestors(of: result)
        scrollToken += 1
    }

    func goToNextMatch() {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
        revealCurrentMatch()
    }

    func goToPreviousMatch() {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + searchMatches.count) % searchMatches.count
        revealCurrentMatch()
    }

    private func revealCurrentMatch() {
        if let id = currentMatchID { expandAncestors(of: [id]) }
        scrollToken += 1
    }

    private func expandAncestors(of paths: [String]) {
        var newExpansions = expansions
        for path in paths {
            let components = path.split(separator: ".").map(String.init)
            guard components.count > 1 else { continue }
            for end in 1..<components.count {
                newExpansions[components[0..<end].joined(separator: ".")] = true
            }
        }
        if newExpansions != expansions { expansions = newExpansions }
    }

    var areAllContainersExpanded: Bool {
        !collapsibleNodes.isEmpty && collapsibleNodes.allSatisfy { isExpanded($0) }
    }

    func load() {
        loadHistory()
        loadExample()
    }

    func parseInput() {
        parse()
    }

    func formatInput() {
        parse(formatter: [.prettyPrinted, .sortedKeys])
    }

    func compressInput() {
        parse(formatter: [.sortedKeys])
    }

    func loadExample() {
        guard let data = try? JSONSerialization.data(
            withJSONObject: jsonSample,
            options: [.prettyPrinted, .sortedKeys]
        ), let string = String(data: data, encoding: .utf8) else {
            return
        }
        inputText = string
        parse(savesHistory: false)
    }

    func clearAll() {
        inputText = ""
        tree = nil
        statusMessage = "支持对象、数组、布尔值、数字和字符串"
        isError = false
        metaMessage = ""
        deepestLevel = 0
        expansions = [:]
        refreshSearch()
    }

    func copyResult() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusMessage = "没有可复制的内容"
            isError = true
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        statusMessage = "已复制到剪贴板"
        isError = false
    }

    func loadHistory() {
        do {
            history = try JsonParserHistoryRepository.fetchRecent()
        } catch {
            showHistoryError(error)
        }
    }

    func reuseHistory(_ item: JsonParserHistoryRecord) {
        inputText = item.content
        parse(savesHistory: false)
    }

    func deleteHistory(_ item: JsonParserHistoryRecord) {
        do {
            try JsonParserHistoryRepository.delete(id: item.id)
            history.removeAll { $0.id == item.id }
        } catch {
            showHistoryError(error)
        }
    }

    func deleteHistory(at offsets: IndexSet) {
        let items = offsets.compactMap { index in
            history.indices.contains(index) ? history[index] : nil
        }
        items.forEach(deleteHistory)
    }

    func clearHistory() {
        do {
            try JsonParserHistoryRepository.deleteAll()
            history = []
        } catch {
            showHistoryError(error)
        }
    }

    func toggleAll() {
        let shouldExpand = !areAllContainersExpanded
        var newExpansions = Dictionary(
            uniqueKeysWithValues: collapsibleNodes.map { ($0.path, shouldExpand) }
        )
        newExpansions["root"] = true
        expansions = newExpansions
    }

    func toggleLevel(_ level: Int) {
        let targetNodes = nodes.filter { $0.depth == level }
        guard !targetNodes.isEmpty else { return }

        let shouldExpand = !targetNodes.allSatisfy { isExpanded($0) }
        var newExpansions = expansions
        if shouldExpand {
            for node in nodes where node.depth < level {
                newExpansions[node.path] = true
            }
        }
        for node in targetNodes {
            newExpansions[node.path] = shouldExpand
        }
        expansions = newExpansions
    }

    func isLevelExpanded(_ level: Int) -> Bool {
        let targetNodes = nodes.filter { $0.depth == level }
        return !targetNodes.isEmpty && targetNodes.allSatisfy { isExpanded($0) }
    }

    func levelButtonTitle(_ level: Int) -> String {
        (isLevelExpanded(level) ? "折叠" : "展开") + "\(level)级"
    }

    private func parse(
        formatter: JSONSerialization.WritingOptions? = nil,
        savesHistory: Bool = true
    ) {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "请输入需要解析的 JSON 内容"
            isError = false
            tree = nil
            metaMessage = ""
            refreshSearch()
            return
        }
        guard let data = trimmed.data(using: .utf8) else {
            showError(message: "输入不是有效的 UTF-8 文本")
            return
        }

        let raw: Any
        var isEscapedText = false
        do {
            raw = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            guard let escaped = JSONParser.parseEscapedText(trimmed) else {
                showError(message: "错误：\(error.localizedDescription)")
                return
            }
            raw = escaped
            isEscapedText = true
        }

        let (unwrappedValue, unwrapped) = JSONParser.unwrapString(raw)
        let typed = JSONValue.from(unwrappedValue)
        tree = typed
        expansions = [:]
        deepestLevel = typed.containerNodes().map(\.depth).max() ?? 0
        isError = false
        refreshSearch()

        let meta = JSONParser.rootDescription(of: unwrappedValue)
        if isEscapedText {
            statusMessage = "检测到带转义符的 JSON 文本，已自动去转义并解析"
            metaMessage = "\(meta) | 输入内容含 \\\" 转义"
        } else if unwrapped > 0 {
            statusMessage = "检测到 JSON 字符串，已自动解包 \(unwrapped) 层"
            metaMessage = "\(meta) | 输入内容是被字符串包裹的 JSON"
        } else {
            statusMessage = "JSON 有效，已完成解析"
            metaMessage = meta
        }

        if let formatter {
            inputText = format(jsonObject: unwrappedValue, options: formatter)
        }
        if savesHistory {
            saveHistory(
                content: inputText.trimmingCharacters(in: .whitespacesAndNewlines),
                summary: meta
            )
        }
    }

    private func format(
        jsonObject: Any,
        options: JSONSerialization.WritingOptions
    ) -> String {
        var writingOptions = options
        writingOptions.insert(.withoutEscapingSlashes)
        guard JSONSerialization.isValidJSONObject(jsonObject),
              let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: writingOptions),
              let string = String(data: data, encoding: .utf8) else {
            return inputText
        }
        return string
    }

    private func saveHistory(content: String, summary: String) {
        guard !content.isEmpty else { return }
        do {
            try JsonParserHistoryRepository.save(
                JsonParserHistoryRecord(content: content, summary: summary)
            )
            history = try JsonParserHistoryRepository.fetchRecent()
        } catch {
            showHistoryError(error)
        }
    }

    private var nodes: [(path: String, depth: Int)] {
        guard let tree else { return [] }
        return tree.containerNodes()
    }

    private var collapsibleNodes: [(path: String, depth: Int)] {
        nodes.filter { $0.depth > 0 }
    }

    private func isExpanded(_ node: (path: String, depth: Int)) -> Bool {
        expansions[node.path] ?? (node.depth <= 1)
    }

    private func showError(message: String) {
        tree = nil
        statusMessage = "JSON 无效，请检查语法后重试"
        metaMessage = message
        isError = true
        deepestLevel = 0
        refreshSearch()
    }

    private func showHistoryError(_ error: Error) {
        statusMessage = "历史记录操作失败：\(error.localizedDescription)"
        isError = true
    }
}
