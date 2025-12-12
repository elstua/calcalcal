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
        self._caloriesText = State(initialValue: calories > 0 ? String(calories) : "")
        self._weightText = State(initialValue: weight != nil ? String(format: "%.1f", weight!) : "")
        self.originalCalories = calories
        self.originalWeight = weight
        self.nutrition = nutrition
        self.onUpdate = onUpdate
    }

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        Text("Nutrition Details")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Divider()

                        // Calories Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calories")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            HStack {
                                TextField("0", text: $caloriesText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disabled(isUpdating)

                                Text("kcal")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Weight Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weight")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            HStack {
                                TextField("0", text: $weightText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disabled(isUpdating)

                                Text("g")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        // Nutrition Details
                        if let nutrition = nutrition {
                            VStack(alignment: .leading, spacing: 6) {
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
                    .padding(.bottom, 60) // Space for the floating button
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
                                .font(.system(size: 24, weight: .bold))
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 24, weight: .bold))
                        }
                    }
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 5)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
                .disabled(isUpdating || !hasValidChanges())
            }
            .frame(width: 280, height: 450)
        }
    private func nutritionRow(label: String, value: Double?, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            if let value = value, value > 0 {
                Text(String(format: "%.1f %@", value, unit))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            } else {
                Text("--")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
            print("Update: calories=\(calories ?? -1), weight=\(weight ?? -1)")
        }
        .previewDisplayName("Calorie Context Menu")
    }
}
