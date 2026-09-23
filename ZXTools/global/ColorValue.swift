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

    init?(hexString rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        guard value.count == 6,
              let hexadecimal = UInt32(value, radix: 16) else {
            return nil
        }

        red = Int((hexadecimal >> 16) & 0xFF)
        green = Int((hexadecimal >> 8) & 0xFF)
        blue = Int(hexadecimal & 0xFF)
    }

    init?(rgbString rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("rgb(") && value.hasSuffix(")") {
            value = String(value.dropFirst(4).dropLast())
        }

        let components = value.split(separator: ",", omittingEmptySubsequences: false)
        guard components.count == 3 else {
            return nil
        }

        let numbers = components.compactMap {
            Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard numbers.count == 3,
              numbers.allSatisfy({ 0...255 ~= $0 }) else {
            return nil
        }

        red = numbers[0]
        green = numbers[1]
        blue = numbers[2]
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }

    var rgbString: String {
        "rgb(\(red), \(green), \(blue))"
    }
}
