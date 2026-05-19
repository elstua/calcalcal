import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    @State private var showingSettings = false
    @State private var showingHealthEditor = false
    @State private var showingGoalsEditor = false
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
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: DSSpacing.mlg) {
                        // User Info
                        VStack(spacing: DSSpacing.sm) {
                            Image(systemName: "person.circle.fill")
                                .font(Font.dsCustom(weight: .regular, size: 80))
                                .foregroundColor(DSColors.primary)

                            Text(appState.currentUser?.name ?? "User")
                                .font(.dsTitle2)
                                .fontWeight(.semibold)

                            Text(appState.currentUser?.email ?? "")
                                .font(.dsSubheadline)
                                .foregroundColor(DSColors.textSecondary)
                        }

                        healthInfoSection
                        calorieGoalsSection

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

                        Spacer(minLength: DSSpacing.mlg)

                        // Sign Out Button
                        Button("Sign Out") {
                            appState.authManager.signOut()
                        }
                        .foregroundColor(DSColors.error)
                    }
                    .padding()
                }

                if showingHealthEditor {
                    ProfileHealthEditorContainer(
                        user: appState.currentUser,
                        isPresented: showingHealthEditor,
                        onClose: {
                            showingHealthEditor = false
                        },
                        onSave: { updates in
                            _ = try await appState.authManager.updateProfile(updates)
                        }
                    )
                    .transition(.opacity)
                }

                if showingGoalsEditor {
                    ProfileGoalsEditorContainer(
                        user: appState.currentUser,
                        isPresented: showingGoalsEditor,
                        onClose: {
                            showingGoalsEditor = false
                        },
                        onSave: { updates in
                            _ = try await appState.authManager.updateProfile(updates)
                        }
                    )
                    .transition(.opacity)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(appState)
            }
        }
    }

    // MARK: - Profile Info Sections

    private var healthInfoSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.smd) {
            sectionHeader("Health Information") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showingHealthEditor = true
                }
            }

            profileInfoRow("Weight:", value: formattedWeight)
            profileInfoRow("Height:", value: formattedHeight)
            profileInfoRow("Target Weight:", value: formattedTargetWeight)
            profileInfoRow("Gender:", value: formattedGender)
        }
        .padding()
        .background(DSColors.surfaceSecondary)
        .cornerRadius(DSCornerRadius.md)
    }

    private var calorieGoalsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.smd) {
            sectionHeader("Calorie Goals") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showingGoalsEditor = true
                }
            }

            profileInfoRow("Calories:", value: formattedCalories)
            profileInfoRow("Carbs:", value: formattedCarbs)
            profileInfoRow("Protein:", value: formattedProtein)
            profileInfoRow("Fat:", value: formattedFat)
        }
        .padding()
        .background(DSColors.surfaceSecondary)
        .cornerRadius(DSCornerRadius.md)
    }

    private func sectionHeader(_ title: String, onEdit: @escaping () -> Void) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.dsHeadline)

            Spacer()

            Button(action: onEdit) {
                Text("Edit")
                    .font(.dsCaptionEmphasized)
                    .foregroundColor(DSColors.primary)
                    .padding(.horizontal, DSSpacing.smd)
                    .frame(height: 34)
                    .background(
                        Capsule(style: .continuous)
                            .fill(DSColors.primary.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, DSSpacing.xs)
    }

    private func profileInfoRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.md) {
            Text(title)
                .font(.dsBody)
                .foregroundColor(DSColors.textSecondary)

            Spacer(minLength: DSSpacing.md)

            Text(value)
                .font(.dsBodyEmphasized)
                .foregroundColor(value == "Not set" ? DSColors.textSecondary : DSColors.textPrimary)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }

    private var formattedWeight: String {
        guard let weightKg = appState.currentUser?.weightKg else { return "Not set" }
        return formatWeight(weightKg, unit: appState.currentUser?.weightUnit ?? "kg")
    }

    private var formattedHeight: String {
        guard let heightCm = appState.currentUser?.heightCm else { return "Not set" }
        return formatHeight(heightCm, unit: appState.currentUser?.heightUnit ?? "cm")
    }

    private var formattedTargetWeight: String {
        guard let targetWeightKg = appState.currentUser?.targetWeightKg else { return "Not set" }
        return formatWeight(targetWeightKg, unit: appState.currentUser?.weightUnit ?? "kg")
    }

    private var formattedGender: String {
        guard let gender = appState.currentUser?.gender else { return "Not set" }
        return formatGender(gender)
    }

    private var formattedCalories: String {
        guard let goal = appState.currentUser?.dailyCalorieGoal else { return "Not set" }
        return "\(goal) kcal"
    }

    private var formattedCarbs: String {
        guard let goal = appState.currentUser?.dailyCarbGoal else { return "Not set" }
        return "\(Int(goal.rounded())) g"
    }

    private var formattedProtein: String {
        guard let goal = appState.currentUser?.dailyProteinGoal else { return "Not set" }
        return "\(Int(goal.rounded())) g"
    }

    private var formattedFat: String {
        guard let goal = appState.currentUser?.dailyFatGoal else { return "Not set" }
        return "\(Int(goal.rounded())) g"
    }
    
    // MARK: - Apple Health Section
    
    @ViewBuilder
    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.smd) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(DSColors.error)
                Text("Apple Health")
                    .font(.dsHeadline)
            }
            .padding(.bottom, DSSpacing.xs)
            
            if !healthKitManager.isAvailable {
                // HealthKit not available on this device
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(DSColors.warning)
                    Text("HealthKit is not available on this device")
                        .font(.dsSubheadline)
                        .foregroundColor(DSColors.textSecondary)
                }
            } else {
                // Connection status
                HStack {
                    Text("Status:")
                        .foregroundColor(DSColors.textSecondary)
                    Spacer()
                    HStack(spacing: DSSpacing.xs) {
                        Circle()
                            .fill(healthKitManager.isSyncEnabled ? DSColors.success : DSColors.disabled)
                            .frame(width: 8, height: 8)
                        Text(healthKitManager.isSyncEnabled ? "Connected" : "Not connected")
                            .font(.dsSubheadline)
                            .foregroundColor(healthKitManager.isSyncEnabled ? DSColors.success : DSColors.textSecondary)
                    }
                }
                
                // Last sync time
                if let lastSync = healthKitManager.lastSyncDate {
                    HStack {
                        Text("Last synced:")
                            .foregroundColor(DSColors.textSecondary)
                        Spacer()
                        Text(formatDate(lastSync))
                            .font(.dsSubheadline)
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                
                // Auto sync toggle
                Toggle(isOn: Binding(
                    get: { healthKitManager.isSyncEnabled },
                    set: { healthKitManager.isSyncEnabled = $0 }
                )) {
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        Text("Auto sync")
                        Text("Automatically import weight & height, export nutrition")
                            .font(.dsCaption)
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                
                // Sync status message
                if let message = syncStatusMessage {
                    Text(message)
                        .font(.dsCaption)
                        .foregroundColor(DSColors.textSecondary)
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
                    .padding(.vertical, DSSpacing.sm)
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
                        .padding(.vertical, DSSpacing.sm)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DSColors.error)
                }
            }
        }
        .padding()
        .background(DSColors.surfaceSecondary)
        .cornerRadius(DSCornerRadius.md)
    }
    
    // MARK: - Temporary Account Banner
    
    @ViewBuilder
    private var temporaryAccountBanner: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(DSColors.warning)
                Text("Temporary Account")
                    .font(.dsHeadline)
                Spacer()
            }
            
            Text("Your data is stored locally. Create an account in Settings to sync across devices.")
                .font(.dsSubheadline)
                .foregroundColor(DSColors.textSecondary)
        }
        .padding()
        .background(DSColors.warning.opacity(0.1))
        .cornerRadius(DSCornerRadius.md)
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

