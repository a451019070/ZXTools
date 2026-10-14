//
//  ColorConverterView.swift
//  Tools
//
//  Created by ZX on 2026/9/21.
//

import SwiftUI
import AppKit

// MARK: - 视图

struct ColorConverterView: View {
    @StateObject private var viewModel = ColorConventerViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroHeader
            Divider().background(Color.slate200)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inputCard
                    historyCard
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Color.canvasBackground)
        }
        .onAppear(perform: viewModel.loadHistory)
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintbrush")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.primaryBlue, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("颜色转换")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.slate900)
                Text("Hex 与 RGB 快速互转，支持 3 位简写与多种 RGB 写法")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate500)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white)
    } 

    // MARK: - 输入卡片

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                converterPanel(
                    title: "16 进制颜色",
                    placeholder: "#3B82F6 或 #3bf",
                    hint: nil,
                    text: $viewModel.hexInput,
                    buttonTitle: "Hex → RGB",
                    action: viewModel.convertHex
                )
                converterPanel(
                    title: "RGB 颜色",
                    placeholder: "rgb(59, 130, 246) / 59,130,246 / 59 130 246",
                    hint: "支持 rgb()、逗号、空格分隔，括号可选",
                    text: $viewModel.rgbInput,
                    buttonTitle: "RGB → Hex",
                    action: viewModel.convertRGB
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("预览")
                    previewBlock
                }
                Spacer()
                Button(action: viewModel.clearInputs) {
                    Label("清空输入", systemImage: "eraser")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let errorMessage = viewModel.errorMessage {
                errorBanner(errorMessage)
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.slate200, lineWidth: 1)
        )
    }

    private func converterPanel(
        title: String,
        placeholder: String,
        hint: String?,
        text: Binding<String>,
        buttonTitle: String,
//        buttonIcon: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                sectionLabel(title)
                if let hint {
                    Text(hint)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.slate400)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .onSubmit(action)
                .frame(height: 36)
            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.primaryBlue)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color.slate50, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.slate200, lineWidth: 1)
        )
    }

    private var previewBlock: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(viewModel.previewColor)
                .frame(width: 96, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.slate200, lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.previewColor == .white && viewModel.lastHexResult.isEmpty ? "等待转换" : "已就绪")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.slate500)
                if !viewModel.lastHexResult.isEmpty {
                    Text(viewModel.lastHexResult)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.slate700)
                }
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
        }
        .font(.system(size: 12))
        .foregroundStyle(Color.red)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 历史记录

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("历史转换记录")
                Spacer()
                if !viewModel.history.isEmpty {
                    Button(action: viewModel.clearHistory) {
                        Label("清空", systemImage: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if viewModel.history.isEmpty {
                emptyHistory
            } else {
                List {
                    ForEach(viewModel.history) { item in
                        ColorHistoryRow(item: item)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.white)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.reuse(item)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.delete(item)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button("使用本颜色") {
                                    viewModel.reuse(item)
                                }
                                Button("删除", role: .destructive) {
                                    viewModel.delete(item)
                                }
                            }
                    }
                    .onDelete(perform: viewModel.delete)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.slate200, lineWidth: 1)
                )
                .frame(minHeight: 120, maxHeight: 260)
            }
        }
        .padding(18)
        .background(Color.slate50, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.slate200, lineWidth: 1)
        )
    }

    private var emptyHistory: some View {
        VStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 24))
                .foregroundStyle(Color.slate300)
            Text("暂无历史记录")
                .font(.system(size: 13))
                .foregroundStyle(Color.slate400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 行为

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.slate700)
    }
}

// MARK: - 历史记录行

struct ColorHistoryRow: View {
    let item: ColorHistoryRecord

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(item))
                .frame(width: 32, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.slate200, lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.hex.uppercased())
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.slate800)
                Text(item.rgb)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.slate500)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    ColorConverterView()
        .frame(width: 920, height: 720)
}
