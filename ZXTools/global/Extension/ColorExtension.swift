//
//  ColorExtension.swift
//  Tools
//
//  Created by ZX on 2026/9/22.
//

import Foundation
import SwiftUI


extension Color{

    /// 支持 `RGB`、`RGBA`、`RRGGBB`、`RRGGBBAA`，可带 `#` 前缀。
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard let value = UInt64(hex, radix: 16) else {
            self = .clear
            return
        }

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        switch hex.count {
        case 3:
            red = ((value >> 8) & 0xF) * 17
            green = ((value >> 4) & 0xF) * 17
            blue = (value & 0xF) * 17
            alpha = 255
        case 4:
            red = ((value >> 12) & 0xF) * 17
            green = ((value >> 8) & 0xF) * 17
            blue = ((value >> 4) & 0xF) * 17
            alpha = (value & 0xF) * 17
        case 6:
            red = (value >> 16) & 0xFF
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
            alpha = 255
        case 8:
            red = (value >> 24) & 0xFF
            green = (value >> 16) & 0xFF
            blue = (value >> 8) & 0xFF
            alpha = value & 0xFF
        default:
            self = .clear
            return
        }

        self.init(
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0,
            opacity: Double(alpha) / 255.0
        )
    }
    
    init(_ colorValue: ColorValue) {
        self.init(red: Double(colorValue.red)/255.0,
                     green: Double(colorValue.green)/255.0,
                     blue: Double(colorValue.blue)/255.0)
    }
    init(_ colorRecord: ColorHistoryRecord){
        self.init(red: Double(colorRecord.red)/255.0,
                     green: Double(colorRecord.green)/255.0,
                     blue: Double(colorRecord.blue)/255.0)
    }
}
