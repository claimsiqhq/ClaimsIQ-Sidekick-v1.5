//
//  Claims_IQ_Sidekick_1_5App.swift
//  Claims IQ Sidekick 1.5
//
//  Created by John Shoust on 2025-11-07.
//

import SwiftUI
import SwiftData

@main
struct Claims_IQ_Sidekick_1_5App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
