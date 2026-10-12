//
//  RSAKit.swift
//  ZXTools
//
//  RSA 密钥生成 / PEM 解析 / 加解密（系统 Security 框架，无三方依赖）
//  支持导入：X.509(SPKI) 公钥、PKCS#8 私钥、PKCS#1 公私钥，有无 PEM 头均可
//  导出格式：X.509 公钥（BEGIN PUBLIC KEY）、PKCS#8 私钥（BEGIN PRIVATE KEY）
//

import Foundation
import Security

enum RSAKit {

    // MARK: - 对外接口

    nonisolated static func generateKeyPair(bits: Int) throws -> (publicPEM: String, privatePEM: String) {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: bits
        ]
        var error: Unmanaged<CFError>?

        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey),
              let privateData = SecKeyCopyExternalRepresentation(privateKey, &error) as Data?,
              let publicData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw CryptoError.keyGenerationFailed
        }

        let publicDER = wrapPublicKey(pkcs1: [UInt8](publicData))
        let privateDER = wrapPrivateKey(pkcs1: [UInt8](privateData))
        return (
            pem(label: "PUBLIC KEY", der: publicDER),
            pem(label: "PRIVATE KEY", der: privateDER)
        )
    }

    nonisolated static func encrypt(_ data: Data, publicPEM: String, oaep: Bool) throws -> Data {
        guard !publicPEM.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CryptoError.emptyPublicKey
        }
        let der = try derFromPEM(publicPEM)
        let key = try makeKey(pkcs1: try publicKeyPKCS1(from: der), isPublic: true)
        let algorithm: SecKeyAlgorithm = oaep ? .rsaEncryptionOAEPSHA256 : .rsaEncryptionPKCS1

        guard SecKeyIsAlgorithmSupported(key, .encrypt, algorithm) else {
            throw CryptoError.encryptionFailed
        }

        let blockSize = SecKeyGetBlockSize(key)
        let maxLength = oaep ? blockSize - 66 : blockSize - 11
        guard data.count <= maxLength else {
            throw CryptoError.rsaInputTooLong(max: maxLength)
        }

        var error: Unmanaged<CFError>?
        guard let result = SecKeyCreateEncryptedData(key, algorithm, data as CFData, &error) as Data? else {
            throw CryptoError.encryptionFailed
        }
        return result
    }

    nonisolated static func decrypt(_ data: Data, privatePEM: String, oaep: Bool) throws -> Data {
        guard !privatePEM.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CryptoError.emptyPrivateKey
        }
        let der = try derFromPEM(privatePEM)
        let key = try makeKey(pkcs1: try privateKeyPKCS1(from: der), isPublic: false)
        let algorithm: SecKeyAlgorithm = oaep ? .rsaEncryptionOAEPSHA256 : .rsaEncryptionPKCS1

        guard SecKeyIsAlgorithmSupported(key, .decrypt, algorithm) else {
            throw CryptoError.decryptionFailed
        }
        guard data.count == SecKeyGetBlockSize(key) else {
            throw CryptoError.invalidCiphertext
        }

        var error: Unmanaged<CFError>?
        guard let result = SecKeyCreateDecryptedData(key, algorithm, data as CFData, &error) as Data? else {
            throw CryptoError.decryptionFailed
        }
        return result
    }

    // MARK: - SecKey

    private nonisolated static func makeKey(pkcs1: [UInt8], isPublic: Bool) throws -> SecKey {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: isPublic ? kSecAttrKeyClassPublic : kSecAttrKeyClassPrivate
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(Data(pkcs1) as CFData, attributes as CFDictionary, &error) else {
            throw CryptoError.invalidRSAKey
        }
        return key
    }

    // MARK: - PEM

    private nonisolated static func derFromPEM(_ text: String) throws -> [UInt8] {
        let body = text
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") }
            .joined()
            .components(separatedBy: .whitespaces)
            .joined()
        guard let data = Data(base64Encoded: body), !data.isEmpty else {
            throw CryptoError.invalidRSAKey
        }
        return [UInt8](data)
    }

    private nonisolated static func pem(label: String, der: [UInt8]) -> String {
        let base64 = Data(der).base64EncodedString()
        var lines: [String] = []
        var index = base64.startIndex
        while index < base64.endIndex {
            let next = base64.index(index, offsetBy: 64, limitedBy: base64.endIndex) ?? base64.endIndex
            lines.append(String(base64[index..<next]))
            index = next
        }
        return (["-----BEGIN \(label)-----"] + lines + ["-----END \(label)-----"]).joined(separator: "\n")
    }

    // MARK: - ASN.1 DER

    private struct TLV {
        let tag: UInt8
        let start: Int
        let end: Int
    }

    private nonisolated static let rsaAlgorithmIdentifier: [UInt8] = [
        0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00
    ]

    private nonisolated static func readTLV(_ bytes: [UInt8], at index: Int) -> TLV? {
        guard index + 2 <= bytes.count else { return nil }
        let tag = bytes[index]
        var cursor = index + 1
        var length = Int(bytes[cursor])
        cursor += 1

        if length & 0x80 != 0 {
            let count = length & 0x7F
            guard count >= 1, count <= 4, cursor + count <= bytes.count else { return nil }
            length = 0
            for _ in 0..<count {
                length = (length << 8) | Int(bytes[cursor])
                cursor += 1
            }
        }

        let end = cursor + length
        guard end <= bytes.count else { return nil }
        return TLV(tag: tag, start: cursor, end: end)
    }

    private nonisolated static func children(of bytes: [UInt8], in parent: TLV) -> [TLV] {
        var result: [TLV] = []
        var cursor = parent.start
        while cursor < parent.end {
            guard let item = readTLV(bytes, at: cursor), item.end <= parent.end else { break }
            result.append(item)
            cursor = item.end
        }
        return result
    }

    private nonisolated static func publicKeyPKCS1(from der: [UInt8]) throws -> [UInt8] {
        guard let outer = readTLV(der, at: 0), outer.tag == 0x30 else {
            throw CryptoError.invalidRSAKey
        }
        let items = children(of: der, in: outer)

        // X.509 SubjectPublicKeyInfo：SEQUENCE { SEQUENCE(算法), BIT STRING(PKCS#1) }
        if items.count >= 2, items[0].tag == 0x30, items[1].tag == 0x03, items[1].end - items[1].start > 1 {
            return Array(der[(items[1].start + 1)..<items[1].end])
        }
        // PKCS#1 RSAPublicKey：SEQUENCE { INTEGER, INTEGER }
        if items.count == 2, items[0].tag == 0x02 {
            return Array(der[0..<outer.end])
        }
        throw CryptoError.invalidRSAKey
    }

    private nonisolated static func privateKeyPKCS1(from der: [UInt8]) throws -> [UInt8] {
        guard let outer = readTLV(der, at: 0), outer.tag == 0x30 else {
            throw CryptoError.invalidRSAKey
        }
        let items = children(of: der, in: outer)

        // PKCS#8：SEQUENCE { INTEGER, SEQUENCE(算法), OCTET STRING(PKCS#1) }
        if items.count >= 3, items[1].tag == 0x30, items[2].tag == 0x04 {
            return Array(der[items[2].start..<items[2].end])
        }
        // PKCS#1 RSAPrivateKey：SEQUENCE { 9 个 INTEGER }
        if items.count >= 9, items[0].tag == 0x02, items[1].tag == 0x02 {
            return Array(der[0..<outer.end])
        }
        throw CryptoError.invalidRSAKey
    }

    private nonisolated static func derLength(_ length: Int) -> [UInt8] {
        if length < 0x80 { return [UInt8(length)] }
        var bytes: [UInt8] = []
        var value = length
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return [0x80 | UInt8(bytes.count)] + bytes
    }

    private nonisolated static func derWrap(tag: UInt8, _ content: [UInt8]) -> [UInt8] {
        [tag] + derLength(content.count) + content
    }

    private nonisolated static func wrapPublicKey(pkcs1: [UInt8]) -> [UInt8] {
        let bitString = derWrap(tag: 0x03, [0x00] + pkcs1)
        return derWrap(tag: 0x30, rsaAlgorithmIdentifier + bitString)
    }

    private nonisolated static func wrapPrivateKey(pkcs1: [UInt8]) -> [UInt8] {
        let version: [UInt8] = [0x02, 0x01, 0x00]
        let octetString = derWrap(tag: 0x04, pkcs1)
        return derWrap(tag: 0x30, version + rsaAlgorithmIdentifier + octetString)
    }
}
