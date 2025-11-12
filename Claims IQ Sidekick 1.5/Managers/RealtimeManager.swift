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
        // Monitor auth state changes
        supabaseManager.$currentUser
            .sink { [weak self] user in
                if user != nil {
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
            do {
                _ = await channel?.subscribe { error in
                    if let error = error {
                        print("Failed to connect to Realtime: \(error)")
                    } else {
                        Task { @MainActor in
                            self.isConnected = true
                            self.lastUpdate = Date()
                        }
                        print("Connected to Supabase Realtime")
                    }
                }
            }
        }
    }
    
    func disconnectFromRealtime() {
        Task {
            await channel?.unsubscribe()
            await MainActor.run {
                self.isConnected = false
            }
        }
    }
    
    // MARK: - Table Subscriptions
    
    private func subscribeToClaimsChanges() {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        Task {
            // Listen for INSERT events
            await channel?.onPostgresChange(
                event: .insert,
                schema: "public",
                table: "claims",
                filter: "user_id=eq.\(userId)"
            ) { [weak self] change in
                self?.handleClaimInsert(change)
            }
            
            // Listen for UPDATE events
            await channel?.onPostgresChange(
                event: .update,
                schema: "public",
                table: "claims",
                filter: "user_id=eq.\(userId)"
            ) { [weak self] change in
                self?.handleClaimUpdate(change)
            }
            
            // Listen for DELETE events
            await channel?.onPostgresChange(
                event: .delete,
                schema: "public",
                table: "claims",
                filter: "user_id=eq.\(userId)"
            ) { [weak self] change in
                self?.handleClaimDelete(change)
            }
        }
    }
    
    private func subscribeToPhotosChanges() {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        Task {
            await channel?.onPostgresChange(
                event: .insert,
                schema: "public",
                table: "photos",
                filter: "user_id=eq.\(userId)"
            ) { [weak self] change in
                self?.handlePhotoInsert(change)
            }
            
            await channel?.onPostgresChange(
                event: .update,
                schema: "public",
                table: "photos",
                filter: "user_id=eq.\(userId)"
            ) { [weak self] change in
                self?.handlePhotoUpdate(change)
            }
            
            await channel?.onPostgresChange(
                event: .delete,
                schema: "public",
                table: "photos",
                filter: "user_id=eq.\(userId)"
            ) { [weak self] change in
                self?.handlePhotoDelete(change)
            }
        }
    }
    
    private func subscribeToDocumentsChanges() {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        Task {
            await channel?.onPostgresChange(
                event: .insert,
                schema: "public",
                table: "documents",
                filter: "user_id=eq.\(userId)"
            ) { [weak self] change in
                self?.handleDocumentInsert(change)
            }
        }
    }
    
    private func subscribeToActivityChanges() {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        Task {
            await channel?.onPostgresChange(
                event: .insert,
                schema: "public",
                table: "activity_timeline",
                filter: "user_id=eq.\(userId)"
            ) { [weak self] change in
                self?.handleActivityInsert(change)
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleClaimInsert(_ change: PostgresChangePayload) {
        Task { @MainActor in
            let record = change.new
            
            // Create event
            let event = RealtimeEvent(
                type: .claimInserted,
                tableName: "claims",
                recordId: extractStringValue(from: record["id"]),
                timestamp: Date(),
                payload: convertToDict(record)
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            // Update local database
            await processRealtimeEvent(event)
            
            // Trigger UI update
            objectWillChange.send()
        }
    }
    
    private func handleClaimUpdate(_ change: PostgresChangePayload) {
        Task { @MainActor in
            let record = change.new
            let oldRecord = change.old
            
            let event = RealtimeEvent(
                type: .claimUpdated,
                tableName: "claims",
                recordId: extractStringValue(from: record["id"]),
                timestamp: Date(),
                payload: convertToDict(record),
                oldPayload: convertToDict(oldRecord)
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            await processRealtimeEvent(event)
            objectWillChange.send()
        }
    }
    
    private func handleClaimDelete(_ change: PostgresChangePayload) {
        Task { @MainActor in
            let oldRecord = change.old
            
            let event = RealtimeEvent(
                type: .claimDeleted,
                tableName: "claims",
                recordId: extractStringValue(from: oldRecord["id"]),
                timestamp: Date(),
                oldPayload: convertToDict(oldRecord)
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            await processRealtimeEvent(event)
            objectWillChange.send()
        }
    }
    
    private func handlePhotoInsert(_ change: PostgresChangePayload) {
        Task { @MainActor in
            let record = change.new
            
            let event = RealtimeEvent(
                type: .photoInserted,
                tableName: "photos",
                recordId: extractStringValue(from: record["id"]),
                timestamp: Date(),
                payload: convertToDict(record)
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            await processRealtimeEvent(event)
            objectWillChange.send()
        }
    }
    
    private func handlePhotoUpdate(_ change: PostgresChangePayload) {
        // Similar to claim update
        Task { @MainActor in
            let record = change.new
            let oldRecord = change.old
            
            let event = RealtimeEvent(
                type: .photoUpdated,
                tableName: "photos",
                recordId: extractStringValue(from: record["id"]),
                timestamp: Date(),
                payload: convertToDict(record),
                oldPayload: convertToDict(oldRecord)
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            await processRealtimeEvent(event)
            objectWillChange.send()
        }
    }
    
    private func handlePhotoDelete(_ change: PostgresChangePayload) {
        // Similar to claim delete
        Task { @MainActor in
            let oldRecord = change.old
            
            let event = RealtimeEvent(
                type: .photoDeleted,
                tableName: "photos",
                recordId: extractStringValue(from: oldRecord["id"]),
                timestamp: Date(),
                oldPayload: convertToDict(oldRecord)
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            await processRealtimeEvent(event)
            objectWillChange.send()
        }
    }
    
    private func handleDocumentInsert(_ change: PostgresChangePayload) {
        Task { @MainActor in
            let record = change.new
            
            let event = RealtimeEvent(
                type: .documentInserted,
                tableName: "documents",
                recordId: extractStringValue(from: record["id"]),
                timestamp: Date(),
                payload: convertToDict(record)
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            objectWillChange.send()
        }
    }
    
    private func handleActivityInsert(_ change: PostgresChangePayload) {
        Task { @MainActor in
            let record = change.new
            
            let event = RealtimeEvent(
                type: .activityInserted,
                tableName: "activity_timeline",
                recordId: extractStringValue(from: record["id"]),
                timestamp: Date(),
                payload: convertToDict(record)
            )
            
            realtimeEvents.append(event)
            lastUpdate = Date()
            
            objectWillChange.send()
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractStringValue(from json: AnyJSON?) -> String? {
        guard let json = json else { return nil }
        
        switch json {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        default:
            return nil
        }
    }
    
    private func convertToDict(_ json: [String: AnyJSON]) -> [String: Any] {
        var dict: [String: Any] = [:]
        for (key, value) in json {
            switch value {
            case .string(let str):
                dict[key] = str
            case .int(let int):
                dict[key] = int
            case .double(let double):
                dict[key] = double
            case .bool(let bool):
                dict[key] = bool
            case .array(let array):
                dict[key] = array.map { convertAnyJSON($0) }
            case .object(let obj):
                dict[key] = convertToDict(obj)
            case .null:
                dict[key] = NSNull()
            }
        }
        return dict
    }
    
    private func convertAnyJSON(_ json: AnyJSON) -> Any {
        switch json {
        case .string(let str):
            return str
        case .int(let int):
            return int
        case .double(let double):
            return double
        case .bool(let bool):
            return bool
        case .array(let array):
            return array.map { convertAnyJSON($0) }
        case .object(let obj):
            return convertToDict(obj)
        case .null:
            return NSNull()
        }
    }
    
    // MARK: - Database Updates
    
    private func processRealtimeEvent(_ event: RealtimeEvent) async {
        guard let container = try? ModelContainer(for: Claim.self, Photo.self, Document.self, ActivityTimeline.self) else {
            return
        }
        
        let context = ModelContext(container)
        
        do {
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
            print("Error processing realtime event: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    func clearEvents() {
        realtimeEvents.removeAll()
    }
    
    func reconnect() {
        disconnectFromRealtime()
        connectToRealtime()
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
    case activityInserted
    
    var displayName: String {
        switch self {
        case .claimInserted: return "Claim Created"
        case .claimUpdated: return "Claim Updated"
        case .claimDeleted: return "Claim Deleted"
        case .photoInserted: return "Photo Added"
        case .photoUpdated: return "Photo Updated"
        case .photoDeleted: return "Photo Deleted"
        case .documentInserted: return "Document Added"
        case .activityInserted: return "Activity Added"
        }
    }
    
    var icon: String {
        switch self {
        case .claimInserted, .claimUpdated: return "doc.text"
        case .claimDeleted: return "trash"
        case .photoInserted, .photoUpdated: return "photo"
        case .photoDeleted: return "photo.slash"
        case .documentInserted: return "doc"
        case .activityInserted: return "clock"
        }
    }
    
    var color: UIColor {
        switch self {
        case .claimInserted, .photoInserted, .documentInserted, .activityInserted:
            return .systemGreen
        case .claimUpdated, .photoUpdated:
            return .systemBlue
        case .claimDeleted, .photoDeleted:
            return .systemRed
        }
    }
}