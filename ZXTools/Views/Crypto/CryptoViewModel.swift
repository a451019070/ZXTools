//
//  CryptoViewModel.swift
//  ZXTools
//
//  编码 / 加密 / 哈希 统一处理
//

import SwiftUI
import Combine
import AppKit
import CryptoKit
import CommonCrypto
import Security

// MARK: - 枚举

enum CryptoCategory: String, CaseIterable, Identifiable {
    case encoding = "编码"
    case cipher = "加密"
    case hash = "哈希"

    var id: Self { self }

    var algorithms: [CryptoAlgorithm] {
        CryptoAlgorithm.allCases.filter { $0.category == self }
    }

    var forwardTitle: String {
        switch self {
        case .encoding: return "编码"
        case .cipher: return "加密"
        case .hash: return "计算"
        }
    }

    var backwardTitle: String? {
        switch self {
        case .encoding: return "解码"
        case .cipher: return "解密"
        case .hash: return nil
        }
    }
}

enum CryptoAlgorithm: String, CaseIterable, Identifiable {
    case base64 = "Base64"
    case url = "URL"
    case hex = "Hex"
    case aesGCM = "AES-GCM（密码）"
    case aesCBC = "AES-CBC"
    case aesECB = "AES-ECB"
    case rsaOAEP = "RSA-OAEP（SHA256）"
    case rsaPKCS1 = "RSA-PKCS1 v1.5"
    case md5 = "MD5"
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
    case hmacSHA256 = "HMAC-SHA256"

    var id: Self { self }

    var category: CryptoCategory {
        switch self {
        case .base64, .url, .hex: return .encoding
        case .aesGCM, .aesCBC, .aesECB, .rsaOAEP, .rsaPKCS1: return .cipher
        case .md5, .sha1, .sha256, .sha512, .hmacSHA256: return .hash
        }
    }

    var usesPassword: Bool { self == .aesGCM }
    var usesKey: Bool { self == .aesCBC || self == .aesECB || self == .hmacSHA256 }
    var usesIV: Bool { self == .aesCBC }
    var usesAESOptions: Bool { self == .aesCBC || self == .aesECB }
    var usesRSA: Bool { self == .rsaOAEP || self == .rsaPKCS1 }
    var usesCipherFormat: Bool { usesAESOptions || usesRSA }

    var keyTitle: String { self == .hmacSHA256 ? "密钥" : "Key" }

    var description: String {
        switch self {
        case .base64: return "文本与 Base64 互转，解码兼容 URL-safe 写法"
        case .url: return "URL 百分号编码 / 解码"
        case .hex: return "文本与十六进制互转"
        case .aesGCM: return "AES-256-GCM，由密码经 PBKDF2 派生密钥；输出 Base64（盐 + Nonce + 密文 + Tag）"
        case .aesCBC: return "AES-CBC + PKCS7，Key / IV 按 UTF-8 文本读取"
        case .aesECB: return "AES-ECB + PKCS7，Key 按 UTF-8 文本读取（ECB 不安全，仅用于兼容）"
        case .rsaOAEP: return "RSA 公钥加密 / 私钥解密，OAEP + SHA256 填充（推荐）；明文长度受密钥长度限制"
        case .rsaPKCS1: return "RSA 公钥加密 / 私钥解密，PKCS#1 v1.5 填充，用于兼容旧系统；明文长度受密钥长度限制"
        case .md5: return "MD5 摘要（不可逆，不安全，仅用于校验）"
        case .sha1: return "SHA-1 摘要（不可逆）"
        case .sha256: return "SHA-256 摘要（不可逆）"
        case .sha512: return "SHA-512 摘要（不可逆）"
        case .hmacSHA256: return "HMAC-SHA256 消息认证码（不可逆）"
        }
    }
}

enum CryptoDirection {
    case forward
    case backward
}

enum CryptoOutputFormat: String, CaseIterable, Identifiable {
    case base64 = "Base64"
    case hex = "Hex"

    var id: Self { self }
}

enum AESKeySize: Int, CaseIterable, Identifiable {
    case bits128 = 128
    case bits192 = 192
    case bits256 = 256

    var id: Self { self }
    var byteCount: Int { rawValue / 8 }
    var title: String { "\(rawValue) 位" }
}

enum RSAKeySize: Int, CaseIterable, Identifiable {
    case bits2048 = 2048
    case bits3072 = 3072
    case bits4096 = 4096

