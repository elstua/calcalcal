import SwiftUI
import UIKit

struct CalorieContextMenuView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var caloriesText: String
    @State private var weightText: String
    @State private var isUpdating: Bool = false
    @State private var showUpdateSuccess: Bool = false
    @State private var isPresented: Bool = false

    private let originalCalories: Int
    private let originalWeight: Double?
    private let nutrition: NutritionData?
    private let onUpdate: (Int?, Double?) -> Void
    private let onDismiss: (() -> Void)?
    private let cardWidth: CGFloat = 320

    init(
        calories: Int,
        weight: Double? = nil,
        nutrition: NutritionData? = nil,
        onDismiss: (() -> Void)? = nil,
        onUpdate: @escaping (Int?, Double?) -> Void
    ) {
        // Use weight from nutrition data if available, otherwise use the weight parameter
        let effectiveWeight = nutrition?.weight ?? weight
        self._caloriesText = State(initialValue: calories > 0 ? String(calories) : "")
        self._weightText = State(initialValue: effectiveWeight != nil ? String(format: "%.1f", effectiveWeight!) : "")
        self.originalCalories = calories
        self.originalWeight = effectiveWeight
        self.nutrition = nutrition
        self.onDismiss = onDismiss
        self.onUpdate = onUpdate
    }

    var body: some View {
        VStack(spacing: 0) {
            CalorieEditorHeader(title: "Nutrition Details") {
                dismissWithScale()
            }

            VStack(spacing: DSSpacing.sm) {
                CalorieEditorNumberRow(
                    title: "Calories",
                    unit: "kcal",
                    text: $caloriesText,
                    keyboardType: .numberPad,
                    isDisabled: isUpdating
                )

                CalorieEditorNumberRow(
                    title: "Weight",
                    unit: getWeightUnit(),
                    text: $weightText,
                    keyboardType: .decimalPad,
                    isDisabled: isUpdating
                )

                if let metricDescription = nutrition?.metric_description, !metricDescription.isEmpty {
                    Text("Serving size: \(metricDescription)")
                        .font(.dsCaption)
                        .foregroundColor(DSColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, DSSpacing.xs)
                }

                if let nutrition = nutrition {
                    Divider()
                        .padding(.vertical, DSSpacing.xs)

                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        nutritionRow(label: "Protein", value: nutrition.protein, unit: "g")
                        nutritionRow(label: "Fat", value: nutrition.fat, unit: "g")
                        nutritionRow(label: "Carbs", value: nutrition.carbs, unit: "g")
                        nutritionRow(label: "Fiber", value: nutrition.fiber, unit: "g")
                        nutritionRow(label: "Sugar", value: nutrition.sugar, unit: "g")
                        nutritionRow(label: "Sodium", value: nutrition.sodium, unit: "mg")
                    }
                }

                updateButton
                    .padding(.top, DSSpacing.smd)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.xl)
        }
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(DSColors.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 28, x: 0, y: 18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        .scaleEffect(isPresented ? 1 : 0.72, anchor: .topTrailing)
        .opacity(isPresented ? 1 : 0)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isPresented)
        .onAppear {
            isPresented = true
        }
    }

    private var updateButton: some View {
        Button(action: performUpdate) {
            HStack(spacing: DSSpacing.xs) {
                if isUpdating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if showUpdateSuccess {
                    Image(systemName: "checkmark")
                        .font(Font.dsCustom(weight: .semiBold, size: 14))
                }

                Text("update")
                    .font(Font.dsCustom(weight: .medium, size: 17))
            }
            .foregroundColor(DSColors.textInverted.opacity(hasValidChanges() ? 1 : 0.92))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Capsule(style: .continuous)
                    .fill(DSColors.primary.opacity(hasValidChanges() ? 1 : 0.55))
            )
        }
        .buttonStyle(.plain)
        .disabled(isUpdating || !hasValidChanges())
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
                    .monospacedDigit()
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
                self.dismissWithScale()
            }
        }
    }

    private func dismissWithScale() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isPresented = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            if let onDismiss {
                onDismiss()
            } else {
                presentationMode.wrappedValue.dismiss()
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

private struct CalorieEditorHeader: View {
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
        .padding(.top, DSSpacing.lg)
        .padding(.bottom, DSSpacing.md)
    }
}

private struct CalorieEditorNumberRow: View {
    let title: String
    let unit: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Text(title)
                .font(.dsBody)
                .foregroundColor(DSColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: 82, alignment: .leading)

            Spacer(minLength: DSSpacing.sm)

            HStack(spacing: DSSpacing.xs) {
                TextField("0", text: $text)
                    .keyboardType(keyboardType)
                    .multilineTextAlignment(.trailing)
                    .font(.dsBodyEmphasized)
                    .foregroundColor(DSColors.textPrimary)
                    .monospacedDigit()
                    .frame(width: 82)
                    .disabled(isDisabled)

                Text(unit)
                    .font(.dsSubheadline)
                    .foregroundColor(DSColors.textSecondary)
                    .lineLimit(1)
                    .frame(width: 36, alignment: .leading)
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
        .environmentObject(AppState())
        .previewDisplayName("Calorie Context Menu")
    }


}
