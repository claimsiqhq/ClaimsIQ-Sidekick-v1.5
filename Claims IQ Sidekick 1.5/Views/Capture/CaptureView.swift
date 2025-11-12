//
//  CaptureView.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI
import PhotosUI
import AVFoundation

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedClaim: Claim?
    @State private var showingClaimPicker = false
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var showingPermissionAlert = false
    @State private var permissionMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Claim Selection
                claimSelectionSection
                
                // Capture Options
                if selectedClaim != nil {
                    captureOptionsSection
                } else {
                    emptyStateView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if selectedClaim != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Change Claim") {
                            showingClaimPicker = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingClaimPicker) {
                ClaimPickerView(selectedClaim: $selectedClaim)
            }
            .fullScreenCover(isPresented: $showingCamera) {
                if let claim = selectedClaim {
                    CameraView(claim: claim)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                if let claim = selectedClaim {
                    ImagePickerView(claim: claim)
                }
            }
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings", action: openSettings)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(permissionMessage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var claimSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Claim")
                .font(.headline)
            
            if let claim = selectedClaim {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(claim.claimNumber)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(claim.insuredName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            } else {
                Button(action: { showingClaimPicker = true }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Select a Claim")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var captureOptionsSection: some View {
        VStack(spacing: 16) {
            // Take Photo
            CaptureOptionCard(
                icon: "camera.fill",
                title: "Take Photo",
                subtitle: "Use camera to capture new evidence",
                color: .blue,
                action: checkCameraPermissionAndCapture
            )
            
            // Upload from Library
            CaptureOptionCard(
                icon: "photo.on.rectangle",
                title: "Choose from Library",
                subtitle: "Select existing photos",
                color: .green,
                action: checkPhotoLibraryPermissionAndPick
            )
            
            // Quick Capture Mode
            CaptureOptionCard(
                icon: "bolt.circle.fill",
                title: "Quick Capture",
                subtitle: "Rapid photo mode for multiple shots",
                color: .orange,
                action: {
                    // Implement quick capture
                    print("Quick capture mode")
                }
            )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.on.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Select a claim to start capturing")
                .font(.headline)
            
            Text("Choose a claim first, then you can take photos or upload documents")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Permission Handling
    
    private func checkCameraPermissionAndCapture() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    }
                }
            }
        case .denied, .restricted:
            permissionMessage = "Camera access is required to take photos. Please enable it in Settings."
            showingPermissionAlert = true
        @unknown default:
            break
        }
    }
    
    private func checkPhotoLibraryPermissionAndPick() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            showingImagePicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        showingImagePicker = true
                    }
                }
            }
        case .denied, .restricted:
            permissionMessage = "Photo library access is required to select photos. Please enable it in Settings."
            showingPermissionAlert = true
        @unknown default:
            break
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct CaptureOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Claim Picker

struct ClaimPickerView: View {
    @Binding var selectedClaim: Claim?
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Claim> { $0.status == .active },
           sort: \Claim.createdAt,
           order: .reverse) private var activeClaims: [Claim]
    
    var body: some View {
        NavigationStack {
            List(activeClaims) { claim in
                Button(action: {
                    selectedClaim = claim
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(claim.claimNumber)
                                .font(.headline)
                            
                            Text(claim.insuredName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Image(systemName: "location")
                                    .font(.caption)
                                Text(claim.address)
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedClaim?.id == claim.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Claim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CaptureView()
        .modelContainer(for: [
            Claim.self,
            Photo.self,
            Document.self,
            Inspection.self,
            ActivityTimeline.self,
            InspectionChecklist.self,
            SyncQueue.self
        ])
}
