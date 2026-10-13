//
//  TinyPNGClient.swift
//  ZXTools
//
//  Created by ZX on 2026/10/13.
//

import Foundation

// MARK: - 请求选项

nonisolated struct TinyPNGOptions: Sendable {
    nonisolated struct Resize: Sendable {
        /// scale / fit / cover / thumb
        var method: String
        var width: Int?
        var height: Int?
    }

    /// 目标 MIME 类型，空数组表示保持原格式
    var convertTypes: [String] = []
    var resize: Resize?
    /// copyright / creation / location
    var preserve: [String] = []

    /// 是否需要在压缩后再发起一次带参数的请求（转换 / 缩放 / 保留元数据）
    var hasPostProcessing: Bool {
        !convertTypes.isEmpty || resize != nil || !preserve.isEmpty
    }

    func requestBody() throws -> Data {
        var body: [String: Any] = [:]

        if let resize {
            var dict: [String: Any] = ["method": resize.method]
            if let width = resize.width { dict["width"] = width }
            if let height = resize.height { dict["height"] = height }
            body["resize"] = dict
        }

        if !convertTypes.isEmpty {
            body["convert"] = ["type": convertTypes]
            // 透明图转为 JPEG 时需要指定底色
            if convertTypes.contains("image/jpeg") {
                body["transform"] = ["background": "white"]
            }
        }

        if !preserve.isEmpty {
            body["preserve"] = preserve
        }

        return try JSONSerialization.data(withJSONObject: body)
    }
}

// MARK: - 结果

nonisolated struct TinyPNGResult: Sendable {
    let data: Data
    let inputSize: Int
    let mimeType: String
    let compressionCount: Int?

    var outputSize: Int { data.count }

    var fileExtension: String {
        switch mimeType {
        case "image/png": return "png"
        case "image/jpeg": return "jpg"
        case "image/webp": return "webp"
        case "image/avif": return "avif"
        default: return "png"
        }
    }
}

// MARK: - 错误

nonisolated enum TinyPNGError: LocalizedError {
    case missingKey
    case unauthorized
    case limitReached(String?)
    case unsupportedFormat(String?)
    case badRequest(String?)
    case server(Int, String?)
    case network(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "请先填写 TinyPNG API Key"
        case .unauthorized:
            return "API Key 无效或已被停用"
        case .limitReached(let message):
            return "已达到本月压缩额度上限" + Self.suffix(message)
        case .unsupportedFormat(let message):
            return "不支持的图片格式" + Self.suffix(message)
        case .badRequest(let message):
            return "请求被拒绝" + Self.suffix(message)
        case .server(let status, let message):
            return "服务端错误（\(status)）" + Self.suffix(message)
        case .network(let error):
            return "网络请求失败：\(error.localizedDescription)"
        case .invalidResponse:
            return "服务端返回了无法识别的数据"
        }
    }

    private static func suffix(_ message: String?) -> String {
        guard let message, !message.isEmpty else { return "" }
        return "：\(message)"
    }
}

// MARK: - 客户端

nonisolated struct TinyPNGClient: Sendable {
    private static let shrinkURL = URL(string: "https://api.tinify.com/shrink")!

    nonisolated private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration)
    }()

    let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: 校验 Key

    /// 向 /shrink 发送空请求：Key 有效时返回 400（缺少图片），无效时返回 401。
    /// 返回本月已压缩次数（若服务端提供）。
    func validate() async throws -> Int? {
        guard !apiKey.isEmpty else { throw TinyPNGError.missingKey }

        var request = makeRequest(url: Self.shrinkURL)
        request.httpBody = Data()
        let (data, response) = try await send(request)

        switch response.statusCode {
        case 400, 201:
            return compressionCount(from: response)
        default:
            throw apiError(status: response.statusCode, data: data)
        }
    }

    // MARK: 压缩

    func compress(_ input: Data, options: TinyPNGOptions) async throws -> TinyPNGResult {
        guard !apiKey.isEmpty else { throw TinyPNGError.missingKey }

        // 1. 上传原图
        let shrinkRequest = makeRequest(url: Self.shrinkURL)
        let (shrinkData, shrinkResponse) = try await send(shrinkRequest, body: input)
        guard shrinkResponse.statusCode == 201 else {
            throw apiError(status: shrinkResponse.statusCode, data: shrinkData)
        }

        let info = try? JSONDecoder().decode(ShrinkResponse.self, from: shrinkData)
        let location = shrinkResponse.value(forHTTPHeaderField: "Location")
        guard let outputURL = (info?.output.url ?? location).flatMap(URL.init(string:)) else {
            throw TinyPNGError.invalidResponse
        }
        let count = compressionCount(from: shrinkResponse)

        // 2. 下载结果；需要转换 / 缩放 / 保留元数据时改用 POST 携带参数
        var downloadRequest = makeRequest(url: outputURL)
        if options.hasPostProcessing {
            downloadRequest.httpMethod = "POST"
            downloadRequest.httpBody = try options.requestBody()
            downloadRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else {
            downloadRequest.httpMethod = "GET"
        }

        let (imageData, imageResponse) = try await send(downloadRequest)
        guard imageResponse.statusCode == 200 else {
            throw apiError(status: imageResponse.statusCode, data: imageData)
        }

        let mime = imageResponse.value(forHTTPHeaderField: "Content-Type")?
            .split(separator: ";").first
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            ?? info?.output.type
            ?? "image/png"

        return TinyPNGResult(
            data: imageData,
            inputSize: info?.input.size ?? input.count,
            mimeType: mime,
            compressionCount: count
        )
    }

    // MARK: 内部实现

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let credential = Data("api:\(apiKey)".utf8).base64EncodedString()
        request.setValue("Basic \(credential)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send(_ request: URLRequest, body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response): (Data, URLResponse)
            if let body {
                (data, response) = try await Self.session.upload(for: request, from: body)
            } else {
                (data, response) = try await Self.session.data(for: request)
            }
            guard let http = response as? HTTPURLResponse else {
                throw TinyPNGError.invalidResponse
            }
            return (data, http)
        } catch let error as TinyPNGError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TinyPNGError.network(error)
        }
    }

    private func compressionCount(from response: HTTPURLResponse) -> Int? {
        response.value(forHTTPHeaderField: "Compression-Count").flatMap { Int($0) }
    }

    private func apiError(status: Int, data: Data) -> TinyPNGError {
        let message = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.message
        switch status {
        case 401: return .unauthorized
        case 429: return .limitReached(message)
        case 415: return .unsupportedFormat(message)
        case 400: return .badRequest(message)
        default: return .server(status, message)
        }
    }
}

// MARK: - 响应模型

private nonisolated struct ShrinkResponse: Decodable {
    struct Input: Decodable {
        let size: Int
    }

    struct Output: Decodable {
        let size: Int?
        let type: String?
        let url: String?
    }

    let input: Input
    let output: Output
}

private nonisolated struct APIErrorBody: Decodable {
    let error: String?
    let message: String?
}
