//
//  DataManager.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import SwiftData
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    private let supabaseManager = SupabaseManager.shared
    private let syncManager = SyncManager.shared
    private let modelContainer: ModelContainer
    
    @Published var isSyncing = false
    @Published var syncError: Error?
    
    private init() {
        do {
            let schema = Schema([
                Claim.self,
                Photo.self,
                Document.self,
                Inspection.self,
                ActivityTimeline.self,
                InspectionChecklist.self,
                SyncQueue.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Claims Operations
    
    @MainActor
    func createClaim(_ claim: Claim, in context: ModelContext) async throws {
        // Save locally first
        context.insert(claim)
        try context.save()
        
        // Add to sync queue
        let syncItem = createSyncQueueItem(
            for: claim,
            operation: .create,
            tableName: "claims"
        )
        context.insert(syncItem)
        try context.save()
        
        // Try immediate sync if online
        if syncManager.isOnline {
            Task {
                try? await supabaseManager.createClaim(claim)
                syncItem.markCompleted()
                try? context.save()
            }
        }
    }
    
    @MainActor
    func updateClaim(_ claim: Claim, in context: ModelContext) async throws {
        claim.updatedAt = Date()
        claim.syncStatus = .pending
        try context.save()
        
        // Add to sync queue
        let syncItem = createSyncQueueItem(
            for: claim,
            operation: .update,
            tableName: "claims"
        )
        context.insert(syncItem)
        try context.save()
        
        // Try immediate sync if online
        if syncManager.isOnline {
            Task {
                try? await supabaseManager.updateClaim(claim)
                claim.syncStatus = .synced
                claim.lastSyncedAt = Date()
                syncItem.markCompleted()
                try? context.save()
            }
        }
    }
    
    @MainActor
    func deleteClaim(_ claim: Claim, in context: ModelContext) async throws {
        let claimId = claim.id
        
        // Add to sync queue before deletion
        let syncItem = SyncQueue(
            operationType: .delete,
            tableName: "claims",
            recordId: claimId,
            data: try JSONEncoder().encode(["id": claimId.uuidString])
        )
        context.insert(syncItem)
        
        // Delete locally
        context.delete(claim)
        try context.save()
        
        // Try immediate sync if online
        if syncManager.isOnline {
            Task {
                // Implement delete in Supabase
                syncItem.markCompleted()
                try? context.save()
            }
        }
    }
    
    // MARK: - Photos Operations
    
    @MainActor
    func savePhoto(_ photo: Photo, imageData: Data, in context: ModelContext) async throws {
        // Save image locally first
        let localPath = try await saveImageLocally(imageData, fileName: photo.storagePath)
        photo.localPath = localPath
        photo.fileSize = imageData.count
        
        // Save to database
        context.insert(photo)
        try context.save()
        
        // Add to sync queue
        let syncItem = createSyncQueueItem(
            for: photo,
            operation: .create,
            tableName: "photos"
        )
        context.insert(syncItem)
        try context.save()
        
        // Upload in background if online
        if syncManager.isOnline {
            Task {
                do {
                    let storagePath = try await supabaseManager.uploadPhoto(
                        claimId: photo.claim?.id.uuidString ?? "",
                        imageData: imageData,
                        fileName: URL(fileURLWithPath: photo.storagePath).lastPathComponent
                    )
                    
                    photo.storagePath = storagePath
                    photo.isSynced = true
                    syncItem.markCompleted()
                    try? context.save()
                } catch {
                    print("Failed to upload photo: \(error)")
                }
            }
        }
    }
    
    // MARK: - Fetch Operations
    
    @MainActor
    func refreshClaims(in context: ModelContext) async throws {
        guard syncManager.isOnline else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let remoteClaims = try await supabaseManager.fetchClaims()
            
            for remoteClaim in remoteClaims {
                // Check if claim exists locally
                let remoteId = remoteClaim.id
                let descriptor = FetchDescriptor<Claim>()
                let allClaims = try context.fetch(descriptor)
                
                if let existingClaim = allClaims.first(where: { $0.id == remoteId }) {
                    // Update existing claim if remote is newer
                    if remoteClaim.updatedAt > existingClaim.updatedAt {
                        updateLocalClaim(existingClaim, from: remoteClaim)
                    }
                } else {
                    // Insert new claim
                    context.insert(remoteClaim)
                }
            }
            
            try context.save()
        } catch {
            syncError = error
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSyncQueueItem(
        for claim: Claim,
        operation: SyncOperationType,
        tableName: String
    ) -> SyncQueue {
        do {
            let dto = claim.toDTO()
            let data = try JSONEncoder().encode(dto)
            return SyncQueue(
                operationType: operation,
                tableName: tableName,
                recordId: claim.id,
                data: data
            )
        } catch {
            // Fallback with minimal data
            return SyncQueue(
                operationType: operation,
                tableName: tableName,
                recordId: claim.id,
                data: Data()
            )
        }
    }
    
    private func createSyncQueueItem(
        for photo: Photo,
        operation: SyncOperationType,
        tableName: String
    ) -> SyncQueue {
        do {
            // Create a simple DTO for photo
            let photoData: [String: Any] = [
                "id": photo.id.uuidString,
                "storage_path": photo.storagePath,
                "claim_id": photo.claim?.id.uuidString ?? "",
                "damage_type": photo.damageType ?? "",
                "is_synced": photo.isSynced
            ]
            let data = try JSONSerialization.data(withJSONObject: photoData)
            return SyncQueue(
                operationType: operation,
                tableName: tableName,
                recordId: photo.id,
                data: data
            )
        } catch {
            return SyncQueue(
                operationType: operation,
                tableName: tableName,
                recordId: photo.id,
                data: Data()
            )
        }
    }
    
    private func saveImageLocally(_ imageData: Data, fileName: String) async throws -> String {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        
        let photosDirectory = documentsPath.appendingPathComponent("photos")
        
        // Create directory if needed
        try FileManager.default.createDirectory(
            at: photosDirectory,
            withIntermediateDirectories: true
        )
        
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        try imageData.write(to: fileURL)
        
        return fileURL.path
    }
    
    private func updateLocalClaim(_ local: Claim, from remote: Claim) {
        local.claimNumber = remote.claimNumber
        local.policyNumber = remote.policyNumber
        local.insuredName = remote.insuredName
        local.insuredPhone = remote.insuredPhone
        local.insuredEmail = remote.insuredEmail
        local.address = remote.address
        local.city = remote.city
        local.state = remote.state
        local.zipCode = remote.zipCode
        local.latitude = remote.latitude
        local.longitude = remote.longitude
        local.lossDate = remote.lossDate
        local.lossDescription = remote.lossDescription
        local.status = remote.status
        local.priority = remote.priority
        local.coverageType = remote.coverageType
        local.deductible = remote.deductible
        local.updatedAt = remote.updatedAt
        local.syncStatus = .synced
        local.lastSyncedAt = Date()
    }
    
    // MARK: - Background Operations
    
    func performBackgroundSync() async {
        await syncManager.performSync()
    }
    
    func getPendingSyncCount() async -> Int {
        await syncManager.getPendingSyncCount()
    }
}

// MARK: - ModelContext Extension

extension ModelContext {
    func fetchCount<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> Int {
        let items = try fetch(descriptor)
        return items.count
    }
}
