//
//  LoginView.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var showingSignUp = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "house.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundStyle(.blue)
                    
                    Text("ClaimsIQ Sidekick")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Property Claims Assistant")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Login Form
                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: viewModel.signIn) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                    
                    Button("Forgot Password?") {
                        // TODO: Implement password reset
                    }
                    .font(.footnote)
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Sign Up Link
                HStack {
                    Text("Don't have an account?")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    Button("Sign Up") {
                        showingSignUp = true
                    }
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                }
                .padding(.bottom, 32)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
        }
    }
}

// MARK: - View Model

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseManager = SupabaseManager.shared
    
    var isValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    func signIn() {
        guard isValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await supabaseManager.signIn(email: email, password: password)
                
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
