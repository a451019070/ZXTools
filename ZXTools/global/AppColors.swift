//
//  ColorExtension.swift
//  Tools
//
//  Created by ZX on 2026/9/21.
//

import SwiftUI

extension Color {
    static let primaryBlue = Color(red: 0.231, green: 0.510, blue: 0.965)   // #3b82f6
    static let secondaryGreen = Color(red: 0.063, green: 0.725, blue: 0.506) // #10b981
    static let accentIndigo = Color(red: 0.388, green: 0.400, blue: 0.945)   // #6366f1
    static let slate900 = Color(red: 0.118, green: 0.161, blue: 0.231)       // #1e293b
    static let slate800 = Color(red: 0.200, green: 0.255, blue: 0.333)
    static let slate700 = Color(red: 0.298, green: 0.333, blue: 0.412)
    static let slate600 = Color(red: 0.392, green: 0.439, blue: 0.518)
    static let slate500 = Color(red: 0.486, green: 0.533, blue: 0.612)
    static let slate400 = Color(red: 0.580, green: 0.624, blue: 0.690)
    static let slate300 = Color(red: 0.682, green: 0.722, blue: 0.792)
    static let slate200 = Color(red: 0.812, green: 0.843, blue: 0.882)
    static let slate100 = Color(red: 0.918, green: 0.937, blue: 0.957)
    static let slate50  = Color(red: 0.965, green: 0.973, blue: 0.984)
    static let canvasBackground = Color(red: 0.965, green: 0.973, blue: 0.984)
}

extension ShapeStyle where Self == Color {
    static var slate: Color { Color.slate600 }
    static var slate50: Color { Color.slate50 }
    static var slate100: Color { Color.slate100 }
    static var slate200: Color { Color.slate200 }
    static var slate300: Color { Color.slate300 }
    static var slate400: Color { Color.slate400 }
    static var slate500: Color { Color.slate500 }
    static var slate600: Color { Color.slate600 }
    static var slate700: Color { Color.slate700 }
    static var slate800: Color { Color.slate800 }
    static var slate900: Color { Color.slate900 }
}
