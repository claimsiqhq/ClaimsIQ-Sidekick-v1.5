//
//  RealtimeManager.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import Combine
import Supabase
import SwiftData

class RealtimeManager: ObservableObject {
    static let shared = RealtimeManager()
    
    private let supabaseManager = SupabaseManager.shared
    private var channel: RealtimeChannelV2?
    private var subscriptions: [AnyCancellable] = []
    
    @Published var isConnected = false
    @Published var lastUpdate: Date?
    @Published var realtimeEvents: [RealtimeEvent] = []
    
    private init() {
        setupRealtimeConnection()
    }
    
    // MARK: - Setup
    
    private func setupRealtimeConnection() {
        // Subscribe to authentication changes
        supabaseManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.connectToRealtime()
                } else {
                    self?.disconnectFromRealtime()
                }
            }
            .store(in: &subscriptions)
    }
    
    // MARK: - Connection Management
    
    func connectToRealtime() {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        // Create channel for user-specific updates
        channel = supabaseManager.client.realtimeV2.channel("claims:\(userId)")
        
        // Subscribe to claims table changes
        subscribeToClaimsChanges()
        
        // Subscribe to photos table changes
        subscribeToPhotosChanges()
        
        // Subscribe to documents table changes
        subscribeToDocumentsChanges()
        
        // Subscribe to activity timeline
        subscribeToActivityChanges()
        
        // Connect to channel
        Task {
            await channel?.subscribe()
            
            await MainActor.run {
                self.isConnected = true
                self.lastUpdate = Date()
            }
            
            print("Connected to Supabase Realtime")
        }
    }
    
    func disconnectFromRealtime() {
        Task {
            await channel?.unsubscribe()
            channel = nil
            
            await MainActor.run {
                self.isConnected = false
            }
            
            print("Disconnected from Supabase Realtime")
        }
    }
    
    // MARK: - Table Subscriptions
    
    private func subscribeToClaimsChanges() {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        // Listen for all events on claims table
        Task {
            await channel?.onPostgresChange(
                InsertAction(
                    schema: "public",
                    table: "claims",
                    filter: "user_id=eq.\(userId)"
                )
            ) { [weak self] action in
                if case let .insert(insertAction) = action {
                    self?.handleClaimInsert(insertAction)
                }
            }
            
            await channel?.onPostgresChange(
                UpdateAction(
                    schema: "public",
                    table: "claims",
                    filter: "user_id=eq.\(userId)"
                )
            ) { [weak self] action in
                if case let .update(updateAction) = action {
                    self?.handleClaimUpdate(updateAction)
                }
            }
            
            await channel?.onPostgresChange(
                DeleteAction(
                    schema: "public",
                    table: "claims",
                    filter: "user_id=eq.\(userId)"
                )
            ) { [weak self] action in
                if case let .delete(deleteAction) = action {
                    self?.handleClaimDelete(deleteAction)
                }
            }
        }
    }
    
    private func subscribeToPhotosChanges() {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        Task {
            await channel?.onPostgresChange(
                InsertAction(
                    schema: "public",
                    table: "photos",
                    filter: "user_id=eq.\(userId)"
                )
            ) { [weak self] action in
                if case let .insert(insertAction) = action {
                    self?.handlePhotoInsert(insertAction)
                }
            }
            
            await channel?.onPostgresChange(
                UpdateAction(
                    schema: "public",
                    table: "photos",
                    filter: "user_id=eq.\(userId)"
                )
            ) { [weak self] action in
                if case let .update(updateAction) = action {
                    self?.handlePhotoUpdate(updateAction)
                }
            }
            
            await channel?.onPostgresChange(
                DeleteAction(
                    schema: "public",
                    table: "photos",
                    filter: "user_id=eq.\(userId)"
                )
            ) { [weak self] action in
                if case let .delete(deleteAction) = action {
                    self?.handlePhotoDelete(deleteAction)
                }
            }
        }
    }
    
    private func subscribeToDocumentsChanges() {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        Task {
            await channel?.onPostgresChange(
                InsertAction(
                    schema: "public",
                    table: "documents",
                    filter: "user_id=eq.\(userId)"
                )
            ) { [weak self] action in
                if case let .insert(insertAction) = action {
                    self?.handleDocumentInsert(insertAction)
                }
            }
        }
    }
    
    private func subscribeToActivityChanges() {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        Task {
            await channel?.onPostgresChange(
                InsertAction(
                    schema: "public",
                    table: "activity_timeline",
                    filter: "user_id=eq.\(userId)"
                )
            ) { [weak self] action in
                if case let .insert(insertAction) = action {
                    self?.handleActivityInsert(insertAction)
                }
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleClaimInsert(_ action: InsertAction) {
        Task { @MainActor in
            let record = action.record
            
            // Create event
            let event = RealtimeEvent(
                type: .claimInserted,
                tableName: "claims",
                recordId: record["id"] as? String,
                timestamp: Date(),
                payload: record
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            // Update local database
            await updateLocalDatabase(event: event)
            
            // Post notification
            NotificationCenter.default.post(
                name: .claimInserted,
                object: nil,
                userInfo: ["record": record]
            )
        }
    }
    
    private func handleClaimUpdate(_ action: UpdateAction) {
        Task { @MainActor in
            let record = action.record
            let oldRecord = action.oldRecord
            
            // Create event
            let event = RealtimeEvent(
                type: .claimUpdated,
                tableName: "claims",
                recordId: record["id"] as? String,
                timestamp: Date(),
                payload: record,
                oldPayload: oldRecord
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            // Update local database
            await updateLocalDatabase(event: event)
            
            // Post notification
            NotificationCenter.default.post(
                name: .claimUpdated,
                object: nil,
                userInfo: ["record": record, "oldRecord": oldRecord]
            )
        }
    }
    
    private func handleClaimDelete(_ action: DeleteAction) {
        Task { @MainActor in
            let oldRecord = action.oldRecord
            
            // Create event
            let event = RealtimeEvent(
                type: .claimDeleted,
                tableName: "claims",
                recordId: oldRecord["id"] as? String,
                timestamp: Date(),
                oldPayload: oldRecord
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            // Update local database
            await updateLocalDatabase(event: event)
            
            // Post notification
            NotificationCenter.default.post(
                name: .claimDeleted,
                object: nil,
                userInfo: ["oldRecord": oldRecord]
            )
        }
    }
    
    private func handlePhotoInsert(_ action: InsertAction) {
        Task { @MainActor in
            let record = action.record
            
            // Create event
            let event = RealtimeEvent(
                type: .photoInserted,
                tableName: "photos",
                recordId: record["id"] as? String,
                timestamp: Date(),
                payload: record
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            // Post notification
            NotificationCenter.default.post(
                name: .photoInserted,
                object: nil,
                userInfo: ["record": record]
            )
        }
    }
    
    private func handlePhotoUpdate(_ action: UpdateAction) {
        // Similar to claim update
    }
    
    private func handlePhotoDelete(_ action: DeleteAction) {
        // Similar to claim delete
    }
    
    private func handleDocumentInsert(_ action: InsertAction) {
        Task { @MainActor in
            let record = action.record
            
            // Create event
            let event = RealtimeEvent(
                type: .documentInserted,
                tableName: "documents",
                recordId: record["id"] as? String,
                timestamp: Date(),
                payload: record
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            // Post notification
            NotificationCenter.default.post(
                name: .documentInserted,
                object: nil,
                userInfo: ["record": record]
            )
        }
    }
    
    private func handleActivityInsert(_ action: InsertAction) {
        Task { @MainActor in
            let record = action.record
            
            // Create event
            let event = RealtimeEvent(
                type: .activityInserted,
                tableName: "activity_timeline",
                recordId: record["id"] as? String,
                timestamp: Date(),
                payload: record
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            // Post notification
            NotificationCenter.default.post(
                name: .activityInserted,
                object: nil,
                userInfo: ["record": record]
            )
        }
    }
    
    // MARK: - Local Database Updates
    
    private func updateLocalDatabase(event: RealtimeEvent) async {
        do {
            let container = try ModelContainer(for: Claim.self, Photo.self, Document.self)
            let context = ModelContext(container)
            
            switch event.type {
            case .claimInserted:
                // Fetch and insert claim if not exists
                if let recordId = event.recordId,
                   let uuid = UUID(uuidString: recordId) {
                    
                    let descriptor = FetchDescriptor<Claim>()
                    let claims = try context.fetch(descriptor)
                    
                    if !claims.contains(where: { $0.id == uuid }) {
                        // Fetch full claim from Supabase
                        // Convert and insert
                    }
                }
                
            case .claimUpdated:
                // Update existing claim
                if let recordId = event.recordId,
                   let uuid = UUID(uuidString: recordId) {
                    
                    let descriptor = FetchDescriptor<Claim>()
                    let claims = try context.fetch(descriptor)
                    
                    if let claim = claims.first(where: { $0.id == uuid }) {
                        // Update claim fields from payload
                        // Mark as synced
                        claim.syncStatus = .synced
                        claim.lastSyncedAt = Date()
                        try context.save()
                    }
                }
                
            case .claimDeleted:
                // Delete claim if exists
                if let recordId = event.recordId,
                   let uuid = UUID(uuidString: recordId) {
                    
                    let descriptor = FetchDescriptor<Claim>()
                    let claims = try context.fetch(descriptor)
                    
                    if let claim = claims.first(where: { $0.id == uuid }) {
                        context.delete(claim)
                        try context.save()
                    }
                }
                
            default:
                break
            }
        } catch {
            print("Failed to update local database: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    func getRecentEvents(limit: Int = 10) -> [RealtimeEvent] {
        Array(realtimeEvents.suffix(limit))
    }
    
    func clearEvents() {
        realtimeEvents.removeAll()
    }
}

// MARK: - Supporting Types

struct RealtimeEvent: Identifiable {
    let id = UUID()
    let type: RealtimeEventType
    let tableName: String
    let recordId: String?
    let timestamp: Date
    let payload: [String: Any]?
    let oldPayload: [String: Any]?
    
    init(
        type: RealtimeEventType,
        tableName: String,
        recordId: String? = nil,
        timestamp: Date = Date(),
        payload: [String: Any]? = nil,
        oldPayload: [String: Any]? = nil
    ) {
        self.type = type
        self.tableName = tableName
        self.recordId = recordId
        self.timestamp = timestamp
        self.payload = payload
        self.oldPayload = oldPayload
    }
}

enum RealtimeEventType {
    case claimInserted
    case claimUpdated
    case claimDeleted
    case photoInserted
    case photoUpdated
    case photoDeleted
    case documentInserted
    case documentUpdated
    case documentDeleted
    case activityInserted
    
    var displayName: String {
        switch self {
        case .claimInserted: return "New Claim"
        case .claimUpdated: return "Claim Updated"
        case .claimDeleted: return "Claim Deleted"
        case .photoInserted: return "Photo Added"
        case .photoUpdated: return "Photo Updated"
        case .photoDeleted: return "Photo Deleted"
        case .documentInserted: return "Document Added"
        case .documentUpdated: return "Document Updated"
        case .documentDeleted: return "Document Deleted"
        case .activityInserted: return "New Activity"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let claimInserted = Notification.Name("claimInserted")
    static let claimUpdated = Notification.Name("claimUpdated")
    static let claimDeleted = Notification.Name("claimDeleted")
    static let photoInserted = Notification.Name("photoInserted")
    static let photoUpdated = Notification.Name("photoUpdated")
    static let photoDeleted = Notification.Name("photoDeleted")
    static let documentInserted = Notification.Name("documentInserted")
    static let activityInserted = Notification.Name("activityInserted")
}
