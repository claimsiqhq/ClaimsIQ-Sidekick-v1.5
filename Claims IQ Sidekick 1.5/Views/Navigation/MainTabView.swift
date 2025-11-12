//
//  MainTabView.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }
                .tag(1)
            
            CaptureView()
                .tabItem {
                    Label("Capture", systemImage: "camera.fill")
                }
                .tag(2)
            
            ClaimsListView()
                .tabItem {
                    Label("Claims", systemImage: "list.bullet.clipboard.fill")
                }
                .tag(3)
            
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(4)
        }
        .accentColor(.blue)
        .onAppear {
            // Configure tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Placeholder Views (to be implemented)

struct TodayView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    HStack {
                        Label("3 Inspections", systemImage: "house.circle.fill")
                        Spacer()
                        Text("2.5 hours")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("Weather", systemImage: "cloud.sun.fill")
                        Spacer()
                        Text("72°F, Partly Cloudy")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Today's Schedule") {
                    Text("No inspections scheduled")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}



struct MapView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.gray)
                
                Text("Map Coming Soon")
                    .font(.title2)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    MainTabView()
        .environmentObject(SupabaseManager.shared)
        .environmentObject(LocationManager.shared)
}
