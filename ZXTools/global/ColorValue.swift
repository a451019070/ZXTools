//
//  ColorValue.swift
//  Tools
//
//  Created by ZX on 2026/9/22.
//

import Foundation

// MARK: - 颜色转换
struct ColorValue: Equatable {
    let red: Int
    let green: Int
    let blue: Int

    /// 支持 `#RRGGBB`、`#RGB`，可带或不带 `#` 前缀。
    init?(hexString rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        let parsed: UInt64?
        switch value.count {
        case 3:
            // RGB 简写：每 4 位补齐，例如 "3bf" -> "33bbff"
            guard let v = UInt64(value, radix: 16) else { parsed = nil; break }
            let r = (v >> 8) & 0xF
            let g = (v >> 4) & 0xF
            let b = v & 0xF
            parsed = (r * 17) << 16 | (g * 17) << 8 | (b * 17)
        case 6:
            parsed = UInt64(value, radix: 16)
        default:
            parsed = nil
        }

        guard let hexadecimal = parsed else {
            return nil
        }

        red = Int((hexadecimal >> 16) & 0xFF)
        green = Int((hexadecimal >> 8) & 0xFF)
        blue = Int(hexadecimal & 0xFF)
    }

    /// 支持 `rgb(59, 130, 246)`、`rgb(59,130,246)`、`(59,130,246)`、`59,130,246`、
    /// `59 130 246` 等多种写法。
    init?(rgbString rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("rgb(") && value.hasSuffix(")") {
            value = String(value.dropFirst(4).dropLast())
        } else if value.hasPrefix("rgba(") && value.hasSuffix(")") {
            value = String(value.dropFirst(5).dropLast())
        } else if value.hasPrefix("(") && value.hasSuffix(")") {
            value = String(value.dropFirst().dropLast())
        }

        // 用正则提取 0~255 的整数，容忍逗号 / 空格 / 分号 / 斜杠 / 竖线 等分隔符
        let pattern = #"-?\d{1,3}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        let matches = regex.matches(in: value, range: range)

        // 只取每个匹配项的第一段数字，避免后面被误解析
        let numbers: [Int] = matches.compactMap { match in
            guard let r = Range(match.range, in: value) else { return nil }
            return Int(value[r])
        }

        // 跳过 RGBA 中的 alpha（第四位），仅取前三
        let head = numbers.prefix(3)
        guard head.count == 3,
              let r = head.first, let g = head.dropFirst().first, let b = head.dropFirst(2).first,
              (0...255).contains(r), (0...255).contains(g), (0...255).contains(b) else {
            return nil
        }

        red = r
        green = g
        blue = b
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }

    var rgbString: String {
        "rgb(\(red), \(green), \(blue))"
    }
}