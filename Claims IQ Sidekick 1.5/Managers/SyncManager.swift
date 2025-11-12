//
//  SyncManager.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import SwiftData
import Network
import Combine

class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    @Published var lastSyncDate: Date?
    @Published var pendingSyncCount = 0
    @Published var isOnline = true
    
    private let networkMonitor = NWPathMonitor()
    private let backgroundQueue = DispatchQueue(label: "com.claimsiq.sync", qos: .background)
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let keychain = KeychainManager.shared
    
    private init() {
        setupNetworkMonitoring()
        loadLastSyncDate()
        startPeriodicSync()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied
                
                // If we just came online, trigger sync
                if wasOffline && self?.isOnline == true {
                    Task {
                        await self?.performSync()
                    }
                }
            }
        }
        
        let queue = DispatchQueue(label: "com.claimsiq.networkmonitor")
        networkMonitor.start(queue: queue)
    }
    
    // MARK: - Sync Operations
    
    @MainActor
    func performSync() async {
        guard isOnline, !isSyncing else { return }
        
        isSyncing = true
        syncProgress = 0.0
        
        do {
            // Get ModelContext
            let container = try ModelContainer(for: SyncQueue.self, Claim.self, Photo.self, Document.self)
            let context = ModelContext(container)
            
            // Fetch pending sync items
            let descriptor = FetchDescriptor<SyncQueue>(
                predicate: #Predicate { $0.status == .pending || $0.status == .failed },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            
            let syncItems = try context.fetch(descriptor)
            pendingSyncCount = syncItems.count
            
            if syncItems.isEmpty {
                isSyncing = false
                lastSyncDate = Date()
                saveLastSyncDate()
                return
            }
            
            // Process each sync item
            for (index, syncItem) in syncItems.enumerated() {
                syncProgress = Double(index) / Double(syncItems.count)
                
                do {
                    try await processSyncItem(syncItem, in: context)
                    
                    // Mark as completed
                    syncItem.markCompleted()
                    try context.save()
                    
                } catch {
                    print("Sync failed for item \(syncItem.id): \(error)")
                    syncItem.markFailed(error: error.localizedDescription)
                    
                    if syncItem.canRetry {
                        // Will retry in next sync
                    } else {
                        // Move to dead letter queue or handle differently
                    }
                    
                    try? context.save()
                }
            }
            
            // Update sync status
            syncProgress = 1.0
            lastSyncDate = Date()
            saveLastSyncDate()
            pendingSyncCount = 0
            
        } catch {
            print("Sync error: \(error)")
        }
        
        isSyncing = false
    }
    
    private func processSyncItem(_ item: SyncQueue, in context: ModelContext) async throws {
        switch item.tableName {
        case "claims":
            try await syncClaim(item, in: context)
        case "photos":
            try await syncPhoto(item, in: context)
        case "documents":
            try await syncDocument(item, in: context)
        case "inspections":
            try await syncInspection(item, in: context)
        case "inspection_checklist":
            try await syncChecklistItem(item, in: context)
        case "activity_timeline":
            try await syncActivity(item, in: context)
        default:
            throw SyncError.unsupportedTable(item.tableName)
        }
    }
    
    // MARK: - Table-Specific Sync
    
    private func syncClaim(_ item: SyncQueue, in context: ModelContext) async throws {
        let claimDTO = try item.getData(as: ClaimDTO.self)
        
        switch item.operationType {
        case .create:
            try await SupabaseManager.shared.client.database
                .from("claims")
                .insert(claimDTO)
                .execute()
                
        case .update:
            guard let recordId = item.recordId else {
                throw SyncError.missingRecordId
            }
            
            try await SupabaseManager.shared.client.database
                .from("claims")
                .update(claimDTO)
                .eq("id", value: recordId.uuidString)
                .execute()
                
        case .delete:
            guard let recordId = item.recordId else {
                throw SyncError.missingRecordId
            }
            
            try await SupabaseManager.shared.client.database
                .from("claims")
                .delete()
                .eq("id", value: recordId.uuidString)
                .execute()
        }
    }
    
    private func syncPhoto(_ item: SyncQueue, in context: ModelContext) async throws {
        switch item.operationType {
        case .create:
            // Get photo data
            guard let recordId = item.recordId else {
                throw SyncError.missingRecordId
            }
            
            let descriptor = FetchDescriptor<Photo>()
            let photos = try context.fetch(descriptor)
            
            guard let photo = photos.first(where: { $0.id == recordId }) else {
                throw SyncError.recordNotFound
            }
            
            // Upload image if not already uploaded
            if !photo.isSynced, let localPath = photo.localPath {
                let imageURL = URL(fileURLWithPath: localPath)
                let imageData = try Data(contentsOf: imageURL)
                
                let storagePath = try await SupabaseManager.shared.uploadPhoto(
                    claimId: photo.claim?.id.uuidString ?? "",
                    imageData: imageData,
                    fileName: URL(fileURLWithPath: photo.storagePath).lastPathComponent
                )
                
                photo.storagePath = storagePath
                photo.isSynced = true
                try context.save()
            }
            
            // Create database record
            let photoData = try item.getData(as: [String: Any].self)
            try await SupabaseManager.shared.client.database
                .from("photos")
                .insert(photoData)
                .execute()
                
        case .update, .delete:
            // Similar implementation for update and delete
            break
        }
    }
    
    private func syncDocument(_ item: SyncQueue, in context: ModelContext) async throws {
        // Similar to photo sync
    }
    
    private func syncInspection(_ item: SyncQueue, in context: ModelContext) async throws {
        // Implement inspection sync
    }
    
    private func syncChecklistItem(_ item: SyncQueue, in context: ModelContext) async throws {
        // Implement checklist sync
    }
    
    private func syncActivity(_ item: SyncQueue, in context: ModelContext) async throws {
        // Implement activity sync
    }
    
    // MARK: - Periodic Sync
    
    private func startPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: Configuration.backgroundFetchInterval, repeats: true) { _ in
            Task {
                await self.performSync()
            }
        }
    }
    
    func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflict<T: Codable>(local: T, remote: T, strategy: ConflictResolutionStrategy) -> T {
        switch strategy {
        case .lastWriteWins:
            // Compare timestamps and return the newer one
            return local // Simplified - would need timestamp comparison
        case .localWins:
            return local
        case .remoteWins:
            return remote
        case .merge:
            // Custom merge logic would go here
            return local
        }
    }
    
    // MARK: - Background Sync
    
    func scheduleBackgroundSync() {
        // This would be called from the app delegate for background fetch
        Task {
            await performSync()
        }
    }
    
    // MARK: - Persistence
    
    private func loadLastSyncDate() {
        lastSyncDate = keychain.getLastSyncDate()
    }
    
    private func saveLastSyncDate() {
        if let date = lastSyncDate {
            keychain.saveLastSyncDate(date)
        }
    }
    
    // MARK: - Public Methods
    
    func markForSync<T: PersistentModel>(_ model: T, operation: SyncOperationType) {
        // This would be called when local changes are made
        // Creates a SyncQueue entry for the model
    }
    
    func getPendingSyncCount() async -> Int {
        do {
            let container = try ModelContainer(for: SyncQueue.self)
            let context = ModelContext(container)
            
            let descriptor = FetchDescriptor<SyncQueue>(
                predicate: #Predicate { $0.status == .pending || $0.status == .failed }
            )
            
            let count = try context.fetchCount(descriptor)
            
            await MainActor.run {
                self.pendingSyncCount = count
            }
            
            return count
        } catch {
            return 0
        }
    }
}

// MARK: - Supporting Types

enum SyncError: LocalizedError {
    case unsupportedTable(String)
    case missingRecordId
    case recordNotFound
    case networkError
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .unsupportedTable(let table):
            return "Unsupported table: \(table)"
        case .missingRecordId:
            return "Missing record ID for sync operation"
        case .recordNotFound:
            return "Record not found in local database"
        case .networkError:
            return "Network error during sync"
        case .authenticationRequired:
            return "Authentication required for sync"
        }
    }
}

enum ConflictResolutionStrategy {
    case lastWriteWins
    case localWins
    case remoteWins
    case merge
}

