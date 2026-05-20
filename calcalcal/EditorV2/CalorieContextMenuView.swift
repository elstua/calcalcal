import SwiftUI
import UIKit

struct CalorieContextMenuView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var caloriesText: String
    @State private var weightText: String
    @State private var isUpdating: Bool = false
    @State private var showUpdateSuccess: Bool = false

    private let originalCalories: Int
    private let originalWeight: Double?
    private let nutrition: NutritionData?
    private let onUpdate: (Int?, Double?) -> Void

    init(
        calories: Int,
        weight: Double? = nil,
        nutrition: NutritionData? = nil,
        onUpdate: @escaping (Int?, Double?) -> Void
    ) {
        // Use weight from nutrition data if available, otherwise use the weight parameter
        let effectiveWeight = nutrition?.weight ?? weight
        self._caloriesText = State(initialValue: calories > 0 ? String(calories) : "")
        self._weightText = State(initialValue: effectiveWeight != nil ? String(format: "%.1f", effectiveWeight!) : "")
        self.originalCalories = calories
        self.originalWeight = effectiveWeight
        self.nutrition = nutrition
        self.onUpdate = onUpdate
    }

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.smd) {
                        // Header
                        Text("Nutrition Details")
                            .font(.dsHeadline)
                            .fontWeight(.regular)

                        // Calories Section
                        HStack {

                            TextField("0", text: $caloriesText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(isUpdating)


                            Text("Calories")
                                .font(.dsSubheadline)
                                .fontWeight(.medium)
                                .foregroundColor(DSColors.textSecondary)



                        }

                        // Weight Section
                        HStack {
                            TextField("0", text: $weightText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(isUpdating)

                            Text(getWeightUnit())
                                .font(.dsSubheadline)
                                .foregroundColor(DSColors.textSecondary)
                        }

                        // Display metric description if available
                        if let metricDescription = nutrition?.metric_description, !metricDescription.isEmpty {
                            Text("Serving size: \(metricDescription)")
                                .font(.dsCaption)
                                .foregroundColor(DSColors.textSecondary)
                                .padding(.top, -4)
                        }

                        Divider()

                        // Nutrition Details
                        if let nutrition = nutrition {
                            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                nutritionRow(label: "Protein", value: nutrition.protein, unit: "g")
                                nutritionRow(label: "Fat", value: nutrition.fat, unit: "g")
                                nutritionRow(label: "Carbs", value: nutrition.carbs, unit: "g")
                                nutritionRow(label: "Fiber", value: nutrition.fiber, unit: "g")
                                nutritionRow(label: "Sugar", value: nutrition.sugar, unit: "g")
                                nutritionRow(label: "Sodium", value: nutrition.sodium, unit: "mg")
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 72) // Space for the floating button
                }

                // Sticky Update button
                Button(action: {
                    performUpdate()
                }) {
                    HStack {
                        if isUpdating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else if showUpdateSuccess {
                            Image(systemName: "checkmark")
                                .font(.dsHeadline)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.dsHeadline)
                        }
                    }
                    .frame(width: DSSpacing.xxxl, height: DSSpacing.xxxl)
                    .background(DSColors.primary)
                    .foregroundColor(DSColors.textInverted)
                    .clipShape(Circle())
                    .shadow(color: DSColors.shadowHeavy, radius: 5, y: 5)
                }
                .padding(.trailing, DSSpacing.xs)
                .padding(.bottom, DSSpacing.sm)
                .disabled(isUpdating || !hasValidChanges())
            }
        }
    private func nutritionRow(label: String, value: Double?, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.dsSubheadline)
                .foregroundColor(DSColors.textSecondary)

            Spacer()

            if let value = value, value > 0 {
                Text(String(format: "%.1f %@", value, unit))
                    .font(.dsSubheadline)
                    .fontWeight(.medium)
                    .foregroundColor(DSColors.textPrimary)
            } else {
                Text("--")
                    .font(.dsSubheadline)
                    .foregroundColor(DSColors.textSecondary)
            }
        }
    }

    private func hasValidChanges() -> Bool {
        let caloriesChanged = caloriesText != (originalCalories > 0 ? String(originalCalories) : "")
        let weightChanged = weightText != (originalWeight != nil ? String(format: "%.1f", originalWeight!) : "")

        // Check if at least one field has valid input and has changed
        if caloriesChanged, let newCalories = Int(caloriesText), newCalories > 0 {
            return true
        }

        if weightChanged, let newWeight = Double(weightText), newWeight > 0 {
            return true
        }

        return false
    }

    private func performUpdate() {
        guard hasValidChanges() else { return }

        isUpdating = true

        // Parse new values
        let newCalories = Int(caloriesText)
        let newWeight = Double(weightText)

        // Determine what changed
        let caloriesChanged = newCalories != originalCalories
        let weightChanged = newWeight != originalWeight

        var caloriesToSend: Int?
        var weightToSend: Double?

        if weightChanged {
            // If weight changed, send only weight (let AI recalculate calories)
            weightToSend = newWeight
        } else if caloriesChanged {
            // If only calories changed, send calories with original weight
            caloriesToSend = newCalories
            weightToSend = originalWeight
        }

        // Perform update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.onUpdate(caloriesToSend, weightToSend)

            // Show success state
            withAnimation {
                self.isUpdating = false
                self.showUpdateSuccess = true
            }

            // Reset success state and dismiss after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    self.showUpdateSuccess = false
                }
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }

    // Helper function to determine weight unit based on metric description
    private func getWeightUnit() -> String {
        if let metricDescription = nutrition?.metric_description, !metricDescription.isEmpty {
            // Extract unit from metric description if it contains "g" for grams
            if metricDescription.lowercased().contains("g") {
                return "g"
            } else if metricDescription.lowercased().contains("oz") {
                return "oz"
            } else if metricDescription.lowercased().contains("lb") {
                return "lb"
            }
        }
        // Default to grams
        return "g"
    }
}

// MARK: - Preview


struct CalorieContextMenuView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleNutrition = NutritionData(
            calories: 250,
            protein: 15.2,
            fat: 8.5,
            carbs: 32.1,
            fiber: 4.2,
            sugar: 12.3,
            sodium: 450.0,
            confidence: 0.92
        )

        CalorieContextMenuView(
            calories: 250,
            weight: 100.0,
            nutrition: sampleNutrition
        ) { calories, weight in
            dlog("Update: calories=\(calories ?? -1), weight=\(weight ?? -1)")
        }
        .previewDisplayName("Calorie Context Menu")
    }


}
