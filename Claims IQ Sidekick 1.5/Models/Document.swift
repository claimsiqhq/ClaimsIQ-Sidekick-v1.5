//
//  Document.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import SwiftData

@Model
final class Document {
    @Attribute(.unique) var id: UUID
    var documentType: DocumentType
    var title: String
    var storagePath: String
    var localPath: String?
    var fileSize: Int?
    var mimeType: String
    var extractedData: Data? // JSON encoded
    var isSynced: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var claim: Claim?
    
    init(
        documentType: DocumentType,
        title: String,
        storagePath: String,
        mimeType: String = "application/pdf"
    ) {
        self.id = UUID()
        self.documentType = documentType
        self.title = title
        self.storagePath = storagePath
        self.mimeType = mimeType
        self.isSynced = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    
    var fileSizeFormatted: String {
        guard let size = fileSize else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    var fileExtension: String {
        switch mimeType {
        case "application/pdf": return "PDF"
        case "image/jpeg", "image/jpg": return "JPEG"
        case "image/png": return "PNG"
        default: return "Document"
        }
    }
    
    // MARK: - Extracted Data Helpers
    
    func setExtractedData(_ data: ExtractedDocumentData) {
        if let encoded = try? JSONEncoder().encode(data) {
            self.extractedData = encoded
        }
    }
    
    func getExtractedData() -> ExtractedDocumentData? {
        guard let data = extractedData else { return nil }
        return try? JSONDecoder().decode(ExtractedDocumentData.self, from: data)
    }
}

// MARK: - Supporting Types

enum DocumentType: String, CaseIterable, Codable {
    case fnol = "fnol"
    case policy = "policy"
    case estimate = "estimate"
    case report = "report"
    case invoice = "invoice"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .fnol: return "FNOL"
        case .policy: return "Policy"
        case .estimate: return "Estimate"
        case .report: return "Report"
        case .invoice: return "Invoice"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .fnol: return "doc.text.fill"
        case .policy: return "doc.fill"
        case .estimate: return "dollarsign.square.fill"
        case .report: return "doc.richtext.fill"
        case .invoice: return "receipt.fill"
        case .other: return "folder.fill"
        }
    }
}

struct ExtractedDocumentData: Codable {
    // Common fields
    var documentDate: Date?
    var extractedText: String?
    
    // FNOL specific
    var fnolData: FNOLData?
    
    // Policy specific
    var policyData: PolicyData?
    
    // Estimate specific
    var estimateData: EstimateData?
}

struct FNOLData: Codable {
    var claimNumber: String?
    var lossDate: Date?
    var reportedDate: Date?
    var causeOfLoss: String?
    var damageDescription: String?
    var contactInfo: ContactInfo?
}

struct PolicyData: Codable {
    var policyNumber: String?
    var effectiveDate: Date?
    var expirationDate: Date?
    var coverages: [String: Double]?
    var deductibles: [String: Double]?
}

struct EstimateData: Codable {
    var estimateNumber: String?
    var totalAmount: Double?
    var lineItems: [EstimateLineItem]?
}

struct EstimateLineItem: Codable, Identifiable {
    var id: UUID = UUID()
    var description: String
    var quantity: Double
    var unitPrice: Double
    var total: Double
}

struct ContactInfo: Codable {
    var name: String?
    var phone: String?
    var email: String?
    var address: String?
}
