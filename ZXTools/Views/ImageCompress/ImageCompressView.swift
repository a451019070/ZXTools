//
//  ImageCompressView.swift
//  ZXTools
//
//  Created by ZX on 2026/10/13.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImageCompressView: View {
    @StateObject private var viewModel = ImageCompressViewModel()
    @State private var isDropTargeted = false
    @State private var isSettingsExpanded = false
    @State private var isHistoryExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroHeader
            Divider().background(Color.slate200)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    settingsCard
                    historyCard
                    dropCard
                    linkCard
                    messageBanners
                    if !viewModel.items.isEmpty {
                        listCard
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Color.canvasBackground)
        }
        .onAppear {
            viewModel.loadHistory()
            if !viewModel.hasKey {
                isSettingsExpanded = true
            }
        }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.badge.arrow.down")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.accentRose, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("图片压缩")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.slate900)
                Text("基于 TinyPNG API，支持 PNG / JPEG / WebP / AVIF 批量压缩、格式转换与缩放")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate500)
            }
            Spacer()
            if let count = viewModel.compressionCount {
                Text("本月已用 \(count) 次")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.slate600)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.slate100, in: Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white)
    }

    // MARK: - API Key

    private var settingsSummary: String {
        var parts = [viewModel.hasKey ? "Key 已配置" : "未配置 Key"]
        parts.append(viewModel.outputFormat.title)
        parts.append(viewModel.resizeMode.title)
        if viewModel.appendSuffix {
            parts.append("追加 -tiny 后缀")
        }
        return parts.joined(separator: " · ")
    }

    private var settingsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSettingsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.slate400)
                            .rotationEffect(.degrees(isSettingsExpanded ? 90 : 0))
                            .frame(width: 12)
                        sectionLabel("API Key 与压缩选项")
                        if !isSettingsExpanded {
                            Text(settingsSummary)
                                .font(.system(size: 11))
                                .foregroundStyle(viewModel.hasKey ? Color.slate500 : Color.red)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isSettingsExpanded {
                    Divider().background(Color.slate100)
                    apiKeyCard
                    Divider().background(Color.slate100)
                    optionsCard
                }
            }
        }
    }

    private var apiKeyCard: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("TinyPNG API Key")
                HStack(spacing: 10) {
                    SecureField("在 tinify.com/developers 获取，每月免费 500 次", text: $viewModel.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                        .onSubmit(viewModel.validateKey)

                    Button(action: viewModel.validateKey) {
                        if viewModel.isValidatingKey {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("验证并保存", systemImage: "checkmark.shield")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentRose)
                    .controlSize(.small)
                    .disabled(viewModel.isValidatingKey || !viewModel.hasKey)

                    Button(action: viewModel.saveKey) {
                        Text(viewModel.hasKey ? "仅保存" : "清除")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isValidatingKey)
                }

                if let message = viewModel.keyMessage {
                    Label(message, systemImage: viewModel.keyMessageIsError ? "exclamationmark.circle" : "checkmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(viewModel.keyMessageIsError ? Color.red : Color.secondaryGreen)
                }

                Text("Key 保存在系统钥匙串中。压缩时图片会上传到 TinyPNG 服务器处理，请勿用于敏感图片。")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.slate400)
            }
        }
    }

    // MARK: - 选项

    private var optionsCard: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel("输出格式")
                        Picker("", selection: $viewModel.outputFormat) {
                            ForEach(ImageOutputFormat.allCases) { format in
                                Text(format.title).tag(format)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                        if viewModel.outputFormat == .jpeg {
                            Text("转为 JPEG 时透明区域将填充白色")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.slate400)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel("缩放")
                        HStack(spacing: 8) {
                            Picker("", selection: $viewModel.resizeMode) {
                                ForEach(ImageResizeMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 220)

                            if viewModel.resizeMode != .none {
                                TextField("宽", text: $viewModel.resizeWidth)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 64)
                                Text("×").foregroundStyle(Color.slate400)
                                TextField("高", text: $viewModel.resizeHeight)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 64)
                                Text("px")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.slate400)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("保留元数据（默认全部移除）")
                    HStack(spacing: 18) {
                        Toggle("版权信息", isOn: $viewModel.preserveCopyright)
                        Toggle("创建时间", isOn: $viewModel.preserveCreation)
                        Toggle("地理位置（仅 JPEG）", isOn: $viewModel.preserveLocation)
                    }
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                }

                Toggle("保存时文件名追加 -tiny 后缀", isOn: $viewModel.appendSuffix)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
            }
        }
        .disabled(viewModel.isCompressing)
    }

    // MARK: - 拖拽区

    private var dropCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(isDropTargeted ? Color.accentRose : Color.slate400)
            Text("拖拽图片或文件夹到这里")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.slate700)
            Text("支持 PNG / JPEG / WebP / AVIF，单张建议不超过 TinyPNG 允许的上限")
                .font(.system(size: 11))
                .foregroundStyle(Color.slate400)
            Button(action: viewModel.presentOpenPanel) {
                Label("选择文件", systemImage: "folder")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.isCompressing)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            (isDropTargeted ? Color.accentRose.opacity(0.06) : Color.white),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDropTargeted ? Color.accentRose : Color.slate300,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !viewModel.isCompressing else { return false }
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let value = item as? URL {
                    url = value
                }
                if let url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            viewModel.addFiles(urls)
        }
        return true
    }

    // MARK: - 链接添加

    private var linkCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("通过图片链接添加")
                HStack(alignment: .top, spacing: 10) {
                    TextField("https://example.com/image.png，多个链接用换行或空格分隔", text: $viewModel.linkInput, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1...4)
                        .onSubmit(viewModel.addRemoteLinks)

                    Button(action: viewModel.addRemoteLinks) {
                        if viewModel.isDownloading {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("下载中…").font(.system(size: 12))
                            }
                        } else {
                            Label("下载并添加", systemImage: "arrow.down.circle")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(
                        viewModel.isDownloading
                            || viewModel.isCompressing
                            || viewModel.linkInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                Text("会先把图片下载到本地，再按上方选项压缩。链接需可直接访问，需要登录或有防盗链的图片可能下载失败。")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.slate400)
            }
        }
    }

    @ViewBuilder
    private var messageBanners: some View {
        if let message = viewModel.errorMessage {
            banner(message, systemImage: "exclamationmark.triangle.fill", color: .red)
        }
        if let message = viewModel.infoMessage {
            banner(message, systemImage: "checkmark.circle.fill", color: .secondaryGreen)
        }
    }

    // MARK: - 列表

    private var listCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionLabel("图片列表（\(viewModel.items.count)）")
                    Spacer()
                    summaryView
                }

                VStack(spacing: 0) {
                    ForEach(viewModel.items) { item in
                        row(for: item)
                        if item.id != viewModel.items.last?.id {
                            Divider().background(Color.slate100)
                        }
                    }
                }

                actionBar
            }
        }
    }

    @ViewBuilder
    private var summaryView: some View {
        if !viewModel.doneItems.isEmpty, let ratio = viewModel.totalSavedRatio {
            HStack(spacing: 6) {
                Text("\(ImageCompressViewModel.formatSize(viewModel.totalOriginalSize)) → \(ImageCompressViewModel.formatSize(viewModel.totalCompressedSize))")
                    .foregroundStyle(Color.slate600)
                Text(ImageCompressViewModel.formatPercent(ratio))
                    .fontWeight(.semibold)
                    .foregroundStyle(ratio >= 0 ? Color.secondaryGreen : Color.accentAmber)
            }
            .font(.system(size: 12))
        }
    }

    private func row(for item: ImageCompressItem) -> some View {
        HStack(spacing: 12) {
            thumbnail(for: item)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.slate900)
                    .lineLimit(1)
                    .truncationMode(.middle)
                statusText(for: item)
            }

            Spacer(minLength: 12)

            trailing(for: item)
        }
        .padding(.vertical, 8)
    }

    private func thumbnail(for item: ImageCompressItem) -> some View {
        Group {
            if let image = item.thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(Color.slate400)
            }
        }
        .frame(width: 40, height: 40)
        .background(Color.slate50)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.slate200, lineWidth: 1))
    }

    @ViewBuilder
    private func statusText(for item: ImageCompressItem) -> some View {
        switch item.status {
        case .waiting:
            Text("\(ImageCompressViewModel.formatSize(item.originalSize)) · 等待压缩")
                .font(.system(size: 11))
                .foregroundStyle(Color.slate500)
        case .compressing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("压缩中…")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.slate500)
            }
        case .done:
            if let result = item.result {
                Text("\(ImageCompressViewModel.formatSize(item.originalSize)) → \(ImageCompressViewModel.formatSize(result.outputSize)) · \(result.fileExtension.uppercased())")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.slate500)
            }
        case .failed(let message):
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(Color.red)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private func trailing(for item: ImageCompressItem) -> some View {
        HStack(spacing: 10) {
            if item.status == .done, let ratio = item.savedRatio {
                Text(ImageCompressViewModel.formatPercent(ratio))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ratio >= 0 ? Color.secondaryGreen : Color.accentAmber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (ratio >= 0 ? Color.secondaryGreen : Color.accentAmber).opacity(0.12),
                        in: Capsule()
                    )
                Button {
                    viewModel.save(item)
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .help("保存这一张")
            }

            Button {
                viewModel.remove(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.slate300)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isCompressing)
            .help("移除")
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if viewModel.isCompressing {
                Button(action: viewModel.cancelCompression) {
                    Label("停止", systemImage: "stop.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            } else {
                Button(action: viewModel.startCompression) {
                    Label(
                        viewModel.pendingCount > 0 ? "开始压缩（\(viewModel.pendingCount)）" : "开始压缩",
                        systemImage: "bolt.fill"
                    )
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentRose)
                .controlSize(.regular)
                .disabled(viewModel.pendingCount == 0)
            }

            Button(action: viewModel.saveAll) {
                Label("保存全部", systemImage: "square.and.arrow.down.on.square")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(viewModel.doneItems.isEmpty || viewModel.isCompressing)

            if !viewModel.doneItems.isEmpty && !viewModel.isCompressing {
                Button(action: viewModel.resetAll) {
                    Label("按当前选项重新压缩", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
            }

            Spacer()

            Button(role: .destructive, action: viewModel.clearAll) {
                Label("清空列表", systemImage: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - 压缩记录

    private var historyCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHistoryExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.slate400)
                                .rotationEffect(.degrees(isHistoryExpanded ? 90 : 0))
                                .frame(width: 12)
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.slate500)
                            sectionLabel("压缩记录（\(viewModel.history.count) / \(ImageCompressHistoryRepository.maximumCount)）")
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if isHistoryExpanded && !viewModel.history.isEmpty {
                        Button(action: viewModel.clearHistory) {
                            Label("清空记录", systemImage: "trash")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if !isHistoryExpanded {
                    EmptyView()
                } else if viewModel.history.isEmpty {
                    Text("暂无记录。压缩成功的图片会自动记录在这里，最多保留 \(ImageCompressHistoryRepository.maximumCount) 条，超出后最早的记录会被替换。")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.slate400)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.history) { record in
                                historyRow(record)
                                if record.id != viewModel.history.last?.id {
                                    Divider().background(Color.slate100)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(maxHeight: 320)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.slate200, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func historyRow(_ record: ImageCompressHistoryRecord) -> some View {
        HStack(spacing: 12) {
            historyThumbnail(record)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.slate900)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Image(systemName: record.isRemote ? "link" : "folder")
                        .font(.system(size: 10))
                    Text(record.source)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.system(size: 11))
                .foregroundStyle(Color.slate500)
                .help(record.source)

                Text("\(ImageCompressViewModel.formatSize(record.originalSize)) → \(ImageCompressViewModel.formatSize(record.compressedSize)) · \(record.outputFormat.uppercased()) · \(record.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.slate400)
            }

            Spacer(minLength: 12)

            if let ratio = record.savedRatio {
                Text(ImageCompressViewModel.formatPercent(ratio))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ratio >= 0 ? Color.secondaryGreen : Color.accentAmber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (ratio >= 0 ? Color.secondaryGreen : Color.accentAmber).opacity(0.12),
                        in: Capsule()
                    )
            }

            Button {
                viewModel.openSource(of: record)
            } label: {
                Image(systemName: record.isRemote ? "doc.on.doc" : "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help(record.isRemote ? "复制图片链接" : "在 Finder 中显示原文件")

            Button {
                viewModel.deleteHistory(record)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.slate300)
            }
            .buttonStyle(.borderless)
            .help("删除这条记录")
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.openSource(of: record)
        }
        .contextMenu {
            Button(record.isRemote ? "复制图片链接" : "复制文件路径") {
                viewModel.copySource(of: record)
            }
            if !record.isRemote {
                Button("在 Finder 中显示原文件") {
                    viewModel.revealInFinder(record)
                }
            }
            Divider()
            Button("删除这条记录", role: .destructive) {
                viewModel.deleteHistory(record)
            }
        }
    }

    private func historyThumbnail(_ record: ImageCompressHistoryRecord) -> some View {
        Group {
            if let data = record.thumbnail, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(Color.slate400)
            }
        }
        .frame(width: 40, height: 40)
        .background(Color.slate50)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.slate200, lineWidth: 1))
    }

    // MARK: - 通用组件

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.slate200, lineWidth: 1)
            )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.slate600)
    }

    private func banner(_ message: String, systemImage: String, color: Color) -> some View {
        Label(message, systemImage: systemImage)
            .font(.system(size: 12))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ImageCompressView()
        .frame(width: 900, height: 700)
}
