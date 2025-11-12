//
//  HomeView.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var realtimeManager: RealtimeManager
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Claim.updatedAt, order: .reverse) private var claims: [Claim]
    @Query(filter: #Predicate<Photo> { $0.createdAt > Calendar.current.startOfDay(for: Date()) })
    private var todaysPhotos: [Photo]
    @Query(filter: #Predicate<SyncQueue> { $0.status == .pending || $0.status == .failed })
    private var pendingSyncs: [SyncQueue]
    
    @State private var showingNewClaim = false
    @State private var showingCamera = false
    @State private var showingDocumentPicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Section
                    welcomeSection
                    
                    // Sync Status Banner
                    if pendingSyncs.count > 0 {
                        syncStatusBanner
                    }
                    
                    // Quick Stats
                    quickStatsGrid
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Recent Activity
                    recentActivitySection
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("ClaimsIQ Sidekick")
            .toolbar {
                toolbarContent
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .sheet(isPresented: $showingNewClaim) {
                NewClaimView()
            }
            .sheet(isPresented: $showingCamera) {
                CaptureView()
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .claimInserted)) { _ in
                // Refresh data when new claim is inserted
                Task {
                    await viewModel.refreshData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .claimUpdated)) { _ in
                // Refresh data when claim is updated
                Task {
                    await viewModel.refreshData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .photoInserted)) { _ in
                // Photos are automatically updated via @Query
            }
            .onReceive(NotificationCenter.default.publisher(for: .activityInserted)) { _ in
                // Activities are automatically updated via @Query
                // Could add a visual indicator here
            }
        }
    }
    
    // MARK: - View Components
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome Back, \(supabaseManager.currentUser?.userMetadata["full_name"]?.stringValue ?? "Adjuster")")
                .font(.title)
                .fontWeight(.bold)
            
            HStack {
                Text(Date(), style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let weather = viewModel.currentWeather {
                    Text("• \(weather)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
    
    private var syncStatusBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(pendingSyncs.count) items pending sync")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Will sync when connection available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Sync Now") {
                Task {
                    await viewModel.syncPendingItems()
                }
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Active Claims",
                value: "\(claims.filter { $0.status == .active }.count)",
                icon: "doc.text.fill",
                color: .blue
            )
            
            StatCard(
                title: "Photos Today",
                value: "\(todaysPhotos.count)",
                icon: "camera.fill",
                color: .green
            )
            
            StatCard(
                title: "Pending Sync",
                value: "\(pendingSyncs.count)",
                icon: "arrow.triangle.2.circlepath",
                color: .orange
            )
            
            StatCard(
                title: "Completion Rate",
                value: viewModel.completionRate,
                icon: "chart.pie.fill",
                color: .purple
            )
        }
        .padding(.horizontal)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                QuickActionButton(
                    title: "New Claim",
                    icon: "plus.circle.fill",
                    color: .blue,
                    action: { showingNewClaim = true }
                )
                
                QuickActionButton(
                    title: "Take Photo",
                    icon: "camera.fill",
                    color: .green,
                    action: { showingCamera = true }
                )
                
                QuickActionButton(
                    title: "Upload",
                    icon: "arrow.up.doc.fill",
                    color: .orange,
                    action: { showingDocumentPicker = true }
                )
                
                QuickActionButton(
                    title: "Schedule",
                    icon: "calendar.badge.plus",
                    color: .purple,
                    action: viewModel.openSchedule
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.horizontal)
            
            if viewModel.recentActivities.isEmpty {
                Text("No recent activity")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.recentActivities.prefix(5)) { activity in
                    ActivityRow(activity: activity)
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            RealtimeIndicator()
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {}) {
                Image(systemName: "bell.badge")
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button(action: viewModel.openSettings) {
                    Label("Settings", systemImage: "gear")
                }
                
                Button(action: viewModel.openProfile) {
                    Label("Profile", systemImage: "person.circle")
                }
                
                Divider()
                
                Button(action: {
                    Task {
                        try? await supabaseManager.signOut()
                    }
                }) {
                    Label("Sign Out", systemImage: "arrow.right.square")
                }
            } label: {
                Image(systemName: "person.circle")
            }
        }
    }
}

// MARK: - View Model

class HomeViewModel: ObservableObject {
    @Published var currentWeather: String?
    @Published var completionRate: String = "0%"
    @Published var recentActivities: [ActivityTimeline] = []
    
    init() {
        Task {
            await loadWeather()
        }
    }
    
    @MainActor
    func refreshData() async {
        await loadWeather()
        calculateCompletionRate()
        // Sync with Supabase
        do {
            try await SupabaseManager.shared.checkSession()
        } catch {
            print("Failed to refresh session: \(error)")
        }
    }
    
    @MainActor
    func syncPendingItems() async {
        // Implement sync logic
        print("Syncing pending items...")
    }
    
    private func loadWeather() async {
        // Simulate weather loading
        await MainActor.run {
            self.currentWeather = "72°F, Partly Cloudy"
        }
    }
    
    private func calculateCompletionRate() {
        // Calculate based on claims
        completionRate = "85%"
    }
    
    func openSchedule() {
        // Navigate to schedule
    }
    
    func openSettings() {
        // Navigate to settings
    }
    
    func openProfile() {
        // Navigate to profile
    }
}

// MARK: - Supporting Views

struct ActivityRow: View {
    let activity: ActivityTimeline
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.activityType.icon)
                .foregroundColor(Color(activity.activityType.color))
                .frame(width: 40, height: 40)
                .background(Color(activity.activityType.color).opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.activityDescription)
                    .font(.subheadline)
                
                Text(activity.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - Placeholder Views

struct NewClaimView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("New Claim Creation")
                .navigationTitle("New Claim")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

struct DocumentPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Text("Document Picker")
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

#Preview {
    HomeView()
        .environmentObject(SupabaseManager.shared)
        .environmentObject(LocationManager.shared)
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
