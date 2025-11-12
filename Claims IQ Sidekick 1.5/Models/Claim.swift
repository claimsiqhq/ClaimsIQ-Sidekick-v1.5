//
//  Claim.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import SwiftData

@Model
final class Claim {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var claimNumber: String
    var policyNumber: String?
    var insuredName: String
    var insuredPhone: String?
    var insuredEmail: String?
    var address: String
    var city: String?
    var state: String?
    var zipCode: String?
    var latitude: Double?
    var longitude: Double?
    var lossDate: Date?
    var lossDescription: String?
    var status: ClaimStatus
    var priority: ClaimPriority
    var coverageType: String?
    var deductible: Double?
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus
    var lastSyncedAt: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade) var photos: [Photo]?
    @Relationship(deleteRule: .cascade) var documents: [Document]?
    @Relationship(deleteRule: .cascade) var inspections: [Inspection]?
    @Relationship(deleteRule: .cascade) var activities: [ActivityTimeline]?
    @Relationship(deleteRule: .cascade) var checklistItems: [InspectionChecklist]?
    
    init(
        claimNumber: String,
        insuredName: String,
        address: String,
        status: ClaimStatus = .active,
        priority: ClaimPriority = .normal
    ) {
        self.id = UUID()
        self.claimNumber = claimNumber
        self.insuredName = insuredName
        self.address = address
        self.status = status
        self.priority = priority
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncStatus = .pending
        self.photos = []
        self.documents = []
        self.inspections = []
        self.activities = []
        self.checklistItems = []
    }
    
    // MARK: - Computed Properties
    
    var photoCount: Int {
        photos?.count ?? 0
    }
    
    var completionPercentage: Double {
        guard let checklist = checklistItems else { return 0 }
        let requiredItems = checklist.filter { $0.required }
        guard !requiredItems.isEmpty else { return 100 }
        
        let completedCount = requiredItems.filter { $0.status == .completed }.count
        return (Double(completedCount) / Double(requiredItems.count)) * 100
    }
    
    var hasUnsyncedChanges: Bool {
        syncStatus != .synced || lastSyncedAt == nil || updatedAt > (lastSyncedAt ?? Date.distantPast)
    }
    
    // MARK: - DTO Conversion
    
    init(from dto: ClaimDTO) {
        self.id = UUID(uuidString: dto.id) ?? UUID()
        self.claimNumber = dto.claim_number
        self.policyNumber = dto.policy_number
        self.insuredName = dto.insured_name
        self.insuredPhone = dto.insured_phone
        self.insuredEmail = dto.insured_email
        self.address = dto.address
        self.city = dto.city
        self.state = dto.state
        self.zipCode = dto.zip_code
        self.latitude = dto.latitude
        self.longitude = dto.longitude
        
        if let lossDateString = dto.loss_date {
            self.lossDate = ISO8601DateFormatter().date(from: lossDateString)
        }
        
        self.lossDescription = dto.loss_description
        self.status = ClaimStatus(rawValue: dto.status) ?? .active
        self.priority = ClaimPriority(rawValue: dto.priority) ?? .normal
        self.coverageType = dto.coverage_type
        self.deductible = dto.deductible
        
        self.createdAt = ISO8601DateFormatter().date(from: dto.created_at) ?? Date()
        self.updatedAt = ISO8601DateFormatter().date(from: dto.updated_at) ?? Date()
        self.syncStatus = .synced
        self.lastSyncedAt = Date()
    }
    
    func toDTO() -> ClaimDTO {
        let formatter = ISO8601DateFormatter()
        
        return ClaimDTO(
            id: id.uuidString,
            claim_number: claimNumber,
            policy_number: policyNumber,
            insured_name: insuredName,
            insured_phone: insuredPhone,
            insured_email: insuredEmail,
            address: address,
            city: city,
            state: state,
            zip_code: zipCode,
            latitude: latitude,
            longitude: longitude,
            loss_date: lossDate != nil ? formatter.string(from: lossDate!) : nil,
            loss_description: lossDescription,
            status: status.rawValue,
            priority: priority.rawValue,
            coverage_type: coverageType,
            deductible: deductible,
            user_id: SupabaseManager.shared.currentUser?.id.uuidString ?? "",
            created_at: formatter.string(from: createdAt),
            updated_at: formatter.string(from: updatedAt)
        )
    }
}

// MARK: - Enums

enum ClaimStatus: String, CaseIterable, Codable {
    case active
    case completed
    case draft
    case cancelled
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        case .draft: return "Draft"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "blue"
        case .completed: return "green"
        case .draft: return "gray"
        case .cancelled: return "red"
        }
    }
}

enum ClaimPriority: String, CaseIterable, Codable {
    case urgent
    case high
    case normal
    case low
    
    var displayName: String {
        switch self {
        case .urgent: return "Urgent"
        case .high: return "High"
        case .normal: return "Normal"
        case .low: return "Low"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .normal: return 2
        case .low: return 3
        }
    }
}

enum SyncStatus: String, CaseIterable, Codable {
    case pending
    case syncing
    case synced
    case failed
}
