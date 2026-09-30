//
//  JSONParserView.swift
//  Tools
//
//  Created by ZX on 2026/9/21.
//

import SwiftUI
import AppKit
import CoreFoundation



// MARK: - JSON 树（带行号 + 左侧折叠箭头）

extension JSONValue {
    /// 完全展开时占用的行数（折叠后行号会跳号，类似代码编辑器）
    var lineCount: Int {
        switch self {
        case .object(let pairs):
            return pairs.isEmpty ? 1 : 2 + pairs.reduce(0) { $0 + $1.value.lineCount }
        case .array(let items):
            return items.isEmpty ? 1 : 2 + items.reduce(0) { $0 + $1.lineCount }
        default:
            return 1
        }
    }
}

enum JSONTreeMetrics {
    static let indent: CGFloat = 16
    static let digitWidth: CGFloat = 7
    /// 行号 + 折叠箭头所在左栏的总宽度
    static func gutterWidth(totalLines: Int) -> CGFloat {
        CGFloat(String(max(totalLines, 1)).count) * digitWidth + 30
    }
}

struct JSONTreeRow: Identifiable {
    enum Kind {
        case open(isArray: Bool)
        case collapsed(isArray: Bool, summary: String)
        case close(isArray: Bool)
        case empty(isArray: Bool)
        case leaf
    }

    let id: String
    let line: Int
    let depth: Int
    let path: String
    let label: String?
    let kind: Kind
    let value: JSONValue
    let hasComma: Bool
}

enum JSONTreeFlattener {
    static func rows(tree: JSONValue, expansions: [String: Bool]) -> [JSONTreeRow] {
        var rows: [JSONTreeRow] = []
        var line = 1
        append(value: tree, label: nil, path: "root", depth: 0, hasComma: false,
               expansions: expansions, line: &line, rows: &rows)
        return rows
    }

    private static func append(value: JSONValue,
                               label: String?,
                               path: String,
                               depth: Int,
                               hasComma: Bool,
                               expansions: [String: Bool],
                               line: inout Int,
                               rows: inout [JSONTreeRow]) {
        let isArray: Bool
        let children: [(label: String?, value: JSONValue)]
        let summary: String

        switch value {
        case .object(let pairs):
            isArray = false
            children = pairs.map { (label: String?.some($0.key), value: $0.value) }
            summary = "\(pairs.count) 个键"
        case .array(let items):
            isArray = true
            children = items.map { (label: String?.none, value: $0) }
            summary = "\(items.count) 项"
        default:
            rows.append(JSONTreeRow(id: path, line: line, depth: depth, path: path, label: label,
                                    kind: .leaf, value: value, hasComma: hasComma))
            line += 1
            return
        }

        if children.isEmpty {
            rows.append(JSONTreeRow(id: path, line: line, depth: depth, path: path, label: label,
                                    kind: .empty(isArray: isArray), value: value, hasComma: hasComma))
            line += 1
            return
        }

        let isOpen = expansions[path] ?? (depth <= 1)
        guard isOpen else {
            rows.append(JSONTreeRow(id: path, line: line, depth: depth, path: path, label: label,
                                    kind: .collapsed(isArray: isArray, summary: summary),
                                    value: value, hasComma: hasComma))
            line += value.lineCount
            return
        }

        rows.append(JSONTreeRow(id: path, line: line, depth: depth, path: path, label: label,
                                kind: .open(isArray: isArray), value: value, hasComma: false))
        line += 1

        let prefix = isArray ? "a" : "o"
        for (idx, child) in children.enumerated() {
            append(value: child.value,
                   label: child.label,
                   path: "\(path).\(prefix)\(idx)",
                   depth: depth + 1,
                   hasComma: idx < children.count - 1,
                   expansions: expansions,
                   line: &line,
                   rows: &rows)
        }

        rows.append(JSONTreeRow(id: path + "#close", line: line, depth: depth, path: path, label: nil,
                                kind: .close(isArray: isArray), value: value, hasComma: hasComma))
        line += 1
    }
}

struct JSONTreeView: View {
    let tree: JSONValue
    @Binding var expansions: [String: Bool]

    var body: some View {
        let rows = JSONTreeFlattener.rows(tree: tree, expansions: expansions)
        let digits = String(tree.lineCount).count
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                JSONTreeRowView(row: row, digits: digits, expansions: $expansions)
            }
        }
    }
}

struct JSONTreeRowView: View {
    let row: JSONTreeRow
    let digits: Int
    @Binding var expansions: [String: Bool]

