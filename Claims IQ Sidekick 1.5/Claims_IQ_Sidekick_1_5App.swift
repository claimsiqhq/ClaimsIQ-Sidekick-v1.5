//
//  Claims_IQ_Sidekick_1_5App.swift
//  Claims IQ Sidekick 1.5
//
//  Created by John Shoust on 2025-11-07.
//

import SwiftUI
import SwiftData
import Supabase
import BackgroundTasks

@main
struct Claims_IQ_Sidekick_1_5App: App {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var realtimeManager = RealtimeManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Claim.self,
            Photo.self,
            Document.self,
            Inspection.self,
            ActivityTimeline.self,
            InspectionChecklist.self,
            SyncQueue.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            AuthView()
                .environmentObject(supabaseManager)
                .environmentObject(locationManager)
                .environmentObject(syncManager)
                .environmentObject(dataManager)
                .environmentObject(realtimeManager)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    scheduleBackgroundSync()
                }
        }
        .modelContainer(sharedModelContainer)
        .backgroundTask(.appRefresh("com.claimsiq.sync")) {
            await syncManager.performSync()
        }
    }
    
    // MARK: - Background Tasks
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.claimsiq.sync",
            using: nil
        ) { task in
            Task {
                await syncManager.handleBackgroundTask(task: task)
            }
        }
    }
    
    private func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: "com.claimsiq.sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: Configuration.backgroundFetchInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background sync: \(error)")
        }
    }
}
