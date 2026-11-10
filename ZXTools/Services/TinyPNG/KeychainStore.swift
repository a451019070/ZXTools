//
//  KeychainStore.swift
//  ZXTools
//
//  Created by ZX on 2026/10/13.
//

import Foundation
import Security

/// 有开发者签名时存钥匙串；无签名（本地调试 / ad-hoc）时钥匙串会因签名变化拒绝读取，改存 UserDefaults。
nonisolated enum KeychainStore {
    private static let service = "ZX.ZXTools"
    private static let defaultsPrefix = "ZX.ZXTools.secret."

    /// 当前进程是否带有 TeamIdentifier（即被正式开发者签名）
    static let isSigned: Bool = {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return false }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return false }

        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &info
        ) == errSecSuccess,
            let dict = info as? [String: Any] else { return false }

        let team = dict[kSecCodeInfoTeamIdentifier as String] as? String
        return !(team ?? "").isEmpty
    }()

    /// 用于界面提示
    static var storageName: String { isSigned ? "钥匙串" : "本地偏好设置" }

    static func read(account: String) -> String? {
        guard isSigned else {
            return UserDefaults.standard.string(forKey: defaultsPrefix + account)
        }

        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ value: String, account: String) -> Bool {
        guard isSigned else {
            UserDefaults.standard.set(value, forKey: defaultsPrefix + account)
            return true
        }

        let data = Data(value.utf8)
        let query = baseQuery(account: account)

        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func delete(account: String) -> Bool {
        guard isSigned else {
            UserDefaults.standard.removeObject(forKey: defaultsPrefix + account)
            return true
        }

        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
