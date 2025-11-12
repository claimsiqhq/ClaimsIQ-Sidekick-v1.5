//
//  ClaimsListView.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI
import SwiftData

struct ClaimsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var supabaseManager: SupabaseManager
    
    @Query private var claims: [Claim]
    @State private var searchText = ""
    @State private var selectedStatus: ClaimStatus?
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var showingNewClaim = false
    @State private var selectedClaim: Claim?
    
    private var filteredClaims: [Claim] {
        let filtered = claims.filter { claim in
            let matchesSearch = searchText.isEmpty ||
                claim.claimNumber.localizedCaseInsensitiveContains(searchText) ||
                claim.insuredName.localizedCaseInsensitiveContains(searchText) ||
                claim.address.localizedCaseInsensitiveContains(searchText)
            
            let matchesStatus = selectedStatus == nil || claim.status == selectedStatus
            
            return matchesSearch && matchesStatus
        }
        
        return filtered.sorted { first, second in
            switch sortOrder {
            case .dateDescending:
                return first.createdAt > second.createdAt
            case .dateAscending:
                return first.createdAt < second.createdAt
            case .claimNumber:
                return first.claimNumber < second.claimNumber
            case .priority:
                return first.priority.sortOrder < second.priority.sortOrder
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters
                filterSection
                
                // Claims List
                if filteredClaims.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredClaims) { claim in
                            ClaimRowView(claim: claim)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedClaim = claim
                                }
                        }
                        .onDelete(perform: deleteClaims)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Claims")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search claims...")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingNewClaim) {
                NewClaimView()
            }
            .navigationDestination(item: $selectedClaim) { claim in
                ClaimDetailView(claim: claim)
            }
            .refreshable {
                await refreshClaims()
            }
        }
    }
    
    // MARK: - View Components
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Status Filter
                Menu {
                    Button("All Statuses", action: { selectedStatus = nil })
                    Divider()
                    ForEach(ClaimStatus.allCases, id: \.self) { status in
                        Button(action: { selectedStatus = status }) {
                            Label(status.displayName, systemImage: selectedStatus == status ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label(
                        selectedStatus?.displayName ?? "All Statuses",
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                // Sort Order
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(action: { sortOrder = order }) {
                            Label(order.displayName, systemImage: sortOrder == order ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label(sortOrder.displayName, systemImage: "arrow.up.arrow.down")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(searchText.isEmpty && selectedStatus == nil ? "No claims yet" : "No matching claims")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(searchText.isEmpty && selectedStatus == nil ? "Create your first claim to get started" : "Try adjusting your filters")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty && selectedStatus == nil {
                Button("Create New Claim") {
                    showingNewClaim = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .padding()
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingNewClaim = true }) {
                Image(systemName: "plus")
            }
        }
    }
    
    // MARK: - Actions
    
    private func deleteClaims(at offsets: IndexSet) {
        for index in offsets {
            let claim = filteredClaims[index]
            modelContext.delete(claim)
            
            // Add to sync queue for deletion
            if let data = try? JSONEncoder().encode(["id": claim.id.uuidString]) {
                let syncItem = SyncQueue(
                    operationType: .delete,
                    tableName: "claims",
                    recordId: claim.id,
                    data: data
                )
                modelContext.insert(syncItem)
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete claims: \(error)")
        }
    }
    
    private func refreshClaims() async {
        do {
            let fetchedClaims = try await supabaseManager.fetchClaims()
            
            // Update or insert claims
            for fetchedClaim in fetchedClaims {
                // Check if claim already exists
                let fetchedId = fetchedClaim.id
                let descriptor = FetchDescriptor<Claim>()
                let allClaims = try? modelContext.fetch(descriptor) ?? []
                
                if let existingClaim = allClaims.first(where: { $0.id == fetchedId }) {
                    // Update existing claim
                    existingClaim.syncStatus = .synced
                    existingClaim.lastSyncedAt = Date()
                } else {
                    // Insert new claim
                    modelContext.insert(fetchedClaim)
                }
            }
            
            try? modelContext.save()
        } catch {
            print("Failed to refresh claims: \(error)")
        }
    }
}

// MARK: - Supporting Types

enum SortOrder: String, CaseIterable {
    case dateDescending = "date_desc"
    case dateAscending = "date_asc"
    case claimNumber = "claim_number"
    case priority = "priority"
    
    var displayName: String {
        switch self {
        case .dateDescending: return "Newest First"
        case .dateAscending: return "Oldest First"
        case .claimNumber: return "Claim Number"
        case .priority: return "Priority"
        }
    }
}

// MARK: - Claim Row View

struct ClaimRowView: View {
    let claim: Claim
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(claim.claimNumber)
                        .font(.headline)
                    
                    Text(claim.insuredName)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Priority Badge
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
                
                // Status Badge
                StatusBadge(status: claim.status)
            }
            
            // Address
            HStack {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(claim.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            // Footer
            HStack {
                if let lossDate = claim.lossDate {
                    Label("Loss: \(lossDate, style: .date)", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Photo Count
                if claim.photoCount > 0 {
                    Label("\(claim.photoCount)", systemImage: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Sync Status
                if claim.hasUnsyncedChanges {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var priorityColor: Color {
        switch claim.priority {
        case .urgent: return .red
        case .high: return .orange
        case .normal: return .blue
        case .low: return .gray
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ClaimStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(status.color).opacity(0.2))
            .foregroundColor(Color(status.color))
            .cornerRadius(4)
    }
}

#Preview {
    ClaimsListView()
        .environmentObject(SupabaseManager.shared)
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
