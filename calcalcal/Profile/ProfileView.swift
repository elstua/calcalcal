import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    @State private var showingSettings = false
    @State private var isSyncing = false
    @State private var syncStatusMessage: String?
    
    // MARK: - Helper Functions
    
    /// Format weight value with appropriate unit
    private func formatWeight(_ weightKg: Double, unit: String) -> String {
        if unit == "lbs" {
            let weightLbs = weightKg * 2.20462
            return String(format: "%.1f lbs", weightLbs)
        } else {
            return String(format: "%.1f kg", weightKg)
        }
    }
    
    /// Format height value with appropriate unit
    private func formatHeight(_ heightCm: Double, unit: String) -> String {
        if unit == "in" {
            let heightIn = heightCm / 2.54
            let feet = Int(heightIn / 12)
            let inches = Int(heightIn.truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(inches)\""
        } else {
            return String(format: "%.0f cm", heightCm)
        }
    }
    
    /// Format gender string for display
    private func formatGender(_ gender: String) -> String {
        switch gender.lowercased() {
        case "male":
            return "Male"
        case "female":
            return "Female"
        case "other":
            return "Other"
        default:
            return gender.capitalized
        }
    }
    
    /// Format date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // User Info
                    VStack(spacing: 10) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text(appState.currentUser?.name ?? "User")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(appState.currentUser?.email ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Health Data Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Health Information")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        // Weight
                        HStack {
                            Text("Weight:")
                                .foregroundColor(.secondary)
                            Spacer()
                            if let weightKg = appState.currentUser?.weightKg {
                                let weightUnit = appState.currentUser?.weightUnit ?? "kg"
                                Text(formatWeight(weightKg, unit: weightUnit))
                                    .fontWeight(.medium)
                            } else {
                                Text("Not set")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Height
                        HStack {
                            Text("Height:")
                                .foregroundColor(.secondary)
                            Spacer()
                            if let heightCm = appState.currentUser?.heightCm {
                                let heightUnit = appState.currentUser?.heightUnit ?? "cm"
                                Text(formatHeight(heightCm, unit: heightUnit))
                                    .fontWeight(.medium)
                            } else {
                                Text("Not set")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Target Weight (Estimated Weight)
                        HStack {
                            Text("Target Weight:")
                                .foregroundColor(.secondary)
                            Spacer()
                            if let targetWeightKg = appState.currentUser?.targetWeightKg {
                                let weightUnit = appState.currentUser?.weightUnit ?? "kg"
                                Text(formatWeight(targetWeightKg, unit: weightUnit))
                                    .fontWeight(.medium)
                            } else {
                                Text("Not set")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Gender
                        HStack {
                            Text("Gender:")
                                .foregroundColor(.secondary)
                            Spacer()
                            if let gender = appState.currentUser?.gender {
                                Text(formatGender(gender))
                                    .fontWeight(.medium)
                            } else {
                                Text("Not set")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Apple Health Section
                    healthKitSection
                    
                    // Account Status Banner (for temporary accounts)
                    if appState.isTemporaryUser {
                        temporaryAccountBanner
                    }
                    
                    // Settings Button
                    Button("Settings") {
                        showingSettings = true
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer(minLength: 20)
                    
                    // Sign Out Button
                    Button("Sign Out") {
                        appState.authManager.signOut()
                    }
                    .foregroundColor(.red)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(appState)
            }
        }
    }
    
    // MARK: - Apple Health Section
    
    @ViewBuilder
    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Apple Health")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            if !healthKitManager.isAvailable {
                // HealthKit not available on this device
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("HealthKit is not available on this device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                // Connection status
                HStack {
                    Text("Status:")
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(healthKitManager.isSyncEnabled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(healthKitManager.isSyncEnabled ? "Connected" : "Not connected")
                            .font(.subheadline)
                            .foregroundColor(healthKitManager.isSyncEnabled ? .green : .secondary)
                    }
                }
                
                // Last sync time
                if let lastSync = healthKitManager.lastSyncDate {
                    HStack {
                        Text("Last synced:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(lastSync))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Auto sync toggle
                Toggle(isOn: Binding(
                    get: { healthKitManager.isSyncEnabled },
                    set: { healthKitManager.isSyncEnabled = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto sync")
                        Text("Automatically import weight & height, export nutrition")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Sync status message
                if let message = syncStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                // Manual sync button
                Button(action: syncHealthKitData) {
                    HStack {
                        if isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(isSyncing ? "Syncing..." : "Sync Now")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(isSyncing)
                
                // Connect button if not connected
                if !healthKitManager.isSyncEnabled {
                    Button(action: connectHealthKit) {
                        HStack {
                            Image(systemName: "heart.fill")
                            Text("Connect Apple Health")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Temporary Account Banner
    
    @ViewBuilder
    private var temporaryAccountBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Temporary Account")
                    .font(.headline)
                Spacer()
            }
            
            Text("Your data is stored locally. Create an account in Settings to sync across devices.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func syncHealthKitData() {
        isSyncing = true
        syncStatusMessage = nil
        
        Task {
            await appState.syncHealthKitDataManually()
            
            await MainActor.run {
                isSyncing = false
                syncStatusMessage = "Health data synced successfully"
                
                // Clear message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    syncStatusMessage = nil
                }
            }
        }
    }
    
    private func connectHealthKit() {
        isSyncing = true
        syncStatusMessage = nil
        
        Task {
            do {
                // Request all permissions - this shows Apple's native permission sheet
                let authorized = try await healthKitManager.requestAllPermissions()
                
                if authorized {
                    // Read and sync health data
                    await appState.syncHealthKitDataManually()
                    
                    await MainActor.run {
                        syncStatusMessage = "Successfully connected to Apple Health"
                    }
                } else {
                    await MainActor.run {
                        syncStatusMessage = "Permission denied. You can enable it in Settings > Privacy > Health"
                    }
                }
            } catch {
                await MainActor.run {
                    syncStatusMessage = "Error: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isSyncing = false
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AppState())
    }
}
