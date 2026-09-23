//
//  ZXToolsApp.swift
//  ZXTools
//
//  Created by ZX on 2026/9/23.
//

import SwiftUI

@main
struct ZXToolsApp: App {
    var body: some Scene {
        WindowGroup("网页辅助工具") {
            ContentView()
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1180, height: 820)

        WindowGroup("JSON 解析", id: "json-parser", for: UUID.self) { _ in
            JSONParserView()
                .frame(minWidth: 760, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1100, height: 720)     
    }
}
