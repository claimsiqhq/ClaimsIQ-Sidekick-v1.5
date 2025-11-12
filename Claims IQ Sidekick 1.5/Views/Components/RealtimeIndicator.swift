//
//  RealtimeIndicator.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI

struct RealtimeIndicator: View {
    @EnvironmentObject var realtimeManager: RealtimeManager
    @EnvironmentObject var syncManager: SyncManager
    @State private var showingDetails = false
    
    var body: some View {
        HStack(spacing: 4) {
            // Connection Status
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 4)
                        .scaleEffect(realtimeManager.isConnected ? 1.5 : 1.0)
                        .opacity(realtimeManager.isConnected ? 0 : 1)
                        .animation(
                            realtimeManager.isConnected ?
                                Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false) :
                                .default,
                            value: realtimeManager.isConnected
                        )
                )
            
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Pending Sync Count
            if syncManager.pendingSyncCount > 0 {
                Text("(\(syncManager.pendingSyncCount))")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            RealtimeDetailsView()
        }
    }
    
    private var statusColor: Color {
        if !syncManager.isOnline {
            return .gray
        } else if realtimeManager.isConnected {
            return .green
        } else {
            return .orange
        }
    }
    
    private var statusText: String {
        if !syncManager.isOnline {
            return "Offline"
        } else if realtimeManager.isConnected {
            return "Live"
        } else {
            return "Connecting..."
        }
    }
}

// MARK: - Realtime Details View

struct RealtimeDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var realtimeManager: RealtimeManager
    @EnvironmentObject var syncManager: SyncManager
    
    var body: some View {
        NavigationStack {
            List {
                // Connection Status
                Section("Connection Status") {
                    HStack {
                        Label("Network", systemImage: "wifi")
                        Spacer()
                        Text(syncManager.isOnline ? "Online" : "Offline")
                            .foregroundStyle(syncManager.isOnline ? .green : .gray)
                    }
                    
                    HStack {
                        Label("Realtime", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        Text(realtimeManager.isConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(realtimeManager.isConnected ? .green : .gray)
                    }
                    
                    if let lastUpdate = realtimeManager.lastUpdate {
                        HStack {
                            Label("Last Update", systemImage: "clock")
                            Spacer()
                            Text(lastUpdate, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Sync Status
                Section("Sync Status") {
                    HStack {
                        Label("Pending Items", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        Text("\(syncManager.pendingSyncCount)")
                            .foregroundStyle(syncManager.pendingSyncCount > 0 ? .orange : .green)
                    }
                    
                    if let lastSync = syncManager.lastSyncDate {
                        HStack {
                            Label("Last Sync", systemImage: "checkmark.circle")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if syncManager.isSyncing {
                        HStack {
                            Label("Sync Progress", systemImage: "arrow.clockwise")
                            Spacer()
                            ProgressView(value: syncManager.syncProgress)
                                .progressViewStyle(.linear)
                                .frame(width: 100)
                        }
                    }
                }
                
                // Recent Events
                Section("Recent Activity") {
                    let recentEvents = realtimeManager.getRecentEvents(limit: 10)
                    
                    if recentEvents.isEmpty {
                        Text("No recent realtime events")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(recentEvents) { event in
                            RealtimeEventRow(event: event)
                        }
                    }
                }
                
                // Actions
                Section {
                    Button(action: {
                        Task {
                            await syncManager.performSync()
                        }
                    }) {
                        Label("Sync Now", systemImage: "arrow.clockwise")
                    }
                    .disabled(syncManager.isSyncing || !syncManager.isOnline)
                    
                    if realtimeManager.isConnected {
                        Button(action: {
                            realtimeManager.disconnectFromRealtime()
                        }) {
                            Label("Disconnect Realtime", systemImage: "antenna.radiowaves.left.and.right.slash")
                        }
                    } else {
                        Button(action: {
                            realtimeManager.connectToRealtime()
                        }) {
                            Label("Connect Realtime", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }
                }
            }
            .navigationTitle("Connection Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Realtime Event Row

struct RealtimeEventRow: View {
    let event: RealtimeEvent
    
    var body: some View {
        HStack {
            // Event Icon
            Image(systemName: eventIcon)
                .foregroundColor(eventColor)
                .frame(width: 30)
            
            // Event Details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(event.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Table Name
            Text(event.tableName)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(4)
        }
        .padding(.vertical, 2)
    }
    
    private var eventIcon: String {
        switch event.type {
        case .claimInserted, .claimUpdated:
            return "doc.text.fill"
        case .claimDeleted:
            return "trash"
        case .photoInserted, .photoUpdated:
            return "camera.fill"
        case .photoDeleted:
            return "photo.slash"
        case .documentInserted, .documentUpdated:
            return "doc.fill"
        case .documentDeleted:
            return "doc.slash"
        case .activityInserted:
            return "clock.arrow.circlepath"
        }
    }
    
    private var eventColor: Color {
        switch event.type {
        case .claimInserted, .photoInserted, .documentInserted, .activityInserted:
            return .green
        case .claimUpdated, .photoUpdated, .documentUpdated:
            return .blue
        case .claimDeleted, .photoDeleted, .documentDeleted:
            return .red
        }
    }
}

#Preview {
    RealtimeIndicator()
        .environmentObject(RealtimeManager.shared)
        .environmentObject(SyncManager.shared)
}
