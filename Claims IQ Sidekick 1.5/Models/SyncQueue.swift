//
//  SyncQueue.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import SwiftData

@Model
final class SyncQueue {
    @Attribute(.unique) var id: UUID
    var operationType: SyncOperationType
    var tableName: String
    var recordId: UUID?
    var data: Data // JSON encoded
    var retryCount: Int
    var maxRetries: Int
    var status: SyncQueueStatus
    var errorMessage: String?
    var deviceId: String
    var createdAt: Date
    var processedAt: Date?
    
    init(
        operationType: SyncOperationType,
        tableName: String,
        recordId: UUID? = nil,
        data: Data
    ) {
        self.id = UUID()
        self.operationType = operationType
        self.tableName = tableName
        self.recordId = recordId
        self.data = data
        self.retryCount = 0
        self.maxRetries = 3
        self.status = .pending
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        self.createdAt = Date()
    }
    
    // MARK: - Computed Properties
    
    var canRetry: Bool {
        retryCount < maxRetries && status == .failed
    }
    
    var isExpired: Bool {
        // Consider items older than 7 days as expired
        createdAt.addingTimeInterval(7 * 24 * 60 * 60) < Date()
    }
    
    // MARK: - Methods
    
    func incrementRetry() {
        retryCount += 1
        if retryCount >= maxRetries {
            status = .failed
            errorMessage = "Maximum retry attempts reached"
        }
    }
    
    func markProcessing() {
        status = .processing
    }
    
    func markCompleted() {
        status = .completed
        processedAt = Date()
    }
    
    func markFailed(error: String) {
        status = .failed
        errorMessage = error
        incrementRetry()
    }
    
    // MARK: - Data Helpers
    
    func setData<T: Codable>(_ object: T) throws {
        self.data = try JSONEncoder().encode(object)
    }
    
    func getData<T: Codable>(as type: T.Type) throws -> T {
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Supporting Types

enum SyncOperationType: String, CaseIterable, Codable {
    case create
    case update
    case delete
    
    var displayName: String {
        switch self {
        case .create: return "Create"
        case .update: return "Update"
        case .delete: return "Delete"
        }
    }
}

enum SyncQueueStatus: String, CaseIterable, Codable {
    case pending
    case processing
    case completed
    case failed
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .processing: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
}
