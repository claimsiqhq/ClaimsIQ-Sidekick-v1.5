//
//  Inspection.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import SwiftData

@Model
final class Inspection {
    @Attribute(.unique) var id: UUID
    var scheduledDate: Date?
    var scheduledTime: Date?
    var arrivalTime: Date?
    var completionTime: Date?
    var status: InspectionStatus
    var notes: String?
    var weatherConditions: Data? // JSON encoded
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus
    
    // Relationships
    var claim: Claim?
    
    init(claimId: UUID) {
        self.id = UUID()
        self.status = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncStatus = .pending
    }
    
    // MARK: - Computed Properties
    
    var isScheduled: Bool {
        scheduledDate != nil
    }
    
    var isOverdue: Bool {
        guard let scheduled = scheduledDate else { return false }
        return scheduled < Date() && status == .pending
    }
    
    var duration: TimeInterval? {
        guard let arrival = arrivalTime,
              let completion = completionTime else { return nil }
        return completion.timeIntervalSince(arrival)
    }
    
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Weather Helpers
    
    func setWeatherConditions(_ weather: WeatherConditions) {
        if let encoded = try? JSONEncoder().encode(weather) {
            self.weatherConditions = encoded
        }
    }
    
    func getWeatherConditions() -> WeatherConditions? {
        guard let data = weatherConditions else { return nil }
        return try? JSONDecoder().decode(WeatherConditions.self, from: data)
    }
}

// MARK: - Supporting Types

enum InspectionStatus: String, CaseIterable, Codable {
    case pending
    case inProgress = "in_progress"
    case completed
    case cancelled
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .inProgress: return "blue"
        case .completed: return "green"
        case .cancelled: return "gray"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .inProgress: return "arrow.clockwise.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

struct WeatherConditions: Codable {
    let temperature: Double
    let temperatureUnit: String
    let conditions: String
    let windSpeed: Double?
    let windDirection: String?
    let humidity: Double?
    let visibility: Double?
    let precipitation: Bool
    let recordedAt: Date
}