    var id: Self { self }
    var title: String { "\(rawValue) 位" }
}

enum CryptoError: LocalizedError {
    case emptyPublicKey
    case emptyPrivateKey
    case invalidRSAKey
    case rsaInputTooLong(max: Int)
    case keyGenerationFailed
    case emptyInput
    case emptyPassword
    case emptyKey
    case invalidKeyLength(expected: Int, actual: Int)
    case invalidIVLength(actual: Int)
    case invalidBase64
    case invalidHex
    case invalidURL
    case invalidCiphertext
    case keyDerivationFailed
    case randomFailed
    case encryptionFailed
    case decryptionFailed
    case invalidUTF8

    var errorDescription: String? {
        switch self {
        case .emptyPublicKey: return "请输入公钥（加密需要公钥）"
        case .emptyPrivateKey: return "请输入私钥（解密需要私钥）"
        case .invalidRSAKey: return "密钥格式不正确，请使用 PEM 格式的 RSA 密钥（X.509 / PKCS#8 / PKCS#1）"
        case let .rsaInputTooLong(max): return "明文过长：当前密钥与填充方式最多加密 \(max) 字节，请缩短内容或换用更长的密钥"
        case .keyGenerationFailed: return "生成密钥对失败"
        case .emptyInput: return "请输入需要处理的内容"
        case .emptyPassword: return "请输入密码"
        case .emptyKey: return "请输入密钥"
        case let .invalidKeyLength(expected, actual):
            return "Key 长度需为 \(expected) 字节，当前为 \(actual) 字节"
        case let .invalidIVLength(actual):
            return "IV 长度需为 16 字节，当前为 \(actual) 字节"
        case .invalidBase64: return "不是有效的 Base64 内容"
        case .invalidHex: return "不是有效的十六进制内容"
        case .invalidURL: return "不是有效的 URL 编码内容"
        case .invalidCiphertext: return "密文格式不正确或长度不足"
        case .keyDerivationFailed: return "密钥派生失败"
        case .randomFailed: return "生成随机数失败"
        case .encryptionFailed: return "加密失败"
        case .decryptionFailed: return "解密失败：密码 / Key / IV 错误，或密文已损坏"
        case .invalidUTF8: return "结果不是有效的 UTF-8 文本"
        }
    }
}

// MARK: - ViewModel

final class CryptoViewModel: ObservableObject {
    @Published var category: CryptoCategory = .encoding {
        didSet {
            if algorithm.category != category, let first = category.algorithms.first {
                algorithm = first
            }
        }
    }

    @Published var algorithm: CryptoAlgorithm = .base64 {
        didSet {
            if oldValue != algorithm {
                output = ""
                errorMessage = nil
                copied = false
            }
        }
    }

    @Published var input: String = ""
    @Published var output: String = ""
    @Published var password: String = ""
    @Published var key: String = ""
    @Published var iv: String = ""
    @Published var keySize: AESKeySize = .bits128
    @Published var outputFormat: CryptoOutputFormat = .base64
    @Published var uppercaseHex: Bool = false
    @Published var rsaPublicKey: String = ""
    @Published var rsaPrivateKey: String = ""
    @Published var rsaKeySize: RSAKeySize = .bits2048
    @Published var isGeneratingKey: Bool = false

    @Published var errorMessage: String?
    @Published var copied: Bool = false

    private static let saltLength = 16
    private static let nonceLength = 12
    private static let tagLength = 16
    private static let pbkdf2Iterations: UInt32 = 100_000

    // MARK: 行为

    func run(_ direction: CryptoDirection) {
        errorMessage = nil
        copied = false
        do {
            guard !input.isEmpty else { throw CryptoError.emptyInput }
            output = try process(direction)
        } catch {
            output = ""
            errorMessage = error.localizedDescription
        }
    }

    func useOutputAsInput() {
        guard !output.isEmpty else { return }
        input = output
        output = ""
        errorMessage = nil
        copied = false
    }

    func clear() {
        input = ""
        output = ""
        errorMessage = nil
        copied = false
    }