    private static let rowHeight: CGFloat = 20
    private static let keyColor = Color(red: 0.63, green: 0.38, blue: 0.03)

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            gutter
            content
                .textSelection(.enabled)
                .padding(.leading, 12 + CGFloat(row.depth) * JSONTreeMetrics.indent)
                .padding(.trailing, 12)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
        }
    }

    // MARK: 左栏：行号 + 折叠箭头

    private var gutter: some View {
        HStack(spacing: 4) {
            Text("\(row.line)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.slate400)
                .frame(width: CGFloat(digits) * JSONTreeMetrics.digitWidth, alignment: .trailing)
            chevron
                .frame(width: 12)
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .frame(height: Self.rowHeight)
    }

    @ViewBuilder
    private var chevron: some View {
        if let isOpen = foldState {
            Button {
                expansions[row.path] = !isOpen
            } label: {
                Image(systemName: isOpen ? "arrowtriangle.down.fill" : "arrowtriangle.right.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.slate400)
                    .frame(width: 12, height: Self.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: Self.rowHeight)
        }
    }

    private var foldState: Bool? {
        switch row.kind {
        case .open: return true
        case .collapsed: return false
        default: return nil
        }
    }

    // MARK: 内容

    @ViewBuilder
    private var content: some View {
        if case .leaf = row.kind, case .string(let s) = row.value, isImageURLString(s) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if row.label != nil {
                    Text(keyPrefix)
                }
                ImageLeaf(urlString: s, hasComma: row.hasComma)
            }
        } else {
            Text(lineText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keyPrefix: AttributedString {
        guard let label = row.label else { return AttributedString() }
        return styled("\"\(label)\"", color: Self.keyColor) + styled(": ", color: .slate500)
    }

    private var comma: AttributedString {
        row.hasComma ? styled(",", color: .slate500) : AttributedString()
    }

    private var lineText: AttributedString {
        var text = keyPrefix
        switch row.kind {
        case .open(let isArray):
            text += bracket(isArray ? "[" : "{")
        case .collapsed(let isArray, let summary):
            text += bracket(isArray ? "[" : "{")
            text += styled(" \(summary) ", color: .slate500, size: 11, mono: false)
            text += bracket(isArray ? "]" : "}")
            text += comma
        case .close(let isArray):
            text += bracket(isArray ? "]" : "}")
            text += comma
        case .empty(let isArray):
            text += bracket(isArray ? "[]" : "{}")
            text += comma
        case .leaf:
            text += leafValue
            text += comma
        }
        return text
    }

    private var leafValue: AttributedString {
        switch row.value {
        case .string(let s): return styled("\"\(s)\"", color: .slate700)
        case .number(let n): return styled(formatNumber(n), color: .green)
        case .bool(let b): return styled(b ? "true" : "false", color: .blue)
        case .null: return styled("null", color: .purple)
        default: return AttributedString()
        }
    }

    private func bracket(_ s: String) -> AttributedString {
        styled(s, color: .slate700, weight: .semibold)
    }

    private func styled(_ text: String,
                        color: Color,
                        size: CGFloat = 12,
                        weight: Font.Weight = .regular,
                        mono: Bool = true) -> AttributedString {
        var s = AttributedString(text)
        s.font = mono
            ? .system(size: size, weight: weight, design: .monospaced)
            : .system(size: size, weight: weight)
        s.foregroundColor = color
        return s
    }

    private func formatNumber(_ n: Double) -> String {
        if n.rounded() == n && abs(n) < 1e15 {
            return String(Int64(n))
        }
        return String(n)
    }
}

// MARK: - 主视图

struct JSONParserView: View {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var viewModel = JSONParserViewModel()
    @State private var isHistoryPresented: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroHeader
            toolbar
            Divider().background(Color.slate200)
            mainArea
        }
        .onAppear(perform: viewModel.load)
        .sheet(isPresented: $isHistoryPresented) {
            historySheet
        }
    }

    private var heroHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("J")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.slate900, in: RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 0) {
                    Text("JSON Handle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Tree Viewer")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.slate500)
                }
            }
            Spacer()
            Text("JSON 解析 · 支持折叠、自动解包、格式化")
                .font(.system(size: 11))
                .foregroundStyle(Color.slate500)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                toolButton(title: "新窗口", color: .accentIndigo) {
                    openWindow(id: "json-parser", value: UUID())
                }
                toolButton(title: "历史\(viewModel.history.isEmpty ? "" : " \(viewModel.history.count)")", color: .slate500) {
                    viewModel.loadHistory()
                    isHistoryPresented = true
                }
                toolButton(title: "示例", color: .skyBlue) { viewModel.loadExample() }
                toolButton(title: "清空", color: .slate500) { viewModel.clearAll() }
                toolButton(title: "复制", color: .slate500) { viewModel.copyResult() }
                toolButton(title: "压缩", color: .slate500) { viewModel.compressInput() }
                toolButton(title: viewModel.areAllContainersExpanded ? "全部折叠" : "全部展开",
                           color: .slate500) { viewModel.toggleAll() }
                toolButton(title: "解析", color: .indigo600, isProminent: true) { viewModel.parseInput() }
                toolButton(title: "格式化", color: .slate800, isProminent: true) { viewModel.formatInput() }
                Spacer()
            }
            if viewModel.deepestLevel > 0 {
                HStack(spacing: 6) {
                    Text("按级别：")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.slate500)
                    ForEach(1...viewModel.deepestLevel, id: \.self) { level in
                        Button { viewModel.toggleLevel(level) } label: {
                            Text(viewModel.levelButtonTitle(level))
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(buttonBg(level), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(buttonBorder(level), lineWidth: 1)
                                )
                                .foregroundStyle(buttonForeground(level))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.slate50)
    }

    private var historySheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("JSON 历史记录")
                        .font(.system(size: 16, weight: .semibold))
                    Text("解析成功后自动保存最近 50 条")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.slate500)
                }
                Spacer()
                if !viewModel.history.isEmpty {
                    Button("清空", role: .destructive) {
                        viewModel.clearHistory()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button("完成") {
                    isHistoryPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)

            Divider()

            if viewModel.history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.slate300)
                    Text("暂无 JSON 历史记录")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.slate400)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.history) { item in
                        Button {
                            reuseHistory(item)
                        } label: {
                            historyRow(item)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("使用此记录") {
                                reuseHistory(item)
                            }
                            Button("删除", role: .destructive) {
                                viewModel.deleteHistory(item)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteHistory(item)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: viewModel.deleteHistory)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 620, minHeight: 460)
    }

    private func historyRow(_ item: JsonParserHistoryRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.summary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.slate700)
                Spacer()
                Text(item.createdAt, format: .dateTime.year().month().day().hour().minute().second())
                    .font(.system(size: 10))
                    .foregroundStyle(Color.slate400)
            }
            Text(historyPreview(item.content))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.slate500)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(.vertical, 6)
    }

    private func historyPreview(_ content: String) -> String {
        let compact = content
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return compact.count > 240 ? String(compact.prefix(240)) + "…" : compact
    }

    private func toolButton(title: String,
                            color: Color,
                            isProminent: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isProminent ? color : Color.white, in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color, lineWidth: 1)
                )
                .foregroundStyle(isProminent ? Color.white : color)
        }
        .buttonStyle(.plain)
    }

    private var mainArea: some View {
        HSplitView {
            inputPane
                .frame(minWidth: 320, idealWidth: 380)
            outputPane
                .frame(minWidth: 360)
        }
        .frame(maxHeight: .infinity)
        .background(Color.white)
    }

    private var inputPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("输入 JSON")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.slate500)
                Spacer()
                Text("Cmd + Enter 触发解析")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.slate400)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.slate50)

            ZStack(alignment: .topLeading) {
                if viewModel.inputText.isEmpty {
                    Text(#"{"name":"value"}"#)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color.slate300)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.inputText)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .scrollContentBackground(.hidden)
                    .background(Color.white)
            }

            HStack {
                statusLabel
                Spacer()
                Text(viewModel.statusMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(viewModel.isError ? Color.red : Color.slate500)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.slate50)
        }
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(Color.slate200),
            alignment: .trailing
        )
    }

    private var outputPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("树形结果")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.slate500)
                Spacer()
                if !viewModel.metaMessage.isEmpty {
                    Text(viewModel.metaMessage)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.slate500)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.slate50)

            GeometryReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading) {
                        if let tree = viewModel.tree {
                            JSONTreeView(tree: tree, expansions: $viewModel.expansions)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "curlybraces.square")
                                    .font(.system(size: 30))
                                    .foregroundStyle(Color.slate300)
                                Text("解析结果将在这里以折叠树展示")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.slate400)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        }
                    }
                    .frame(width: proxy.size.width,
                           alignment: .topLeading)
                    .frame(minHeight: proxy.size.height,
                           alignment: .topLeading)
                }
            }
            .background(alignment: .leading) {
                ZStack(alignment: .leading) {
                    Color(red: 0.988, green: 0.992, blue: 0.998)
                    if let tree = viewModel.tree {
                        Color.slate50
                            .frame(width: JSONTreeMetrics.gutterWidth(totalLines: tree.lineCount))
                            .overlay(alignment: .trailing) {
                                Rectangle().fill(Color.slate200).frame(width: 1)
                            }
                    }
                }
            }
        }
    }

    private var statusLabel: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.isError ? Color.red : (viewModel.tree != nil ? Color.green : Color.slate300))
                .frame(width: 8, height: 8)
            Text(viewModel.isError ? "失败" : (viewModel.tree != nil ? "已解析" : "未解析"))
                .font(.system(size: 10))
                .foregroundStyle(viewModel.isError ? Color.red : (viewModel.tree != nil ? Color.green : Color.slate500))
        }
    }

    // MARK: - 视图行为

    private func reuseHistory(_ item: JsonParserHistoryRecord) {
        viewModel.reuseHistory(item)
        isHistoryPresented = false
    }

    private func buttonBg(_ level: Int) -> Color {
        viewModel.isLevelExpanded(level) ? Color.white : Color.emerald50
    }

    private func buttonBorder(_ level: Int) -> Color {
        viewModel.isLevelExpanded(level) ? Color.slate200 : Color.emerald200
    }

    private func buttonForeground(_ level: Int) -> Color {
        viewModel.isLevelExpanded(level) ? Color.slate500 : Color.emerald700
    }
}

