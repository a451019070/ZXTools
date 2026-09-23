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

            VStack(alignment: .leading, spacing: 20) {
                inputCard
                historyCard
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                Text("Hex 与 RGB 快速互转，自动保存历史记录")
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
            sectionLabel("16 进制颜色")
            HStack(spacing: 12) {
                TextField("#RRGGBB", text: $viewModel.hexInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .onSubmit { viewModel.convertHex() }
                Button(action: viewModel.convertHex) {
                    Label("转换", systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.primaryBlue)
                .keyboardShortcut(.return, modifiers: [])
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("RGB 颜色")
                    HStack(spacing: 8) {
                        TextField("rgb(59, 130, 246)", text: $viewModel.rgbOutput)
                            .textFieldStyle(.roundedBorder)
                            .frame(height: 36)
                            .font(.system(size: 13, design: .monospaced))
                            .onSubmit { viewModel.convertRGB() }
                        Button(action: viewModel.convertRGB) {
                            Image(systemName: "arrow.up.left")
                        }
                        .buttonStyle(.bordered)
                        .help("将 RGB 转换为 Hex")
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("预览")
                    RoundedRectangle(cornerRadius: 6)
                        .fill(viewModel.previewColor)
                        .frame(height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.slate200, lineWidth: 1)
                        )
                }
            }

            if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage)
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.red)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.slate200, lineWidth: 1)
        )
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
                        historyRow(item)
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    private func historyRow(_ item: ColorHistoryRecord) -> some View {
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - 行为

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.slate700)
    }
}

#Preview {
    ColorConverterView()
        .frame(width: 920, height: 660)
}
