//
//  FigmaClient.swift
//  ZXTools
//
//  Created by ZX on 2026/10/14.
//

import Foundation

// MARK: - 错误

nonisolated enum FigmaError: LocalizedError {
    case notFigmaLink
    case missingNodeID
    case invalidToken(String?)
    case forbidden(String?)
    case notFound
    case rateLimited
    case renderFailed
    case server(Int, String?)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notFigmaLink:
            return "不是有效的 Figma 链接"
        case .missingNodeID:
            return "链接缺少 node-id，请在 Figma 中右键图层选择 Copy link"
        case .invalidToken(let message):
            return "Figma Token 无效或已过期（401）" + Self.suffix(message)
        case .forbidden(let message):
            return "没有权限（403）：Token 缺少 File content 读取权限，或该账号无权访问此文件" + Self.suffix(message)
        case .notFound:
            return "找不到该文件或图层，请确认账号有访问权限"
        case .rateLimited:
            return "请求过于频繁，请稍后再试"
        case .renderFailed:
            return "Figma 无法导出该图层（可能是空图层或过大）"
        case .server(let status, let message):
            return "Figma 服务端错误（\(status)）" + Self.suffix(message)
        case .invalidResponse:
            return "Figma 返回了无法识别的数据"
        }
    }

    private static func suffix(_ message: String?) -> String {
        guard let message, !message.isEmpty else { return "" }
        return " [\(message)]"
    }
}

// MARK: - 链接解析

nonisolated struct FigmaLink: Sendable {
    let fileKey: String
    /// API 使用的节点 ID，形如 `1:2`
    let nodeID: String
    let displayName: String

    init(url: URL) throws {
        guard let host = url.host()?.lowercased(),
              host == "figma.com" || host.hasSuffix(".figma.com") else {
            throw FigmaError.notFigmaLink
        }

        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2,
              ["design", "file", "proto", "board"].contains(parts[0].lowercased()) else {
            throw FigmaError.notFigmaLink
        }

        // 分支链接：/design/:fileKey/branch/:branchKey/:name，应使用 branchKey
        var key = parts[1]
        var nameIndex = 2
        if parts.count >= 4, parts[2].lowercased() == "branch" {
            key = parts[3]
            nameIndex = 4
        }

        guard let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "node-id" })?
            .value,
              !raw.isEmpty else {
            throw FigmaError.missingNodeID
        }

        fileKey = key
        nodeID = raw.replacingOccurrences(of: "-", with: ":")

        let slug = parts.count > nameIndex ? parts[nameIndex] : "figma-\(key)"
        displayName = "\(slug)-\(raw.replacingOccurrences(of: ":", with: "-"))"
    }
}

// MARK: - 客户端

nonisolated struct FigmaClient: Sendable {
    private static let imagesURL = URL(string: "https://api.figma.com/v1/images")!

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration)
    }()

    let token: String
    var scale = 2

    init(token: String) {
        self.token = token
    }

    /// 调用 Figma 图片导出接口，返回临时的 PNG 下载地址
    func resolve(_ url: URL) async throws -> ResolvedImageLink {
        let link = try FigmaLink(url: url)

        var components = URLComponents(
            url: Self.imagesURL.appending(path: link.fileKey),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "ids", value: link.nodeID),
            URLQueryItem(name: "format", value: "png"),
            URLQueryItem(name: "scale", value: String(scale))
        ]
        guard let requestURL = components?.url else { throw FigmaError.invalidResponse }

        var request = URLRequest(url: requestURL)
        request.setValue(token, forHTTPHeaderField: "X-Figma-Token")

        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FigmaError.invalidResponse }

        guard http.statusCode == 200 else {
            let message = (try? JSONDecoder().decode(ImagesResponse.self, from: data))?.err
            switch http.statusCode {
            case 401: throw FigmaError.invalidToken(message)
            case 403: throw FigmaError.forbidden(message)
            case 404: throw FigmaError.notFound
            case 429: throw FigmaError.rateLimited
            default: throw FigmaError.server(http.statusCode, message)
            }
        }

        let body = try? JSONDecoder().decode(ImagesResponse.self, from: data)
        if let err = body?.err, !err.isEmpty {
            throw FigmaError.server(http.statusCode, err)
        }
        guard let images = body?.images else { throw FigmaError.invalidResponse }

        // 渲染失败时对应的值为 null
        guard let value = images[link.nodeID] ?? images.values.first,
              let address = value,
              let downloadURL = URL(string: address) else {
            throw FigmaError.renderFailed
        }
        return ResolvedImageLink(downloadURL: downloadURL, suggestedName: link.displayName)
    }
}

private nonisolated struct ImagesResponse: Decodable {
    let err: String?
    let images: [String: String?]?
}
