//
//  NewClaimView.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import SwiftUI
import SwiftData

struct NewClaimView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var claimNumber = ""
    @State private var policyNumber = ""
    @State private var insuredName = ""
    @State private var insuredPhone = ""
    @State private var insuredEmail = ""
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var lossDate = Date()
    @State private var lossDescription = ""
    @State private var priority: ClaimPriority = .normal
    @State private var coverageType = ""
    @State private var deductible = ""
    
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var useCurrentLocation = false
    
    private var isValid: Bool {
        !claimNumber.isEmpty && !insuredName.isEmpty && !address.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Information
                Section("Claim Information") {
                    TextField("Claim Number", text: $claimNumber)
                        .textInputAutocapitalization(.characters)
                    
                    TextField("Policy Number (Optional)", text: $policyNumber)
                        .textInputAutocapitalization(.characters)
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(ClaimPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                }
                
                // Insured Information
                Section("Insured Information") {
                    TextField("Name", text: $insuredName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Phone (Optional)", text: $insuredPhone)
                        .keyboardType(.phonePad)
                    
                    TextField("Email (Optional)", text: $insuredEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                // Property Location
                Section("Property Location") {
                    Toggle("Use Current Location", isOn: $useCurrentLocation)
                        .onChange(of: useCurrentLocation) { _, newValue in
                            if newValue {
                                fetchCurrentLocation()
                            }
                        }
                    
                    TextField("Address", text: $address)
                        .disabled(useCurrentLocation)
                    
                    TextField("City", text: $city)
                        .disabled(useCurrentLocation)
                    
                    HStack {
                        TextField("State", text: $state)
                            .frame(maxWidth: 100)
                        
                        TextField("ZIP Code", text: $zipCode)
                            .keyboardType(.numberPad)
                    }
                    .disabled(useCurrentLocation)
                }
                
                // Loss Information
                Section("Loss Information") {
                    DatePicker("Date of Loss", selection: $lossDate, displayedComponents: .date)
                    
                    TextField("Loss Description", text: $lossDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Coverage Information
                Section("Coverage Information (Optional)") {
                    TextField("Coverage Type", text: $coverageType)
                    
                    TextField("Deductible", text: $deductible)
                        .keyboardType(.decimalPad)
                        .onChange(of: deductible) { _, newValue in
                            // Format as currency
                            let filtered = newValue.filter { $0.isNumber || $0 == "." }
                            if filtered != newValue {
                                deductible = filtered
                            }
                        }
                }
            }
            .navigationTitle("New Claim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .disabled(isLoading)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                Task {
                    await createClaim()
                }
            }
            .disabled(!isValid || isLoading)
        }
    }
    
    // MARK: - Actions
    
    private func fetchCurrentLocation() {
        guard locationManager.isLocationEnabled else {
            errorMessage = "Location services are not enabled"
            showingError = true
            useCurrentLocation = false
            return
        }
        
        Task {
            do {
                let location = try await locationManager.getCurrentLocation()
                let addressString = try await locationManager.reverseGeocodeLocation(location)
                
                await MainActor.run {
                    self.address = addressString
                    // Parse address components if available
                    // This is simplified - in production you'd parse the placemark properly
                    let components = addressString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    if components.count >= 3 {
                        self.city = String(components[components.count - 3])
                        self.state = String(components[components.count - 2])
                        self.zipCode = String(components[components.count - 1])
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to get current location"
                    self.showingError = true
                    self.useCurrentLocation = false
                }
            }
        }
    }
    
    private func createClaim() async {
        isLoading = true
        
        // Create the claim
        let claim = Claim(
            claimNumber: claimNumber,
            insuredName: insuredName,
            address: address,
            status: .active,
            priority: priority
        )
        
        // Set optional fields
        claim.policyNumber = policyNumber.isEmpty ? nil : policyNumber
        claim.insuredPhone = insuredPhone.isEmpty ? nil : insuredPhone
        claim.insuredEmail = insuredEmail.isEmpty ? nil : insuredEmail
        claim.city = city.isEmpty ? nil : city
        claim.state = state.isEmpty ? nil : state
        claim.zipCode = zipCode.isEmpty ? nil : zipCode
        claim.lossDate = lossDate
        claim.lossDescription = lossDescription.isEmpty ? nil : lossDescription
        claim.coverageType = coverageType.isEmpty ? nil : coverageType
        
        if !deductible.isEmpty, let deductibleAmount = Double(deductible) {
            claim.deductible = deductibleAmount
        }
        
        // Get GPS coordinates if available
        if let location = locationManager.currentLocation {
            claim.latitude = location.coordinate.latitude
            claim.longitude = location.coordinate.longitude
        }
        
        // Insert into local database
        modelContext.insert(claim)
        
        // Create initial activity
        let activity = ActivityTimeline(
            activityType: .claimCreated,
            description: "Claim \(claimNumber) created",
            claimId: claim.id
        )
        activity.claim = claim
        modelContext.insert(activity)
        
        // Create default checklist items
        createDefaultChecklist(for: claim)
        
        do {
            try modelContext.save()
            
            // Add to sync queue
            if let claimData = try? JSONEncoder().encode(claim.toDTO()) {
                let syncItem = SyncQueue(
                    operationType: .create,
                    tableName: "claims",
                    recordId: claim.id,
                    data: claimData
                )
                modelContext.insert(syncItem)
                try modelContext.save()
            }
            
            // Try to sync immediately if online
            Task {
                try? await supabaseManager.createClaim(claim)
            }
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create claim: \(error.localizedDescription)"
                self.showingError = true
                self.isLoading = false
            }
        }
    }
    
    private func createDefaultChecklist(for claim: Claim) {
        let categories: [ChecklistCategory] = [.exterior, .roof, .interior]
        
        for category in categories {
            let defaultItems = category.defaultItems.prefix(5) // Limit to 5 items per category initially
            
            for (index, itemName) in defaultItems.enumerated() {
                let checklistItem = InspectionChecklist(
                    category: category,
                    itemName: itemName,
                    required: index < 2 // First 2 items are required
                )
                checklistItem.claim = claim
                modelContext.insert(checklistItem)
            }
        }
    }
}

#Preview {
    NewClaimView()
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
