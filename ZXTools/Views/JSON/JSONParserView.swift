//
//  JSONParserView.swift
//  Tools
//
//  Created by ZX on 2026/9/21.
//

import SwiftUI
import AppKit
import CoreFoundation



// MARK: - JSON 树节点视图

struct JSONNodeView: View {
    let label: String?
    let value: JSONValue
    let depth: Int
    let path: String
    let hasComma: Bool
    let arrayIndex: Int?
    @Binding var expansions: [String: Bool]

    var body: some View {
        switch value {
        case .object(let pairs):
            branchNode(
                type: "object",
                summary: pairs.isEmpty ? "空对象" : "\(pairs.count) 个键",
                children: AnyView(branchChildren(pairs: pairs))
            )
        case .array(let items):
            branchNode(
                type: "array",
                summary: items.isEmpty ? "空数组" : "\(items.count) 项",
                children: AnyView(arrayChildren(items: items))
            )
        case .string(let s):
            if isImageURLString(s) {
                leafRow(content: AnyView(ImageLeaf(urlString: s, hasComma: hasComma)),
                        showComma: false)
            } else {
                leafRow(content: AnyView(Text("\"\(s)\"")
                    .foregroundStyle(Color.slate700)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)))
            }
        case .number(let n):
            leafRow(content: AnyView(Text(formatNumber(n)).foregroundStyle(.green)))
        case .bool(let b):
            leafRow(content: AnyView(Text(b ? "true" : "false").foregroundStyle(.blue)))
        case .null:
            leafRow(content: AnyView(Text("null").foregroundStyle(.purple)))
        }
    }

    // 子节点: object
    private func branchChildren(pairs: [JSONMember]) -> some View {
        Group {
            if pairs.isEmpty {
                Text("空对象")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate400)
            } else {
                ForEach(0..<pairs.count, id: \.self) { idx in
                    let pair = pairs[idx]
                    JSONNodeView(label: pair.key,
                                 value: pair.value,
                                 depth: depth + 1,
                                 path: "\(path).o\(idx)",
                                 hasComma: idx < pairs.count - 1,
                                 arrayIndex: nil,
                                 expansions: $expansions)
                }
            }
        }
    }

    // 子节点: array
    private func arrayChildren(items: [JSONValue]) -> some View {
        Group {
            if items.isEmpty {
                Text("空数组")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate400)
            } else {
                ForEach(0..<items.count, id: \.self) { idx in
                    JSONNodeView(label: nil,
                                 value: items[idx],
                                 depth: depth + 1,
                                 path: "\(path).a\(idx)",
                                 hasComma: idx < items.count - 1,
                                 arrayIndex: idx,
                                 expansions: $expansions)
                }
            }
        }
    }

    // 容器节点
    private func branchNode(type: String, summary: String, children: AnyView) -> AnyView {
        let isOpen = expansions[path] ?? (depth <= 1)
        let openBracket = type == "array" ? "[" : "{"
        let closeBracket = type == "array" ? "]" : "}"

        return AnyView(
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 4) {
                    Button {
                        expansions[path] = !isOpen
                    } label: {
                        Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.slate500)
                            .frame(width: 16, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if let arrayIndex {
                        Text("\(arrayIndex):")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.slate500)
                    }
                    if let label {
                        Text("\"\(label)\"")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(jsonKeyColor)
                        Text(":")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.slate500)
                    }
                    Text(openBracket)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.slate700)
                    if !isOpen {
                        Text(summary)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.slate500)
                        Text(closeBracket)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.slate700)
                    }
                    if hasComma && !isOpen {
                        Text(",")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.slate500)
                    }
                }
                if isOpen {
                    VStack(alignment: .leading, spacing: 7) {
                        children
                    }
                    .padding(.leading, 18)
                    HStack(spacing: 0) {
                        Text(closeBracket)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.slate700)
                        if hasComma {
                            Text(",")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color.slate500)
                        }
                    }
                }
            }
        )
    }

    private func leafRow(content: AnyView, showComma: Bool = true) -> AnyView {
        AnyView(
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let arrayIndex {
                    Text("\(arrayIndex):")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.slate500)
                        .frame(minWidth: 16, alignment: .trailing)
                } else {
                    Spacer().frame(width: 16)
                }
                if let label {
                    Text("\"\(label)\"")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(jsonKeyColor)
                    Text(":")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.slate500)
                }
                content
                if hasComma && showComma {
                    Text(",")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.slate500)
                }
            }
        )
    }

    private var jsonKeyColor: Color {
        Color(red: 0.63, green: 0.38, blue: 0.03)
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
                            JSONNodeView(label: nil,
                                         value: tree,
                                         depth: 0,
                                         path: "root",
                                         hasComma: false,
                                         arrayIndex: nil,
                                         expansions: $viewModel.expansions)
                                .textSelection(.enabled)
                                .padding(12)
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
            .background(Color(red: 0.988, green: 0.992, blue: 0.998))
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
