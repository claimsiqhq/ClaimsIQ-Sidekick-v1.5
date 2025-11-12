//
//  PhotoReviewView.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI
import SwiftData

struct PhotoReviewView: View {
    let image: UIImage
    let claim: Claim
    let damageType: String
    let metadata: PhotoMetadata
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var supabaseManager: SupabaseManager
    
    @State private var notes = ""
    @State private var severity: DamageSeverity?
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingAnnotationView = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image Preview
                    imagePreview
                    
                    // Photo Details
                    photoDetailsSection
                    
                    // Damage Assessment
                    damageAssessmentSection
                    
                    // Notes
                    notesSection
                    
                    // Location Info
                    if let location = metadata.location {
                        locationSection(location)
                    }
                }
                .padding()
            }
            .navigationTitle("Review Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .disabled(isSaving)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingAnnotationView) {
                PhotoAnnotationView(image: image)
            }
        }
    }
    
    // MARK: - View Components
    
    private var imagePreview: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 400)
            .cornerRadius(10)
            .shadow(radius: 5)
            .onTapGesture {
                showingAnnotationView = true
            }
            .overlay(
                Text("Tap to annotate")
                    .font(.caption)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(8),
                alignment: .topTrailing
            )
    }
    
    private var photoDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo Details")
                .font(.headline)
            
            VStack(spacing: 8) {
                DetailRow(label: "Claim", value: "\(claim.claimNumber) - \(claim.insuredName)")
                DetailRow(label: "Type", value: damageType)
                DetailRow(label: "Date", value: metadata.captureDate.formatted())
                DetailRow(label: "Size", value: formatFileSize(image.jpegData(compressionQuality: 0.8)?.count ?? 0))
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    private var damageAssessmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Damage Assessment")
                .font(.headline)
            
            // Severity Picker
            Picker("Severity", selection: $severity) {
                Text("Not Set").tag(nil as DamageSeverity?)
                ForEach(DamageSeverity.allCases, id: \.self) { severity in
                    Text(severity.displayName).tag(severity as DamageSeverity?)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
            
            TextField("Add notes about this photo...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private func locationSection(_ location: LocationMetadata) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let lat = location.latitude, let lon = location.longitude {
                    DetailRow(label: "Coordinates", value: String(format: "%.6f, %.6f", lat, lon))
                }
                
                if let address = location.address {
                    DetailRow(label: "Address", value: address)
                }
                
                if let accuracy = location.horizontalAccuracy {
                    DetailRow(label: "Accuracy", value: String(format: "±%.1f meters", accuracy))
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Retake") {
                dismiss()
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                Task {
                    await savePhoto()
                }
            }
            .disabled(isSaving)
        }
    }
    
    // MARK: - Actions
    
    private func savePhoto() async {
        isSaving = true
        
        do {
            // Generate filename
            let timestamp = Date().timeIntervalSince1970
            let fileName = "photo_\(claim.claimNumber)_\(Int(timestamp)).jpg"
            
            // Compress image
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw PhotoError.compressionFailed
            }
            
            // Save locally first
            let localPath = try await savePhotoLocally(imageData: imageData, fileName: fileName)
            
            // Create photo record
            let photo = Photo(
                claimId: claim.id,
                storagePath: fileName, // Will be updated with Supabase path
                mimeType: "image/jpeg"
            )
            
            photo.localPath = localPath
            photo.fileSize = imageData.count
            photo.width = Int(image.size.width)
            photo.height = Int(image.size.height)
            photo.damageType = damageType
            photo.damageSeverity = severity
            photo.setMetadata(metadata)
            photo.claim = claim
            
            if !notes.isEmpty {
                let annotation = PhotoAnnotation(
                    id: UUID(),
                    type: .text,
                    points: [],
                    text: notes,
                    color: "blue",
                    createdAt: Date()
                )
                photo.setAnnotations([annotation])
            }
            
            // Insert into database
            modelContext.insert(photo)
            
            // Create activity
            let activity = ActivityTimeline(
                activityType: .photoAdded,
                description: "Added photo: \(damageType)",
                claimId: claim.id
            )
            activity.claim = claim
            
            let photoMetadata = PhotoActivityMetadata(
                photoId: photo.id.uuidString,
                photoCount: claim.photoCount + 1
            )
            activity.setMetadata(photoMetadata)
            modelContext.insert(activity)
            
            // Save to database
            try modelContext.save()
            
            // Add to sync queue
            if let photoData = try? JSONEncoder().encode(photo) {
                let syncItem = SyncQueue(
                    operationType: .create,
                    tableName: "photos",
                    recordId: photo.id,
                    data: photoData
                )
                modelContext.insert(syncItem)
                try modelContext.save()
            }
            
            // Try to upload to Supabase in background
            Task {
                do {
                    let storagePath = try await supabaseManager.uploadPhoto(
                        claimId: claim.id.uuidString,
                        imageData: imageData,
                        fileName: fileName
                    )
                    
                    photo.storagePath = storagePath
                    photo.isSynced = true
                    try modelContext.save()
                } catch {
                    print("Failed to upload photo: \(error)")
                    // Will retry via sync queue
                }
            }
            
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isSaving = false
            }
        }
    }
    
    private func savePhotoLocally(imageData: Data, fileName: String) async throws -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosDirectory = documentsPath.appendingPathComponent("photos")
        
        // Create photos directory if it doesn't exist
        try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        try imageData.write(to: fileURL)
        
        return fileURL.path
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Photo Annotation View (Placeholder)

struct PhotoAnnotationView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                
                Text("Annotation tools coming soon")
                    .font(.headline)
                    .padding()
            }
            .navigationTitle("Annotate Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Errors

enum PhotoError: LocalizedError {
    case compressionFailed
    case saveFailed
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress photo"
        case .saveFailed:
            return "Failed to save photo"
        case .uploadFailed:
            return "Failed to upload photo"
        }
    }
}

#Preview {
    PhotoReviewView(
        image: UIImage(systemName: "photo")!,
        claim: Claim(
            claimNumber: "CLM-2024-001",
            insuredName: "John Doe",
            address: "123 Main St"
        ),
        damageType: "Roof",
        metadata: PhotoMetadata(
            captureDate: Date(),
            location: nil,
            deviceInfo: DeviceInfo(model: "iPhone", osVersion: "17.0", appVersion: "1.0"),
            weather: nil,
            cameraSettings: nil
        )
    )
    .environmentObject(SupabaseManager.shared)
}
