//
//  AuthView.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI

struct AuthView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    var body: some View {
        Group {
            if supabaseManager.isAuthenticated {
                // Main app view will go here
                MainTabView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: supabaseManager.isAuthenticated)
        .task {
            await supabaseManager.checkSession()
        }
    }
}


#Preview {
    AuthView()
}