private struct ProfileHealthEditorContainer: View {
    let user: User?
    let isPresented: Bool
    let onClose: () -> Void
    let onSave: ([String: Any]) async throws -> Void

    @State private var backgroundOpacity: Double = 0
    @State private var popupOffset: CGFloat = 56
    @State private var isClosing = false

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    gradient: Gradient(colors: [
                        DSColors.primary.opacity(0.95),
                        DSColors.primary.opacity(0.0)
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .ignoresSafeArea()
                .opacity(backgroundOpacity)

                ProfileHealthEditorPopup(
                    user: user,
                    onClose: closePopup,
                    onSave: onSave
                )
                .padding(.horizontal, DSSpacing.md)
                .padding(.bottom, DSSpacing.md)
                .offset(y: popupOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .onAppear {
                presentPopup()
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    presentPopup()
                } else {
                    closePopup()
                }
            }
        }
    }

    private func presentPopup() {
        isClosing = false
        backgroundOpacity = 0
        popupOffset = 56
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            backgroundOpacity = 1
            popupOffset = 0
        }
    }

    private func closePopup() {
        guard !isClosing else { return }
        isClosing = true

        withAnimation(.easeInOut(duration: 0.22)) {
            backgroundOpacity = 0
            popupOffset = 520
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onClose()
        }
    }
}