// MARK: - 链接识别及图片预览

/// 仅将完整的 HTTP(S) 地址当作链接；不把普通文字、邮箱或相对路径自动转成链接。
func webURL(from string: String) -> URL? {
    guard string == string.trimmingCharacters(in: .whitespacesAndNewlines),
          !string.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }),
          let components = URLComponents(string: string),
          let scheme = components.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          let host = components.host, !host.isEmpty,
          let url = components.url else {
        return nil
    }
    return url
}

/// 图片链接必须首先是实际 HTTP(S) 地址，再以路径后缀识别图片格式。
func isImageURLString(_ s: String) -> Bool {
    let exts: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp",
        "bmp", "heic", "heif", "tiff", "avif"
    ]
    guard let url = webURL(from: s) else { return false }
    // 优先用 URL pathExtension；如果没有，取最后一段路径判断后缀
    let pathExt = url.pathExtension.lowercased()
    if !pathExt.isEmpty { return exts.contains(pathExt) }
    let lastSegment = url.lastPathComponent.lowercased()
    if let dot = lastSegment.lastIndex(of: ".") {
        let ext = String(lastSegment[lastSegment.index(after: dot)...])
        return exts.contains(ext)
    }
    return false
}

/// 图片 URL 点击后弹出预览，弹窗出现时才加载图片。
struct ImageLeaf: View {
    let urlString: String
    let hasComma: Bool
    @State private var isPreviewPresented = false

