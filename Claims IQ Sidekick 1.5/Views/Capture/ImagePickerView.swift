//
//  ImagePickerView.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI
import PhotosUI

struct ImagePickerView: View {
    let claim: Claim
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isProcessing = false
    @State private var currentImageIndex = 0
    @State private var showingReview = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if selectedImages.isEmpty {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 10,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        VStack(spacing: 20) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                            
                            Text("Select Photos")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Choose up to 10 photos")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text("Tap to browse")
                                .font(.caption)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .onChange(of: selectedItems) { _, newItems in
                        Task {
                            await loadImages(from: newItems)
                        }
                    }
                } else {
                    selectedPhotosView
                }
                
                if isProcessing {
                    ProgressView("Processing photos...")
                        .padding()
                }
            }
            .navigationTitle("Select Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingReview) {
                if currentImageIndex < selectedImages.count {
                    MultiPhotoReviewView(
                        images: selectedImages,
                        claim: claim,
                        startIndex: currentImageIndex
                    )
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var selectedPhotosView: some View {
        VStack(spacing: 16) {
            Text("\(selectedImages.count) photos selected")
                .font(.headline)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .cornerRadius(8)
                            .overlay(
                                Button(action: {
                                    selectedImages.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                }
                                .padding(4),
                                alignment: .topTrailing
                            )
                    }
                }
                .padding()
            }
            
            Button(action: {
                currentImageIndex = 0
                showingReview = true
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }
        
        if !selectedImages.isEmpty {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear All") {
                    selectedImages.removeAll()
                    selectedItems.removeAll()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadImages(from items: [PhotosPickerItem]) async {
        isProcessing = true
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImages.append(image)
                }
            }
        }
        
        await MainActor.run {
            isProcessing = false
        }
    }
}

// MARK: - Multi Photo Review

struct MultiPhotoReviewView: View {
    let images: [UIImage]
    let claim: Claim
    let startIndex: Int
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var currentIndex: Int
    @State private var damageTypes: [String]
    @State private var notes: [String]
    @State private var isSaving = false
    
    init(images: [UIImage], claim: Claim, startIndex: Int) {
        self.images = images
        self.claim = claim
        self.startIndex = startIndex
        self._currentIndex = State(initialValue: startIndex)
        self._damageTypes = State(initialValue: Array(repeating: "General", count: images.count))
        self._notes = State(initialValue: Array(repeating: "", count: images.count))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Progress Indicator
                HStack {
                    ForEach(0..<images.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index == currentIndex ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                TabView(selection: $currentIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ScrollView {
                            VStack(spacing: 20) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                
                                // Quick Options
                                VStack(alignment: .leading, spacing: 16) {
                                    // Damage Type
                                    VStack(alignment: .leading) {
                                        Text("Damage Type")
                                            .font(.headline)
                                        
                                        Picker("Type", selection: $damageTypes[index]) {
                                            Text("General").tag("General")
                                            Text("Roof").tag("Roof")
                                            Text("Siding").tag("Siding")
                                            Text("Windows").tag("Windows")
                                            Text("Interior").tag("Interior")
                                            Text("Other").tag("Other")
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                    
                                    // Notes
                                    VStack(alignment: .leading) {
                                        Text("Quick Note")
                                            .font(.headline)
                                        
                                        TextField("Optional note...", text: $notes[index])
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Action Buttons
                HStack(spacing: 16) {
                    if currentIndex > 0 {
                        Button("Previous") {
                            withAnimation {
                                currentIndex -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentIndex < images.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentIndex += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Save All") {
                            Task {
                                await saveAllPhotos()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving)
                    }
                }
                .padding()
            }
            .navigationTitle("Review Photos (\(currentIndex + 1)/\(images.count))")
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
    
    private func saveAllPhotos() async {
        isSaving = true
        
        // Save each photo
        for (index, image) in images.enumerated() {
            // Create metadata
            let metadata = PhotoMetadata(
                captureDate: Date(),
                location: LocationManager.shared.createLocationMetadata(),
                deviceInfo: DeviceInfo(
                    model: UIDevice.current.model,
                    osVersion: UIDevice.current.systemVersion,
                    appVersion: "1.0"
                ),
                weather: nil,
                cameraSettings: nil
            )
            
            // Save photo (reuse logic from PhotoReviewView)
            // ... photo saving logic ...
        }
        
        await MainActor.run {
            dismiss()
        }
    }
}

#Preview {
    ImagePickerView(
        claim: Claim(
            claimNumber: "CLM-2024-001",
            insuredName: "John Doe",
            address: "123 Main St"
        )
    )
}
