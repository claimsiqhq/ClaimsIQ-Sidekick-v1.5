//
//  KeychainManager.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import KeychainAccess

class KeychainManager {
    static let shared = KeychainManager()
    private let keychain: Keychain
    
    private init() {
        self.keychain = Keychain(service: "com.claimsiq.sidekick")
            .synchronizable(true)
    }
    
    // MARK: - User Credentials
    
    func saveUserCredentials(email: String, userId: String) {
        try? keychain.set(email, key: "userEmail")
        try? keychain.set(userId, key: "userId")
        try? keychain.set(Date().timeIntervalSince1970.description, key: "lastLogin")
    }
    
    func getUserEmail() -> String? {
        return try? keychain.get("userEmail")
    }
    
    func getUserId() -> String? {
        return try? keychain.get("userId")
    }
    
    func clearUserCredentials() {
        try? keychain.remove("userEmail")
        try? keychain.remove("userId")
        try? keychain.remove("lastLogin")
    }
    
    // MARK: - Secure Storage
    
    func save(_ value: String, for key: String) {
        try? keychain.set(value, key: key)
    }
    
    func get(_ key: String) -> String? {
        return try? keychain.get(key)
    }
    
    func remove(_ key: String) {
        try? keychain.remove(key)
    }
    
    func saveData(_ data: Data, for key: String) {
        try? keychain.set(data, key: key)
    }
    
    func getData(_ key: String) -> Data? {
        return try? keychain.getData(key)
    }
    
    // MARK: - Sync State
    
    func saveSyncToken(_ token: String) {
        try? keychain.set(token, key: "syncToken")
    }
    
    func getSyncToken() -> String? {
        return try? keychain.get("syncToken")
    }
    
    func saveLastSyncDate(_ date: Date) {
        try? keychain.set(date.timeIntervalSince1970.description, key: "lastSyncDate")
    }
    
    func getLastSyncDate() -> Date? {
        guard let timestampString = try? keychain.get("lastSyncDate"),
              let timestamp = Double(timestampString) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
}
