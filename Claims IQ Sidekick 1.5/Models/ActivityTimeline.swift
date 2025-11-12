//
//  ActivityTimeline.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import SwiftData

@Model
final class ActivityTimeline {
    @Attribute(.unique) var id: UUID
    var activityType: ActivityType
    var description: String
    var metadata: Data? // JSON encoded
    var createdAt: Date
    
    // Relationships
    var claim: Claim?
    
    init(
        activityType: ActivityType,
        description: String,
        claimId: UUID
    ) {
        self.id = UUID()
        self.activityType = activityType
        self.description = description
        self.createdAt = Date()
    }
    
    // MARK: - Metadata Helpers
    
    func setMetadata<T: Codable>(_ metadata: T) {
        if let encoded = try? JSONEncoder().encode(metadata) {
            self.metadata = encoded
        }
    }
    
    func getMetadata<T: Codable>(as type: T.Type) -> T? {
        guard let data = metadata else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Supporting Types

enum ActivityType: String, CaseIterable, Codable {
    case claimCreated = "claim_created"
    case claimUpdated = "claim_updated"
    case statusChanged = "status_changed"
    case photoAdded = "photo_added"
    case photoDeleted = "photo_deleted"
    case documentAdded = "document_added"
    case documentDeleted = "document_deleted"
    case inspectionScheduled = "inspection_scheduled"
    case inspectionStarted = "inspection_started"
    case inspectionCompleted = "inspection_completed"
    case checklistUpdated = "checklist_updated"
    case noteAdded = "note_added"
    case syncCompleted = "sync_completed"
    case syncFailed = "sync_failed"
    
    var displayName: String {
        switch self {
        case .claimCreated: return "Claim Created"
        case .claimUpdated: return "Claim Updated"
        case .statusChanged: return "Status Changed"
        case .photoAdded: return "Photo Added"
        case .photoDeleted: return "Photo Deleted"
        case .documentAdded: return "Document Added"
        case .documentDeleted: return "Document Deleted"
        case .inspectionScheduled: return "Inspection Scheduled"
        case .inspectionStarted: return "Inspection Started"
        case .inspectionCompleted: return "Inspection Completed"
        case .checklistUpdated: return "Checklist Updated"
        case .noteAdded: return "Note Added"
        case .syncCompleted: return "Sync Completed"
        case .syncFailed: return "Sync Failed"
        }
    }
    
    var icon: String {
        switch self {
        case .claimCreated: return "plus.circle.fill"
        case .claimUpdated: return "pencil.circle.fill"
        case .statusChanged: return "arrow.triangle.2.circlepath.circle.fill"
        case .photoAdded: return "camera.fill"
        case .photoDeleted: return "trash.fill"
        case .documentAdded: return "doc.badge.plus"
        case .documentDeleted: return "doc.badge.minus"
        case .inspectionScheduled: return "calendar.badge.plus"
        case .inspectionStarted: return "play.circle.fill"
        case .inspectionCompleted: return "checkmark.seal.fill"
        case .checklistUpdated: return "checklist"
        case .noteAdded: return "note.text"
        case .syncCompleted: return "arrow.triangle.2.circlepath"
        case .syncFailed: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .claimCreated, .photoAdded, .documentAdded, .inspectionScheduled:
            return "green"
        case .claimUpdated, .statusChanged, .checklistUpdated, .noteAdded:
            return "blue"
        case .inspectionStarted:
            return "orange"
        case .inspectionCompleted, .syncCompleted:
            return "green"
        case .photoDeleted, .documentDeleted, .syncFailed:
            return "red"
        }
    }
}

// MARK: - Activity Metadata Types

struct StatusChangeMetadata: Codable {
    let fromStatus: String
    let toStatus: String
}

struct PhotoActivityMetadata: Codable {
    let photoId: String
    let photoCount: Int
}

struct DocumentActivityMetadata: Codable {
    let documentId: String
    let documentType: String
    let documentTitle: String
}