    private static let previewLink = URL(string: "zxtools-preview://open")!

    /// 链接文本 + 逗号 + 行内「预览」标记，合并在同一个 Text 中，折行时会自然跟随文字。
    private var content: AttributedString {
        var text = AttributedString("\"\(urlString)\"" + (hasComma ? "," : ""))
        text.font = .system(size: 12, design: .monospaced)
        text.foregroundColor = Color.slate700

        var marker = AttributedString("  预览")
        marker.font = .system(size: 10, weight: .medium)
        marker.foregroundColor = Color.slate400
        marker.link = Self.previewLink

        return text + marker
    }

    var body: some View {
        Text(content)
            .tint(Color.slate400)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                if url == Self.previewLink {
                    isPreviewPresented = true
                    return .handled
                }
                return .systemAction
            })
            .popover(isPresented: $isPreviewPresented, arrowEdge: .bottom) {
                imagePreview
                    .padding(12)
                    .background(.regularMaterial)
            }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("加载中…")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 260, height: 160)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 420, maxHeight: 420)
                case .failure:
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .foregroundStyle(.red)
                        Text("图片加载失败")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 260, height: 160)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            Text("无效链接")
                .font(.system(size: 11))
                .padding(8)
        }
    }
}

// MARK: - 额外颜色

extension Color {
    static let emerald50 = Color(red: 0.937, green: 0.984, blue: 0.953)
    static let emerald200 = Color(red: 0.737, green: 0.949, blue: 0.792)
    static let emerald700 = Color(red: 0.043, green: 0.604, blue: 0.404)
    static let skyBlue = Color(red: 0.180, green: 0.467, blue: 0.733)
    static let indigo600 = Color(red: 0.310, green: 0.275, blue: 0.898)
}

#Preview {
    JSONParserView()
        .frame(width: 1100, height: 720)
}