private struct ProfileHealthEditorPopup: View {
    let user: User?
    let onClose: () -> Void
    let onSave: ([String: Any]) async throws -> Void

    @State private var weightText: String
    @State private var heightText: String
    @State private var targetWeightText: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let originalWeightKg: Double?
    private let originalHeightCm: Double?
    private let originalTargetWeightKg: Double?
    private let weightUnit: String
    private let heightUnit: String

    init(
        user: User?,
        onClose: @escaping () -> Void,
        onSave: @escaping ([String: Any]) async throws -> Void
    ) {
        self.user = user
        self.onClose = onClose
        self.onSave = onSave

        let weightUnit = user?.weightUnit ?? "kg"
        let heightUnit = user?.heightUnit ?? "cm"
        self.weightUnit = weightUnit
        self.heightUnit = heightUnit
        self.originalWeightKg = user?.weightKg
        self.originalHeightCm = user?.heightCm
        self.originalTargetWeightKg = user?.targetWeightKg

        _weightText = State(initialValue: ProfileEditorFormatting.displayWeight(user?.weightKg, unit: weightUnit))
        _heightText = State(initialValue: ProfileEditorFormatting.displayHeight(user?.heightCm, unit: heightUnit))
        _targetWeightText = State(initialValue: ProfileEditorFormatting.displayWeight(user?.targetWeightKg, unit: weightUnit))
    }

    var body: some View {
        VStack(spacing: 0) {
            ProfileEditorHeader(title: "Edit health", onClose: onClose)

            VStack(spacing: DSSpacing.sm) {
                ProfileEditorNumberRow(
                    title: "Weight",
                    unit: weightUnit,
                    text: $weightText,
                    keyboardType: .decimalPad
                )
                ProfileEditorNumberRow(
                    title: "Height",
                    unit: heightUnit,
                    text: $heightText,
                    keyboardType: .decimalPad
                )
                ProfileEditorNumberRow(
                    title: "Target weight",
                    unit: weightUnit,
                    text: $targetWeightText,
                    keyboardType: .decimalPad
                )

                if let errorMessage {
                    ProfileEditorErrorText(message: errorMessage)
                }

                DSButton(
                    "Save",
                    style: .primary,
                    size: .large,
                    isFullWidth: true,
                    isLoading: isSaving,
                    action: save
                )
                .padding(.top, DSSpacing.sm)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.xl)
        }
        .background(ProfileEditorBackground())
    }

