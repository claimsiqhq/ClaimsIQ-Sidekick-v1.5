//
//  ClaimDetailView.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI
import SwiftData
import MapKit

struct ClaimDetailView: View {
    let claim: Claim
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var selectedTab = 0
    @State private var showingEditView = false
    @State private var showingCamera = false
    @State private var showingDocumentPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Tab Selection
            tabSelector
            
            // Tab Content
            tabContent
        }
        .navigationTitle(claim.claimNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingEditView) {
            EditClaimView(claim: claim)
        }
        .sheet(isPresented: $showingCamera) {
            PhotoCaptureView(claim: claim)
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentUploadView(claim: claim)
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status and Priority
            HStack {
                StatusBadge(status: claim.status)
                
                if claim.priority != .normal {
                    Text(claim.priority.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor.opacity(0.2))
                        .foregroundColor(priorityColor)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                if claim.hasUnsyncedChanges {
                    Label("Pending Sync", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            
            // Insured Info
            VStack(alignment: .leading, spacing: 4) {
                Text(claim.insuredName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let policyNumber = claim.policyNumber {
                    Text("Policy: \(policyNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Location
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(claim.address)
                        .font(.subheadline)
                    
                    if let city = claim.city, let state = claim.state, let zip = claim.zipCode {
                        Text("\(city), \(state) \(zip)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: openInMaps) {
                    Image(systemName: "map")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    private var tabSelector: some View {
        Picker("Tab", selection: $selectedTab) {
            Text("Overview").tag(0)
            Text("Photos").tag(1)
            Text("Workflow").tag(2)
            Text("Documents").tag(3)
            Text("Timeline").tag(4)
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            switch selectedTab {
            case 0:
                OverviewTab(claim: claim)
            case 1:
                PhotosTab(claim: claim, showingCamera: $showingCamera)
            case 2:
                WorkflowTab(claim: claim)
            case 3:
                DocumentsTab(claim: claim, showingDocumentPicker: $showingDocumentPicker)
            case 4:
                TimelineTab(claim: claim)
            default:
                EmptyView()
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button(action: { showingEditView = true }) {
                    Label("Edit Claim", systemImage: "pencil")
                }
                
                Button(action: { showingCamera = true }) {
                    Label("Take Photo", systemImage: "camera")
                }
                
                Button(action: { showingDocumentPicker = true }) {
                    Label("Upload Document", systemImage: "doc.badge.plus")
                }
                
                Divider()
                
                Button(role: .destructive, action: {}) {
                    Label("Delete Claim", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    private var priorityColor: Color {
        switch claim.priority {
        case .urgent: return .red
        case .high: return .orange
        case .normal: return .blue
        case .low: return .gray
        }
    }
    
    // MARK: - Actions
    
    private func openInMaps() {
        guard let latitude = claim.latitude,
              let longitude = claim.longitude else { return }
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = claim.address
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    let claim: Claim
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Loss Information
            SectionView(title: "Loss Information") {
                InfoRow(label: "Date of Loss", value: claim.lossDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not specified")
                InfoRow(label: "Description", value: claim.lossDescription ?? "No description provided")
            }
            
            // Contact Information
            if claim.insuredPhone != nil || claim.insuredEmail != nil {
                SectionView(title: "Contact Information") {
                    if let phone = claim.insuredPhone {
                        InfoRow(label: "Phone", value: phone, action: {
                            if let url = URL(string: "tel://\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        })
                    }
                    
                    if let email = claim.insuredEmail {
                        InfoRow(label: "Email", value: email, action: {
                            if let url = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(url)
                            }
                        })
                    }
                }
            }
            
            // Coverage Information
            if claim.coverageType != nil || claim.deductible != nil {
                SectionView(title: "Coverage") {
                    if let coverage = claim.coverageType {
                        InfoRow(label: "Type", value: coverage)
                    }
                    
                    if let deductible = claim.deductible {
                        InfoRow(label: "Deductible", value: "$\(Int(deductible))")
                    }
                }
            }
            
            // Statistics
            SectionView(title: "Statistics") {
                HStack(spacing: 20) {
                    StatisticView(value: "\(claim.photoCount)", label: "Photos")
                    StatisticView(value: "\(claim.documents?.count ?? 0)", label: "Documents")
                    StatisticView(value: "\(Int(claim.completionPercentage))%", label: "Complete")
                }
            }
        }
        .padding()
    }
}

// MARK: - Photos Tab

struct PhotosTab: View {
    let claim: Claim
    @Binding var showingCamera: Bool
    
    private let columns = [
        GridItem(.adaptive(minimum: 100))
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            if let photos = claim.photos, !photos.isEmpty {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(photos) { photo in
                        PhotoThumbnail(photo: photo)
                    }
                }
                .padding()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    
                    Text("No photos yet")
                        .font(.headline)
                    
                    Button("Take First Photo") {
                        showingCamera = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
                .padding()
            }
        }
    }
}

// MARK: - Workflow Tab

struct WorkflowTab: View {
    let claim: Claim
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let checklist = claim.checklistItems, !checklist.isEmpty {
                ForEach(ChecklistCategory.allCases, id: \.self) { category in
                    let categoryItems = checklist.filter { $0.category == category }
                    
                    if !categoryItems.isEmpty {
                        ChecklistSection(category: category, items: categoryItems)
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "checklist")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    
                    Text("No checklist items")
                        .font(.headline)
                    
                    Text("Create an inspection to generate a checklist")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
    }
}

// MARK: - Documents Tab

struct DocumentsTab: View {
    let claim: Claim
    @Binding var showingDocumentPicker: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if let documents = claim.documents, !documents.isEmpty {
                ForEach(documents) { document in
                    DocumentRow(document: document)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    
                    Text("No documents yet")
                        .font(.headline)
                    
                    Button("Upload Document") {
                        showingDocumentPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
                .padding()
            }
        }
        .padding()
    }
}

// MARK: - Timeline Tab

struct TimelineTab: View {
    let claim: Claim
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let activities = claim.activities, !activities.isEmpty {
                ForEach(activities.sorted(by: { $0.createdAt > $1.createdAt })) { activity in
                    TimelineRow(activity: activity)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    
                    Text("No activity yet")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
    }
}

// MARK: - Supporting Views

struct SectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var action: (() -> Void)?
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if let action = action {
                Button(action: action) {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            } else {
                Text(value)
                    .font(.subheadline)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

struct StatisticView: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Placeholder Views

struct EditClaimView: View {
    let claim: Claim
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Edit Claim: \(claim.claimNumber)")
                .navigationTitle("Edit Claim")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { dismiss() }
                    }
                }
        }
    }
}

struct PhotoCaptureView: View {
    let claim: Claim
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Photo Capture for: \(claim.claimNumber)")
                .navigationTitle("Capture Photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

struct DocumentUploadView: View {
    let claim: Claim
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Upload Document for: \(claim.claimNumber)")
                .navigationTitle("Upload Document")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

struct PhotoThumbnail: View {
    let photo: Photo
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.secondarySystemBackground))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            )
    }
}

struct ChecklistSection: View {
    let category: ChecklistCategory
    let items: [InspectionChecklist]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(category.displayName, systemImage: category.icon)
                .font(.headline)
            
            ForEach(items) { item in
                ChecklistItemRow(item: item)
            }
        }
    }
}

struct ChecklistItemRow: View {
    let item: InspectionChecklist
    
    var body: some View {
        HStack {
            Image(systemName: item.status.icon)
                .foregroundColor(Color(item.status.color))
            
            Text(item.itemName)
                .font(.subheadline)
            
            if item.required {
                Text("Required")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(4)
            }
            
            Spacer()
            
            if item.evidenceCount > 0 {
                Label("\(item.evidenceCount)", systemImage: "camera.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DocumentRow: View {
    let document: Document
    
    var body: some View {
        HStack {
            Image(systemName: document.documentType.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text(document.documentType.displayName)
                    Text("•")
                    Text(document.fileSizeFormatted)
                    if document.isSynced {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct TimelineRow: View {
    let activity: ActivityTimeline
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack {
                Circle()
                    .fill(Color(activity.activityType.color))
                    .frame(width: 10, height: 10)
                
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: activity.activityType.icon)
                        .foregroundColor(Color(activity.activityType.color))
                    
                    Text(activity.activityType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(activity.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(activity.activityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 16)
        }
    }
}

#Preview {
    NavigationStack {
        ClaimDetailView(
            claim: Claim(
                claimNumber: "CLM-2024-001",
                insuredName: "John Doe",
                address: "123 Main St",
                status: .active,
                priority: .high
            )
        )
        .environmentObject(SupabaseManager.shared)
    }
}
