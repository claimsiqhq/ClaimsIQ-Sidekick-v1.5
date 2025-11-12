//
//  InspectionChecklist.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import SwiftData

@Model
final class InspectionChecklist {
    @Attribute(.unique) var id: UUID
    var category: ChecklistCategory
    var itemName: String
    var status: ChecklistStatus
    var required: Bool
    var evidenceCount: Int
    var notes: String?
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus
    
    // Relationships
    var claim: Claim?
    
    init(
        category: ChecklistCategory,
        itemName: String,
        required: Bool = false
    ) {
        self.id = UUID()
        self.category = category
        self.itemName = itemName
        self.status = .pending
        self.required = required
        self.evidenceCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncStatus = .pending
    }
    
    // MARK: - Computed Properties
    
    var isComplete: Bool {
        status == .completed
    }
    
    var hasEvidence: Bool {
        evidenceCount > 0
    }
    
    var needsAttention: Bool {
        required && status == .pending && evidenceCount == 0
    }
    
    // MARK: - Methods
    
    func markCompleted() {
        status = .completed
        completedAt = Date()
        updatedAt = Date()
        syncStatus = .pending
    }
    
    func markPending() {
        status = .pending
        completedAt = nil
        updatedAt = Date()
        syncStatus = .pending
    }
    
    func skip() {
        status = .skipped
        updatedAt = Date()
        syncStatus = .pending
    }
    
    func markNotApplicable() {
        status = .notApplicable
        updatedAt = Date()
        syncStatus = .pending
    }
    
    func addEvidence() {
        evidenceCount += 1
        updatedAt = Date()
        syncStatus = .pending
    }
    
    func removeEvidence() {
        if evidenceCount > 0 {
            evidenceCount -= 1
            updatedAt = Date()
            syncStatus = .pending
        }
    }
}

// MARK: - Supporting Types

enum ChecklistCategory: String, CaseIterable, Codable {
    case exterior
    case interior
    case roof
    case foundation
    case electrical
    case plumbing
    case hvac
    case safety
    case other
    
    var displayName: String {
        switch self {
        case .exterior: return "Exterior"
        case .interior: return "Interior"
        case .roof: return "Roof"
        case .foundation: return "Foundation"
        case .electrical: return "Electrical"
        case .plumbing: return "Plumbing"
        case .hvac: return "HVAC"
        case .safety: return "Safety"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .exterior: return "house"
        case .interior: return "house.fill"
        case .roof: return "triangle.fill"
        case .foundation: return "square.split.bottomrightquarter"
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .hvac: return "wind"
        case .safety: return "exclamationmark.triangle.fill"
        case .other: return "folder.fill"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .exterior: return 1
        case .roof: return 2
        case .foundation: return 3
        case .interior: return 4
        case .electrical: return 5
        case .plumbing: return 6
        case .hvac: return 7
        case .safety: return 8
        case .other: return 9
        }
    }
}

enum ChecklistStatus: String, CaseIterable, Codable {
    case pending
    case completed
    case skipped
    case notApplicable = "na"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .skipped: return "Skipped"
        case .notApplicable: return "N/A"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "circle"
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "arrow.forward.circle"
        case .notApplicable: return "minus.circle"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "gray"
        case .completed: return "green"
        case .skipped: return "orange"
        case .notApplicable: return "gray"
        }
    }
}

// MARK: - Default Checklist Templates

extension ChecklistCategory {
    var defaultItems: [String] {
        switch self {
        case .exterior:
            return [
                "Front elevation photo",
                "Left side elevation photo",
                "Right side elevation photo",
                "Rear elevation photo",
                "Siding damage assessment",
                "Window damage assessment",
                "Door damage assessment",
                "Garage door condition",
                "Deck/patio condition"
            ]
        case .interior:
            return [
                "Entry/foyer condition",
                "Living room condition",
                "Kitchen condition",
                "Master bedroom condition",
                "Bathroom condition",
                "Flooring assessment",
                "Wall damage assessment",
                "Ceiling damage assessment"
            ]
        case .roof:
            return [
                "Overall roof photo",
                "Shingle damage close-up",
                "Gutter condition",
                "Downspout condition",
                "Flashing condition",
                "Chimney condition",
                "Soffit/fascia condition",
                "Ridge/hip assessment"
            ]
        case .foundation:
            return [
                "Foundation overview",
                "Crack documentation",
                "Settlement evidence",
                "Drainage assessment",
                "Basement condition"
            ]
        case .electrical:
            return [
                "Electrical panel photo",
                "Visible damage assessment",
                "Outlet functionality",
                "Light fixture condition"
            ]
        case .plumbing:
            return [
                "Water damage evidence",
                "Pipe condition",
                "Fixture functionality",
                "Water heater condition"
            ]
        case .hvac:
            return [
                "HVAC unit photo",
                "Operational status",
                "Ductwork condition",
                "Thermostat functionality"
            ]
        case .safety:
            return [
                "Smoke detector check",
                "Carbon monoxide detector",
                "Handrail condition",
                "Trip hazard assessment"
            ]
        case .other:
            return []
        }
    }
}
