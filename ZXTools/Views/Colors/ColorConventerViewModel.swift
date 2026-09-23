//
//  ColorConventerViewModel.swift
//  Tools
//
//  Created by ZX on 2026/9/22.
//

import Combine
import SwiftUI

@MainActor
final class ColorConventerViewModel: ObservableObject {
    @Published var hexInput = ""
    @Published var rgbOutput = ""
    @Published private(set) var previewColor: Color = .white
    @Published private(set) var errorMessage: String?
    @Published private(set) var history: [ColorHistoryRecord] = []

    func convertHex() {
        let trimmed = hexInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请输入 16 进制颜色值"
            return
        }
        guard let color = ColorValue(hexString: trimmed) else {
            errorMessage = "请输入有效的 16 进制颜色值（如 #3b82f6）"
            return
        }

        apply(color)
        saveHistory(color)
    }

    func convertRGB() {
        let trimmed = rgbOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请输入 RGB 颜色值"
            return
        }
        guard let color = ColorValue(rgbString: trimmed) else {
            errorMessage = "请输入有效的 RGB 颜色值（如 rgb(59, 130, 246)）"
            return
        }

        apply(color)
        saveHistory(color)
    }

    func reuse(_ item: ColorHistoryRecord) {
        hexInput = item.hex.uppercased()
        rgbOutput = item.rgb
        previewColor = makeColor(red: item.red, green: item.green, blue: item.blue)
        errorMessage = nil
    }

    func loadHistory() {
        do {
            history = try ColorHistoryRepository.fetchRecent()
        } catch {
            history = []
            errorMessage = "读取历史记录失败：\(error.localizedDescription)"
        }
    }

    func delete(at offsets: IndexSet) {
        let items = offsets.compactMap { index in
            history.indices.contains(index) ? history[index] : nil
        }
        items.forEach(delete)
    }

    func delete(_ item: ColorHistoryRecord) {
        do {
            try ColorHistoryRepository.delete(id: item.id)
            history.removeAll { $0.id == item.id }
        } catch {
            errorMessage = "删除历史记录失败：\(error.localizedDescription)"
        }
    }

    func clearHistory() {
        do {
            try ColorHistoryRepository.deleteAll()
            history = []
        } catch {
            errorMessage = "清空历史记录失败：\(error.localizedDescription)"
        }
    }

    private func apply(_ color: ColorValue) {
        hexInput = color.hexString
        rgbOutput = color.rgbString
        previewColor = makeColor(red: color.red, green: color.green, blue: color.blue)
        errorMessage = nil
    }

    private func saveHistory(_ color: ColorValue) {
        let record = ColorHistoryRecord(
            hex: color.hexString.lowercased(),
            rgb: color.rgbString,
            red: color.red,
            green: color.green,
            blue: color.blue
        )

        do {
            try ColorHistoryRepository.save(record)
            loadHistory()
        } catch {
            errorMessage = "保存历史记录失败：\(error.localizedDescription)"
        }
    }

    private func makeColor(red: Int, green: Int, blue: Int) -> Color {
        Color(
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0
        )
    }
}