    private func save() {
        guard !isSaving else { return }
        errorMessage = nil

        let updates = buildUpdates()
        guard updates.error == nil else {
            errorMessage = updates.error
            return
        }

        isSaving = true
        Task {
            do {
                try await onSave(updates.values)
                await MainActor.run {
                    isSaving = false
                    onClose()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func buildUpdates() -> (values: [String: Any], error: String?) {
        var updates: [String: Any] = [:]

        if let result = parsedDouble(weightText, fieldName: "Weight") {
            if let error = result.error { return (updates, error) }
            if let value = result.value {
                let kg = weightUnit == "lbs" ? value * 0.453592 : value
                if let error = validateRange(kg, fieldName: "Weight", min: 30, max: 300, unit: "kg") {
                    return (updates, error)
                }
                if changed(kg, from: originalWeightKg) {
                    updates["weight_kg"] = kg
                }
            }
        }

        if let result = parsedDouble(heightText, fieldName: "Height") {
            if let error = result.error { return (updates, error) }
            if let value = result.value {
                let cm = heightUnit == "in" ? value * 2.54 : value
                if let error = validateRange(cm, fieldName: "Height", min: 100, max: 250, unit: "cm") {
                    return (updates, error)
                }
                if changed(cm, from: originalHeightCm) {
                    updates["height_cm"] = cm
                }
            }
        }

        if let result = parsedDouble(targetWeightText, fieldName: "Target weight") {
            if let error = result.error { return (updates, error) }
            if let value = result.value {
                let kg = weightUnit == "lbs" ? value * 0.453592 : value
                if let error = validateRange(kg, fieldName: "Target weight", min: 30, max: 300, unit: "kg") {
                    return (updates, error)
                }
                if changed(kg, from: originalTargetWeightKg) {
                    updates["target_weight_kg"] = kg
                }
            }
        }

        return (updates, nil)
    }
}

private struct ProfileGoalsEditorContainer: View {
    let user: User?
    let isPresented: Bool
    let onClose: () -> Void
    let onSave: ([String: Any]) async throws -> Void

    @State private var backgroundOpacity: Double = 0
    @State private var popupOffset: CGFloat = 56
    @State private var isClosing = false

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    gradient: Gradient(colors: [
                        DSColors.primary.opacity(0.95),
                        DSColors.primary.opacity(0.0)
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .ignoresSafeArea()
                .opacity(backgroundOpacity)

                ProfileGoalsEditorPopup(
                    user: user,
                    onClose: closePopup,
                    onSave: onSave
                )
                .padding(.horizontal, DSSpacing.md)
                .padding(.bottom, DSSpacing.md)
                .offset(y: popupOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .onAppear {
                presentPopup()
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    presentPopup()
                } else {
                    closePopup()
                }
            }
        }
    }

    private func presentPopup() {
        isClosing = false
        backgroundOpacity = 0
        popupOffset = 56
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            backgroundOpacity = 1
            popupOffset = 0
        }
    }

    private func closePopup() {
        guard !isClosing else { return }
        isClosing = true

        withAnimation(.easeInOut(duration: 0.22)) {
            backgroundOpacity = 0
            popupOffset = 520
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onClose()
        }
    }
}

private struct ProfileGoalsEditorPopup: View {
    let user: User?
    let onClose: () -> Void
    let onSave: ([String: Any]) async throws -> Void

    @State private var calorieText: String
    @State private var carbText: String
    @State private var proteinText: String
    @State private var fatText: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let originalCalories: Int?
    private let originalCarbs: Double?
    private let originalProtein: Double?
    private let originalFat: Double?

    init(
        user: User?,
        onClose: @escaping () -> Void,
        onSave: @escaping ([String: Any]) async throws -> Void
    ) {
        self.user = user
        self.onClose = onClose
        self.onSave = onSave

        self.originalCalories = user?.dailyCalorieGoal
        self.originalCarbs = user?.dailyCarbGoal
        self.originalProtein = user?.dailyProteinGoal
        self.originalFat = user?.dailyFatGoal

        _calorieText = State(initialValue: user?.dailyCalorieGoal.map(String.init) ?? "")
        _carbText = State(initialValue: ProfileEditorFormatting.displayNumber(user?.dailyCarbGoal))
        _proteinText = State(initialValue: ProfileEditorFormatting.displayNumber(user?.dailyProteinGoal))
        _fatText = State(initialValue: ProfileEditorFormatting.displayNumber(user?.dailyFatGoal))
    }

    var body: some View {
        VStack(spacing: 0) {
            ProfileEditorHeader(title: "Edit calorie goals", onClose: onClose)

            VStack(spacing: DSSpacing.sm) {
                ProfileEditorNumberRow(
                    title: "Calories",
                    unit: "kcal",
                    text: $calorieText,
                    keyboardType: .numberPad
                )
                ProfileEditorNumberRow(
                    title: "Carbs",
                    unit: "g",
                    text: $carbText,
                    keyboardType: .decimalPad
                )
                ProfileEditorNumberRow(
                    title: "Protein",
                    unit: "g",
                    text: $proteinText,
                    keyboardType: .decimalPad
                )
                ProfileEditorNumberRow(
                    title: "Fat",
                    unit: "g",
                    text: $fatText,
                    keyboardType: .decimalPad
                )

                if let errorMessage {
                    ProfileEditorErrorText(message: errorMessage)
                }

                DSButton(
                    "Save",
                    style: .primary,
                    size: .large,
                    isFullWidth: true,
                    isLoading: isSaving,
                    action: save
                )
                .padding(.top, DSSpacing.sm)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.xl)
        }
        .background(ProfileEditorBackground())
    }

    private func save() {
        guard !isSaving else { return }
        errorMessage = nil

        let updates = buildUpdates()
        guard updates.error == nil else {
            errorMessage = updates.error
            return
        }

        isSaving = true
        Task {
            do {
                try await onSave(updates.values)
                await MainActor.run {
                    isSaving = false
                    onClose()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func buildUpdates() -> (values: [String: Any], error: String?) {
        var updates: [String: Any] = [:]

        if let result = parsedInt(calorieText, fieldName: "Calories") {
            if let error = result.error { return (updates, error) }
            if let value = result.value {
                if let error = validateRange(Double(value), fieldName: "Calories", min: 800, max: 8000, unit: "kcal") {
                    return (updates, error)
                }
                if value != originalCalories {
                    updates["daily_calorie_goal"] = value
                    updates["daily_calorie_goal_is_manual"] = true
                }
            }
        }

        appendMacroUpdate(
            field: "daily_carb_goal",
            text: carbText,
            original: originalCarbs,
            label: "Carbs",
            updates: &updates
        )
        if let errorMessage { return (updates, errorMessage) }

        appendMacroUpdate(
            field: "daily_protein_goal",
            text: proteinText,
            original: originalProtein,
            label: "Protein",
            updates: &updates
        )
        if let errorMessage { return (updates, errorMessage) }

        appendMacroUpdate(
            field: "daily_fat_goal",
            text: fatText,
            original: originalFat,
            label: "Fat",
            updates: &updates
        )
        if let errorMessage { return (updates, errorMessage) }

        return (updates, nil)
    }

    private func appendMacroUpdate(
        field: String,
        text: String,
        original: Double?,
        label: String,
        updates: inout [String: Any]
    ) {
        guard let result = parsedDouble(text, fieldName: label) else { return }
        if let error = result.error {
            errorMessage = error
            return
        }
        guard let value = result.value else { return }
        if let error = validateRange(value, fieldName: label, min: 1, max: 1000, unit: "g") {
            errorMessage = error
            return
        }
        guard changed(value, from: original) else { return }
        updates[field] = value
    }
}

private func parsedDouble(_ text: String, fieldName: String) -> (value: Double?, error: String?)? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value >= 0 else {
        return (nil, "\(fieldName) must be a non-negative number.")
    }
    return (value, nil)
}

private func parsedInt(_ text: String, fieldName: String) -> (value: Int?, error: String?)? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard let value = Int(trimmed), value >= 0 else {
        return (nil, "\(fieldName) must be a whole non-negative number.")
    }
    return (value, nil)
}

private func validateRange(
    _ value: Double,
    fieldName: String,
    min: Double,
    max: Double,
    unit: String
) -> String? {
    guard value >= min && value <= max else {
        return "\(fieldName) should be between \(ProfileEditorFormatting.displayNumber(min)) and \(ProfileEditorFormatting.displayNumber(max)) \(unit)."
    }
    return nil
}

private func changed(_ value: Double, from original: Double?) -> Bool {
    guard let original else { return true }
    return abs(value - original) > 0.01
}

private enum ProfileEditorFormatting {
    static func displayWeight(_ kg: Double?, unit: String) -> String {
        guard let kg else { return "" }
        let value = unit == "lbs" ? kg * 2.20462 : kg
        return displayNumber(value)
    }

    static func displayHeight(_ cm: Double?, unit: String) -> String {
        guard let cm else { return "" }
        let value = unit == "in" ? cm / 2.54 : cm
        return displayNumber(value)
    }

    static func displayNumber(_ value: Double?) -> String {
        guard let value else { return "" }
        if abs(value.rounded() - value) < 0.05 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
}

private struct ProfileEditorHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.dsHeadline)
                .foregroundColor(DSColors.textPrimary)

            Spacer()

            DSIconButton(icon: "xmark", style: .ghost, size: .regular) {
                onClose()
            }
        }
        .padding(.leading, DSSpacing.lg)
        .padding(.trailing, DSSpacing.smd)
        .padding(.top, DSSpacing.smd)
        .padding(.bottom, DSSpacing.md)
    }
}

private struct ProfileEditorErrorText: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.dsCaption)
            .foregroundColor(DSColors.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DSSpacing.xs)
    }
}

private struct ProfileEditorBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: DSCornerRadius.xxl, style: .continuous)
            .fill(DSColors.surface)
            .dsShadow(.xlarge)
    }
}

private struct ProfileEditorNumberRow: View {
    let title: String
    let unit: String
    @Binding var text: String
    let keyboardType: UIKeyboardType

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Text(title)
                .font(.dsBody)
                .foregroundColor(DSColors.textPrimary)

            Spacer(minLength: DSSpacing.sm)

            HStack(spacing: DSSpacing.xs) {
                TextField("0", text: $text)
                    .keyboardType(keyboardType)
                    .multilineTextAlignment(.trailing)
                    .font(.dsBodyEmphasized)
                    .foregroundColor(DSColors.textPrimary)
                    .monospacedDigit()
                    .frame(width: 84)

                Text(unit)
                    .font(.dsSubheadline)
                    .foregroundColor(DSColors.textSecondary)
                    .frame(width: 34, alignment: .leading)
            }
        }
        .padding(.horizontal, DSSpacing.smd)
        .frame(minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.md, style: .continuous)
                .fill(DSColors.surfaceSecondary)
        )
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AppState())
    }
}
