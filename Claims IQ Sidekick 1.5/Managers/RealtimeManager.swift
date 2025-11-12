//
//  RealtimeManager.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import Supabase
import SwiftData
import Combine

class RealtimeManager: ObservableObject {
    static let shared = RealtimeManager()
    
    private let supabaseManager = SupabaseManager.shared
    private var channel: RealtimeChannel?
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
        channel = supabaseManager.client.realtime.channel("claims:\(userId)")
        
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
            do {
                await channel?.subscribe()
                
                await MainActor.run {
                    self.isConnected = true
                    self.lastUpdate = Date()
                }
                
                print("Connected to Supabase Realtime")
            }
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
        
        // Listen for INSERT events
        channel?.onPostgresChange(
            event: .insert,
            schema: "public",
            table: "claims",
            filter: "user_id=eq.\(userId)"
        ) { [weak self] payload in
            self?.handleClaimInsert(payload)
        }
        
        // Listen for UPDATE events
        channel?.onPostgresChange(
            event: .update,
            schema: "public",
            table: "claims",
            filter: "user_id=eq.\(userId)"
        ) { [weak self] payload in
            self?.handleClaimUpdate(payload)
        }
        
        // Listen for DELETE events
        channel?.onPostgresChange(
            event: .delete,
            schema: "public",
            table: "claims",
            filter: "user_id=eq.\(userId)"
        ) { [weak self] payload in
            self?.handleClaimDelete(payload)
        }
    }
    
    private func subscribeToPhotosChanges() {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        channel?.onPostgresChange(
            event: .insert,
            schema: "public",
            table: "photos",
            filter: "user_id=eq.\(userId)"
        ) { [weak self] payload in
            self?.handlePhotoInsert(payload)
        }
        
        channel?.onPostgresChange(
            event: .update,
            schema: "public",
            table: "photos",
            filter: "user_id=eq.\(userId)"
        ) { [weak self] payload in
            self?.handlePhotoUpdate(payload)
        }
        
        channel?.onPostgresChange(
            event: .delete,
            schema: "public",
            table: "photos",
            filter: "user_id=eq.\(userId)"
        ) { [weak self] payload in
            self?.handlePhotoDelete(payload)
        }
    }
    
    private func subscribeToDocumentsChanges() {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        channel?.onPostgresChange(
            event: .insert,
            schema: "public",
            table: "documents",
            filter: "user_id=eq.\(userId)"
        ) { [weak self] payload in
            self?.handleDocumentInsert(payload)
        }
    }
    
    private func subscribeToActivityChanges() {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        channel?.onPostgresChange(
            event: .insert,
            schema: "public",
            table: "activity_timeline",
            filter: "user_id=eq.\(userId)"
        ) { [weak self] payload in
            self?.handleActivityInsert(payload)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleClaimInsert(_ payload: PostgresChangePayload) {
        Task { @MainActor in
            guard let record = payload.record else { return }
            
            // Create event
            let event = RealtimeEvent(
                type: .claimInserted,
                tableName: "claims",
                recordId: record["id"]?.stringValue,
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
    
    private func handleClaimUpdate(_ payload: PostgresChangePayload) {
        Task { @MainActor in
            guard let record = payload.record,
                  let oldRecord = payload.oldRecord else { return }
            
            // Create event
            let event = RealtimeEvent(
                type: .claimUpdated,
                tableName: "claims",
                recordId: record["id"]?.stringValue,
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
    
    private func handleClaimDelete(_ payload: PostgresChangePayload) {
        Task { @MainActor in
            guard let oldRecord = payload.oldRecord else { return }
            
            // Create event
            let event = RealtimeEvent(
                type: .claimDeleted,
                tableName: "claims",
                recordId: oldRecord["id"]?.stringValue,
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
    
    private func handlePhotoInsert(_ payload: PostgresChangePayload) {
        Task { @MainActor in
            guard let record = payload.record else { return }
            
            // Create event
            let event = RealtimeEvent(
                type: .photoInserted,
                tableName: "photos",
                recordId: record["id"]?.stringValue,
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
    
    private func handlePhotoUpdate(_ payload: PostgresChangePayload) {
        // Similar to claim update
    }
    
    private func handlePhotoDelete(_ payload: PostgresChangePayload) {
        // Similar to claim delete
    }
    
    private func handleDocumentInsert(_ payload: PostgresChangePayload) {
        Task { @MainActor in
            guard let record = payload.record else { return }
            
            // Create event
            let event = RealtimeEvent(
                type: .documentInserted,
                tableName: "documents",
                recordId: record["id"]?.stringValue,
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
    
    private func handleActivityInsert(_ payload: PostgresChangePayload) {
        Task { @MainActor in
            guard let record = payload.record else { return }
            
            // Create event
            let event = RealtimeEvent(
                type: .activityInserted,
                tableName: "activity_timeline",
                recordId: record["id"]?.stringValue,
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
                    
                    let predicate = #Predicate<Claim> { $0.id == uuid }
                    let descriptor = FetchDescriptor<Claim>(predicate: predicate)
                    
                    if try context.fetch(descriptor).isEmpty {
                        // Fetch full claim from Supabase
                        // Convert and insert
                    }
                }
                
            case .claimUpdated:
                // Update existing claim
                if let recordId = event.recordId,
                   let uuid = UUID(uuidString: recordId) {
                    
                    let predicate = #Predicate<Claim> { $0.id == uuid }
                    let descriptor = FetchDescriptor<Claim>(predicate: predicate)
                    
                    if let claim = try context.fetch(descriptor).first {
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
                    
                    let predicate = #Predicate<Claim> { $0.id == uuid }
                    let descriptor = FetchDescriptor<Claim>(predicate: predicate)
                    
                    if let claim = try context.fetch(descriptor).first {
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
    let payload: [String: AnyJSON]?
    let oldPayload: [String: AnyJSON]?
    
    init(
        type: RealtimeEventType,
        tableName: String,
        recordId: String? = nil,
        timestamp: Date = Date(),
        payload: [String: AnyJSON]? = nil,
        oldPayload: [String: AnyJSON]? = nil
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