    func generateRSAKeyPair() {
        guard !isGeneratingKey else { return }
        isGeneratingKey = true
        errorMessage = nil
        let bits = rsaKeySize.rawValue

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try RSAKit.generateKeyPair(bits: bits) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isGeneratingKey = false
                switch result {
                case .success(let pair):
                    self.rsaPublicKey = pair.publicPEM
                    self.rsaPrivateKey = pair.privatePEM
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func copyText(_ text: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func copyOutput() {
        guard !output.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        copied = true
    }

    // MARK: 调度

    private func process(_ direction: CryptoDirection) throws -> String {
        let forward = (direction == .forward)
        switch algorithm {
        case .base64:
            if forward {
                return Data(input.utf8).base64EncodedString()
            }
            return try string(from: try data(fromBase64: input))
        case .url:
            if forward {
                return urlEncode(input)
            }
            guard let decoded = input.removingPercentEncoding else { throw CryptoError.invalidURL }
            return decoded
        case .hex:
            if forward {
                return hexString(Data(input.utf8), uppercase: uppercaseHex)
            }
            return try string(from: try data(fromHex: input))
        case .aesGCM:
            if forward {
                return try gcmEncrypt(input)
            }
            return try gcmDecrypt(input)
        case .aesCBC, .aesECB:
            if forward {
                return try aesEncrypt(input)
            }
            return try aesDecrypt(input)
        case .rsaOAEP, .rsaPKCS1:
            let oaep = (algorithm == .rsaOAEP)
            if forward {
                let cipher = try RSAKit.encrypt(Data(input.utf8), publicPEM: rsaPublicKey, oaep: oaep)
                return formatCipher(cipher)
            }
            let cipher = try parseCipher(input)
            let plain = try RSAKit.decrypt(cipher, privatePEM: rsaPrivateKey, oaep: oaep)
            return try string(from: plain)
        case .md5:
            return hexString(Data(Insecure.MD5.hash(data: Data(input.utf8))), uppercase: uppercaseHex)
        case .sha1:
            return hexString(Data(Insecure.SHA1.hash(data: Data(input.utf8))), uppercase: uppercaseHex)
        case .sha256:
            return hexString(Data(SHA256.hash(data: Data(input.utf8))), uppercase: uppercaseHex)
        case .sha512:
            return hexString(Data(SHA512.hash(data: Data(input.utf8))), uppercase: uppercaseHex)
        case .hmacSHA256:
            guard !key.isEmpty else { throw CryptoError.emptyKey }
            let symmetricKey = SymmetricKey(data: Data(key.utf8))
            let mac = HMAC<SHA256>.authenticationCode(for: Data(input.utf8), using: symmetricKey)
            return hexString(Data(mac), uppercase: uppercaseHex)
        }
    }

    // MARK: 编码工具

    private func urlEncode(_ text: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    private func string(from data: Data) throws -> String {
        guard let text = String(data: data, encoding: .utf8) else { throw CryptoError.invalidUTF8 }
        return text
    }

    private func hexString(_ data: Data, uppercase: Bool) -> String {
        let format = uppercase ? "%02X" : "%02x"
        return data.map { String(format: format, $0) }.joined()
    }

    private func data(fromHex text: String) throws -> Data {
        var s = text.components(separatedBy: .whitespacesAndNewlines).joined()
        if s.lowercased().hasPrefix("0x") { s.removeFirst(2) }
        guard !s.isEmpty, s.count % 2 == 0 else { throw CryptoError.invalidHex }

        var bytes = [UInt8]()
        bytes.reserveCapacity(s.count / 2)
        var index = s.startIndex
        while index < s.endIndex {
            let next = s.index(index, offsetBy: 2)
            guard let byte = UInt8(s[index..<next], radix: 16) else { throw CryptoError.invalidHex }
            bytes.append(byte)
            index = next
        }
        return Data(bytes)
    }

    private func data(fromBase64 text: String) throws -> Data {
        var s = text.components(separatedBy: .whitespacesAndNewlines).joined()
        s = s.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder > 0 {
            s += String(repeating: "=", count: 4 - remainder)
        }
        guard !s.isEmpty, let data = Data(base64Encoded: s) else { throw CryptoError.invalidBase64 }
        return data
    }

    private func formatCipher(_ data: Data) -> String {
        switch outputFormat {
        case .base64: return data.base64EncodedString()
        case .hex: return hexString(data, uppercase: uppercaseHex)
        }
    }

    private func parseCipher(_ text: String) throws -> Data {
        switch outputFormat {
        case .base64: return try data(fromBase64: text)
        case .hex: return try data(fromHex: text)
        }
    }

    // MARK: AES-GCM（密码）

    private func gcmEncrypt(_ text: String) throws -> String {
        guard !password.isEmpty else { throw CryptoError.emptyPassword }

        let salt = try randomBytes(Self.saltLength)
        let symmetricKey = try deriveKey(password: password, salt: salt)
        let sealed = try AES.GCM.seal(Data(text.utf8), using: symmetricKey)
        guard let combined = sealed.combined else { throw CryptoError.encryptionFailed }

        var result = Data(salt)
        result.append(combined)
        return result.base64EncodedString()
    }

    private func gcmDecrypt(_ text: String) throws -> String {
        guard !password.isEmpty else { throw CryptoError.emptyPassword }

        let raw = try data(fromBase64: text)
        guard raw.count >= Self.saltLength + Self.nonceLength + Self.tagLength else {
            throw CryptoError.invalidCiphertext
        }

        let bytes = [UInt8](raw)
        let salt = Array(bytes[0..<Self.saltLength])
        let combined = Data(bytes[Self.saltLength...])
        let symmetricKey = try deriveKey(password: password, salt: salt)

        let plain: Data
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            plain = try AES.GCM.open(box, using: symmetricKey)
        } catch {
            throw CryptoError.decryptionFailed
        }
        return try string(from: plain)
    }

    private func randomBytes(_ count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else { throw CryptoError.randomFailed }
        return bytes
    }

    private func deriveKey(password: String, salt: [UInt8]) throws -> SymmetricKey {
        let passwordLength = password.utf8.count
        let saltLength = salt.count
        let derivedLength = 32
        var derived = [UInt8](repeating: 0, count: derivedLength)

        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            password,
            passwordLength,
            salt,
            saltLength,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            Self.pbkdf2Iterations,
            &derived,
            derivedLength
        )
        guard Int(status) == kCCSuccess else { throw CryptoError.keyDerivationFailed }
        return SymmetricKey(data: Data(derived))
    }

    // MARK: AES-CBC / ECB

    private func aesEncrypt(_ text: String) throws -> String {
        let (keyBytes, ivBytes) = try aesKeyAndIV()
        let result = try aesCrypt(
            operation: CCOperation(kCCEncrypt),
            input: [UInt8](text.utf8),
            key: keyBytes,
            iv: ivBytes
        )
        return formatCipher(Data(result))
    }

    private func aesDecrypt(_ text: String) throws -> String {
        let (keyBytes, ivBytes) = try aesKeyAndIV()
        let cipherData = try parseCipher(text)
        let result = try aesCrypt(
            operation: CCOperation(kCCDecrypt),
            input: [UInt8](cipherData),
            key: keyBytes,
            iv: ivBytes
        )
        return try string(from: Data(result))
    }

    private func aesKeyAndIV() throws -> ([UInt8], [UInt8]) {
        guard !key.isEmpty else { throw CryptoError.emptyKey }

        let keyBytes = Array(key.utf8)
        guard keyBytes.count == keySize.byteCount else {
            throw CryptoError.invalidKeyLength(expected: keySize.byteCount, actual: keyBytes.count)
        }

        if algorithm.usesIV {
            let ivBytes = Array(iv.utf8)
            guard ivBytes.count == kCCBlockSizeAES128 else {
                throw CryptoError.invalidIVLength(actual: ivBytes.count)
            }
            return (keyBytes, ivBytes)
        }
        return (keyBytes, [UInt8](repeating: 0, count: kCCBlockSizeAES128))
    }

    private func aesCrypt(operation: CCOperation,
                          input: [UInt8],
                          key: [UInt8],
                          iv: [UInt8]) throws -> [UInt8] {
        var options = CCOptions(kCCOptionPKCS7Padding)
        if algorithm == .aesECB {
            options |= CCOptions(kCCOptionECBMode)
        }

        let capacity = input.count + kCCBlockSizeAES128
        var output = [UInt8](repeating: 0, count: capacity)
        var moved = 0
        let inputLength = input.count
        let keyLength = key.count

        let status = CCCrypt(
            operation,
            CCAlgorithm(kCCAlgorithmAES),
            options,
            key,
            keyLength,
            iv,
            input,
            inputLength,
            &output,
            capacity,
            &moved
        )

        guard Int(status) == kCCSuccess else {
            if Int(operation) == kCCEncrypt {
                throw CryptoError.encryptionFailed
            }
            throw CryptoError.decryptionFailed
        }
        return Array(output[0..<moved])
    }
}
