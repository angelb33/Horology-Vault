//
//  KeychainHelper.swift
//  Horology Vault
//
//  Created by Angel Burgos on 2026-07-15.
//

import Foundation
import Security

/// Stores the scheduled backup's passphrase in the Keychain so `ScheduledBackupManager` can
/// re-encrypt automatically without prompting — the encrypted backup format can't be produced
/// silently otherwise. Not used anywhere else; the manual "Encrypted Backup" button in Settings
/// still prompts for a passphrase each time and never touches the Keychain.
enum KeychainHelper {
    private static let service = Bundle.main.bundleIdentifier ?? "com.angelburgos.HorologyVault"
    private static let account = "scheduledBackupPassphrase"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// Update-or-add: repeated calls (e.g. "change passphrase") don't need a separate delete step.
    @discardableResult
    static func savePassphrase(_ passphrase: String) -> Bool {
        guard let data = passphrase.data(using: .utf8) else { return false }

        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        guard updateStatus == errSecItemNotFound else { return false }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    static func readPassphrase() -> String? {
        var readQuery = query
        readQuery[kSecReturnData as String] = true
        readQuery[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(readQuery as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deletePassphrase() {
        SecItemDelete(query as CFDictionary)
    }
}
