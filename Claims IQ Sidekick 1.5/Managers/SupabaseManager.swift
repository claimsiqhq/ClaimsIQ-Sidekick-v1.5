//
//  SupabaseManager.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import Combine
import Supabase
import KeychainAccess

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    private let keychain = Keychain(service: "com.claimsiq.sidekick")
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: Configuration.supabaseURL,
            supabaseKey: Configuration.supabaseAnonKey
        )
        
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Authentication
    
    func checkSession() async {
        do {
            let session = try await client.auth.session
            await MainActor.run {
                self.currentUser = session.user
                self.isAuthenticated = true
            }
        } catch {
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        await MainActor.run {
            self.currentUser = session.user
            self.isAuthenticated = true
        }
        
        // Store credentials securely
        try? keychain.set(email, key: "userEmail")
    }
    
    func signUp(email: String, password: String, fullName: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(fullName)]
        )
        
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
        
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
        
        // Clear stored credentials
        try? keychain.remove("userEmail")
    }
    
    // MARK: - Database Operations
    
    func fetchClaims() async throws -> [Claim] {
        let response: [ClaimDTO] = try await client
            .from("claims")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response.map { Claim(from: $0) }
    }
    
    func createClaim(_ claim: Claim) async throws {
        guard currentUser != nil else {
            throw SupabaseError.authRequired
        }
        let dto = claim.toDTO()
        let insertBuilder = try client
            .from("claims")
            .insert(dto)
        
        try await insertBuilder.execute()
    }
    
    func updateClaim(_ claim: Claim) async throws {
        guard currentUser != nil else {
            throw SupabaseError.authRequired
        }
        let dto = claim.toDTO()
        let updateBuilder = try client
            .from("claims")
            .update(dto)
            .eq("id", value: claim.id.uuidString)
        
        try await updateBuilder.execute()
    }
    
    // MARK: - Storage Operations
    
    func uploadPhoto(claimId: String, imageData: Data, fileName: String) async throws -> String {
        guard let userId = currentUser?.id else {
            throw SupabaseError.authRequired
        }
        
        let path = "\(userId)/\(claimId)/\(fileName)"
        
        try await client.storage
            .from(Configuration.photoBucketName)
            .upload(
                path,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        return path
    }
    
    func downloadPhoto(path: String) async throws -> Data {
        return try await client.storage
            .from(Configuration.photoBucketName)
            .download(path: path)
    }
    
    func getPhotoURL(path: String) async throws -> URL {
        return try await client.storage
            .from(Configuration.photoBucketName)
            .createSignedURL(path: path, expiresIn: 3600)
    }
}

// MARK: - Custom Errors

enum SupabaseError: LocalizedError {
    case authRequired
    case uploadFailed
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .authRequired:
            return "Authentication required"
        case .uploadFailed:
            return "Failed to upload file"
        case .downloadFailed:
            return "Failed to download file"
        }
    }
}

// MARK: - DTOs

struct ClaimDTO: Codable {
    let id: String
    let claim_number: String
    let policy_number: String?
    let insured_name: String
    let insured_phone: String?
    let insured_email: String?
    let address: String
    let city: String?
    let state: String?
    let zip_code: String?
    let latitude: Double?
    let longitude: Double?
    let loss_date: String?
    let loss_description: String?
    let status: String
    let priority: String
    let coverage_type: String?
    let deductible: Double?
    let user_id: String
    let created_at: String
    let updated_at: String
}
