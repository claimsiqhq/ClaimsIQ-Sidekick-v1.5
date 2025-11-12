//
//  Photo.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation
import SwiftData
import UIKit

@Model
final class Photo {
    @Attribute(.unique) var id: UUID
    var storagePath: String
    var thumbnailPath: String?
    var localPath: String?
    var fileSize: Int?
    var width: Int?
    var height: Int?
    var mimeType: String
    var damageType: String?
    var damageSeverity: DamageSeverity?
    var aiDetections: Data? // JSON encoded
    var annotations: Data? // JSON encoded
    var metadata: Data? // JSON encoded
    var isSynced: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var claim: Claim?
    
    // Transient properties (not persisted)
    @Transient var image: UIImage?
    @Transient var thumbnail: UIImage?
    
    init(
        claimId: UUID,
        storagePath: String,
        mimeType: String = "image/jpeg"
    ) {
        self.id = UUID()
        self.storagePath = storagePath
        self.mimeType = mimeType
        self.isSynced = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    
    var hasAnnotations: Bool {
        annotations != nil && annotations!.count > 0
    }
    
    var hasAIDetections: Bool {
        aiDetections != nil && aiDetections!.count > 0
    }
    
    // MARK: - Metadata Helpers
    
    func setMetadata(_ metadata: PhotoMetadata) {
        if let encoded = try? JSONEncoder().encode(metadata) {
            self.metadata = encoded
        }
    }
    
    func getMetadata() -> PhotoMetadata? {
        guard let data = metadata else { return nil }
        return try? JSONDecoder().decode(PhotoMetadata.self, from: data)
    }
    
    func setAnnotations(_ annotations: [PhotoAnnotation]) {
        if let encoded = try? JSONEncoder().encode(annotations) {
            self.annotations = encoded
        }
    }
    
    func getAnnotations() -> [PhotoAnnotation]? {
        guard let data = annotations else { return nil }
        return try? JSONDecoder().decode([PhotoAnnotation].self, from: data)
    }
    
    func setAIDetections(_ detections: [AIDetection]) {
        if let encoded = try? JSONEncoder().encode(detections) {
            self.aiDetections = encoded
        }
    }
    
    func getAIDetections() -> [AIDetection]? {
        guard let data = aiDetections else { return nil }
        return try? JSONDecoder().decode([AIDetection].self, from: data)
    }
}

// MARK: - Supporting Types

enum DamageSeverity: String, CaseIterable, Codable {
    case minor
    case moderate
    case severe
    
    var displayName: String {
        switch self {
        case .minor: return "Minor"
        case .moderate: return "Moderate"
        case .severe: return "Severe"
        }
    }
    
    var color: String {
        switch self {
        case .minor: return "yellow"
        case .moderate: return "orange"
        case .severe: return "red"
        }
    }
}

struct PhotoMetadata: Codable {
    let captureDate: Date
    let location: LocationMetadata?
    let deviceInfo: DeviceInfo
    let weather: WeatherInfo?
    let cameraSettings: CameraSettings?
}

struct DeviceInfo: Codable {
    let model: String
    let osVersion: String
    let appVersion: String
}

struct CameraSettings: Codable {
    let flashUsed: Bool
    let zoomLevel: Double
    let orientation: String
}

struct WeatherInfo: Codable {
    let temperature: Double?
    let conditions: String?
    let windSpeed: Double?
    let humidity: Double?
}

struct PhotoAnnotation: Codable, Identifiable {
    let id: UUID
    let type: AnnotationType
    let points: [CGPoint]
    let text: String?
    let color: String
    let createdAt: Date
    
    enum AnnotationType: String, Codable {
        case rectangle
        case arrow
        case text
        case measurement
    }
}

struct AIDetection: Codable, Identifiable {
    let id: UUID
    let damageType: String
    let confidence: Double
    let boundingBox: BoundingBox
    let severity: String?
    let suggestions: [String]?
    
    struct BoundingBox: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }
}
