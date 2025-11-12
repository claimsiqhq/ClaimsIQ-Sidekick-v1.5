//
//  SignUpView.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Join ClaimsIQ Sidekick")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)
                
                // Sign Up Form
                VStack(spacing: 16) {
                    TextField("Full Name", text: $viewModel.fullName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                        .textFieldStyle(.roundedBorder)
                    
                    // Password Requirements
                    VStack(alignment: .leading, spacing: 4) {
                        Label("At least 8 characters", systemImage: viewModel.passwordLength ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(viewModel.passwordLength ? .green : .secondary)
                        
                        Label("Passwords match", systemImage: viewModel.passwordsMatch && !viewModel.password.isEmpty ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(viewModel.passwordsMatch && !viewModel.password.isEmpty ? .green : .secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: viewModel.signUp) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Terms and Privacy
                Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
                
                // Sign In Link
                HStack {
                    Text("Already have an account?")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    Button("Sign In") {
                        dismiss()
                    }
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                }
                .padding(.bottom, 32)
            }
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
}

// MARK: - View Model

class SignUpViewModel: ObservableObject {
    @Published var fullName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseManager = SupabaseManager.shared
    
    var passwordLength: Bool {
        password.count >= 8
    }
    
    var passwordsMatch: Bool {
        password == confirmPassword
    }
    
    var isValid: Bool {
        !fullName.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        passwordLength &&
        passwordsMatch
    }
    
    func signUp() {
        guard isValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await supabaseManager.signUp(
                    email: email,
                    password: password,
                    fullName: fullName
                )
                
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
    SignUpView()
}
