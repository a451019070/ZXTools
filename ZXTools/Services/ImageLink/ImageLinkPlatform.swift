//
//  ImageLinkPlatform.swift
//  ZXTools
//
//  Created by ZX on 2026/10/14.
//

import Foundation

/// 平台解析后的结果：真正用于下载图片的地址，以及建议的文件名
nonisolated struct ResolvedImageLink: Sendable {
    let downloadURL: URL
    let suggestedName: String?
}

nonisolated enum ImageLinkError: LocalizedError {
    case missingToken(String)

    var errorDescription: String? {
        switch self {
        case .missingToken(let name): return "请先填写并保存 \(name)"
        }
    }
}

/// 图片链接的来源平台。新增平台（如蓝湖）时：
/// 1. 增加一个 case，并补全下面各项展示属性；
/// 2. 在 `resolve` 中接入对应的解析逻辑（把平台链接换成可下载的图片地址）。
nonisolated enum ImageLinkPlatform: String, CaseIterable, Identifiable, Sendable {
    case publicLink
    case figma

    var id: Self { self }

    var title: String {
        switch self {
        case .publicLink: return "公开链接"
        case .figma: return "Figma"
        }
    }

    var linkPlaceholder: String {
        switch self {
        case .publicLink:
            return "https://example.com/image.png，多个链接用换行或空格分隔"
        case .figma:
            return "https://www.figma.com/design/…?node-id=1-2，多个链接用换行或空格分隔"
        }
    }

    var hint: String {
        switch self {
        case .publicLink:
            return "会先把图片下载到本地，再按上方选项压缩。链接需可直接访问，需要登录或有防盗链的图片可能下载失败。"
        case .figma:
            return "链接必须带 node-id（在 Figma 中右键图层 → Copy link）。会通过 Figma API 导出该图层的 2x PNG，再按上方选项压缩。"
        }
    }

    /// 钥匙串账号；为 nil 表示该平台不需要 Key
    var keychainAccount: String? {
        switch self {
        case .publicLink: return nil
        case .figma: return "link-platform-figma-token"
        }
    }

    var requiresKey: Bool { keychainAccount != nil }

    var keyTitle: String {
        switch self {
        case .publicLink: return ""
        case .figma: return "Figma Token"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .publicLink: return ""
        case .figma: return "Figma → Settings → Security → Personal access tokens，勾选 File content 读取权限"
        }
    }

    /// 把用户粘贴的链接换成可下载的图片地址
    func resolve(_ url: URL, token: String?) async throws -> ResolvedImageLink {
        switch self {
        case .publicLink:
            return ResolvedImageLink(downloadURL: url, suggestedName: nil)

        case .figma:
            guard let token, !token.isEmpty else {
                throw ImageLinkError.missingToken(keyTitle)
            }
            return try await FigmaClient(token: token).resolve(url)
        }
    }
}
