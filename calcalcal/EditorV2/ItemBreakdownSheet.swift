import SwiftUI
import UIKit

private enum ItemMacroColor {
    static let carbs = Color(hex: 0x5CB8C4)
    static let protein = Color(hex: 0x3B8A5E)
    static let fat = Color(hex: 0xE0854A)
}

// MARK: - Editable item view model

private struct EditableItem: Identifiable {
    let id = UUID()
    var name: String
    var sourceText: String?
    var quantity: Int?
    var caloriesText: String
    var weightText: String
    var weightUnit: WeightUnit
    // Macros are displayed read-only and rescaled with weight or calories.
    var protein: Double?
    var fat: Double?
    var carbs: Double?
    var fiber: Double?
    var sugar: Double?
    var sodium: Double?
    var metricDescription: String?
    var confidence: Double?

    // Immutable baseline (original values) used to rescale proportionally. When a
    // field changes: value = baseline * (newField / baseField). Recomputing from
    // the baseline (not the current value) avoids cumulative rounding drift.
    let baseCalories: Int
    let baseWeight: Double?
    let baseProtein: Double?
    let baseFat: Double?
    let baseCarbs: Double?
    let baseFiber: Double?
    let baseSugar: Double?
    let baseSodium: Double?

    // Tracks the last value we wrote programmatically, so a calories field change
    // that was triggered by a weight edit doesn't re-fire and double-rescale.
    var lastCaloriesText: String = ""

    var calories: Int { Int(caloriesText) ?? 0 }
    var weight: Double? { weightInGrams }

    /// True when we have a positive baseline weight to scale against.
    var canScaleByWeight: Bool { (baseWeight ?? 0) > 0 }

    /// Rescales calories and macros proportionally to the edited weight.
    mutating func rescaleFromWeight() {
        guard let base = baseWeight, base > 0,
              let newWeight = weightInGrams, newWeight > 0 else { return }
        let factor = newWeight / base
        caloriesText = String(Int((Double(baseCalories) * factor).rounded()))
        lastCaloriesText = caloriesText
        applyMacroScale(factor)
    }

    /// Rescales macros proportionally to a directly edited calorie value.
    mutating func rescaleFromCalories() {
        guard baseCalories > 0, let newCalories = Double(caloriesText), newCalories > 0 else { return }
        let factor = newCalories / Double(baseCalories)
        applyMacroScale(factor)
    }

    private mutating func applyMacroScale(_ factor: Double) {
        protein = baseProtein.map { $0 * factor }
        fat = baseFat.map { $0 * factor }
        carbs = baseCarbs.map { $0 * factor }
        fiber = baseFiber.map { $0 * factor }
        sugar = baseSugar.map { $0 * factor }
        sodium = baseSodium.map { $0 * factor }
    }

    func toNutritionItem() -> NutritionItem {
        NutritionItem(
            name: name,
            source_text: sourceText,
            quantity: quantity,
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium,
            weight: weight,
            metric_description: metricDescription,
            confidence: confidence
        )
    }

    mutating func selectWeightUnit(_ newUnit: WeightUnit) {
        let currentWeight = weightInGrams
        weightUnit = newUnit
        weightText = currentWeight.map { formattedWeightText(forGrams: $0) } ?? ""
    }

    var weightUnitLabel: String {
        switch weightUnit {
        case .grams:
            return "g"
        case .ounces:
            return "oz"
        case .serving:
            return servingUnitName
        }
    }

    var availableWeightUnits: [WeightUnit] {
        var units: [WeightUnit] = [.grams, .ounces]
        if hasServingUnit { units.append(.serving) }
        return units
    }

    private var weightInGrams: Double? {
        guard let value = Double(weightText), value > 0 else { return nil }
        switch weightUnit {
        case .grams:
            return value
        case .ounces:
            return value * Self.gramsPerOunce
        case .serving:
            guard let baseWeight, baseWeight > 0 else { return nil }
            return value * baseWeight
        }
    }

    private var hasServingUnit: Bool {
        guard let metricDescription else { return false }
        return !metricDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (baseWeight ?? 0) > 0
    }

    private var servingUnitName: String {
        guard let metricDescription else { return "item" }
        let cleaned = metricDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^\d+(\.\d+)?\s*"#, with: "", options: .regularExpression)
        return cleaned.isEmpty ? "item" : cleaned
    }

    private func formattedWeightText(forGrams grams: Double) -> String {
        switch weightUnit {
        case .grams:
            return Self.formatWeight(grams)
        case .ounces:
            return Self.formatWeight(grams / Self.gramsPerOunce)
        case .serving:
            guard let baseWeight, baseWeight > 0 else { return Self.formatWeight(grams) }
            return Self.formatWeight(grams / baseWeight)
        }
    }

    private static func formatWeight(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static let gramsPerOunce = 28.349523125
}

private enum WeightUnit: String, CaseIterable, Identifiable {
    case grams
    case ounces
    case serving

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .grams: return "Grams"
        case .ounces: return "Ounces"
        case .serving: return "Serving"
        }
    }
}

// MARK: - Item card

private struct ItemCard: View {
    @Binding var item: EditableItem
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.smd) {
            HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
                Text(item.name.isEmpty ? "Item" : item.name)
                    .font(.dsTitle3)
                    .foregroundColor(DSColors.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let qty = item.quantity, qty > 1 {
                    Text("×\(qty)")
                        .font(.dsCaption)
                        .foregroundColor(DSColors.textSecondary)
                }

                Spacer(minLength: DSSpacing.sm)
            }

            VStack(spacing: DSSpacing.sm) {
                fieldPill(title: "Calories", text: $item.caloriesText, unit: "kcal", keyboard: .numberPad)
                    .onChange(of: item.caloriesText) { newValue in
                        // Skip programmatic changes written by a weight edit.
                        guard newValue != item.lastCaloriesText else { return }
                        item.lastCaloriesText = newValue
                        item.rescaleFromCalories()
                    }
                weightField
                    .onChange(of: item.weightText) { _ in
                        item.rescaleFromWeight()
                    }
            }
            .padding(.top, DSSpacing.xs)

            if item.canScaleByWeight {
                Text("Editing calories or weight rescales the macros")
                    .font(.dsCaption)
                    .foregroundColor(DSColors.textSecondary.opacity(0.7))
            }

            if hasMacros {
                VStack(spacing: DSSpacing.xs) {
                    if let c = item.carbs, c > 0 { macroRow(title: "Carbs", value: c, color: ItemMacroColor.carbs) }
                    if let p = item.protein, p > 0 { macroRow(title: "Proteins", value: p, color: ItemMacroColor.protein) }
                    if let f = item.fat, f > 0 { macroRow(title: "Fats", value: f, color: ItemMacroColor.fat) }
                }
                .padding(.top, DSSpacing.xxs)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.mlg)
        .frame(maxWidth: .infinity, minHeight: 350, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.xl, style: .continuous)
                .fill(DSColors.surfaceSecondary)
                .shadow(color: DSColors.shadowMedium, radius: 14, x: 0, y: 8)
                .shadow(color: DSColors.shadowLight, radius: 2, x: 0, y: 1)
        )
        .opacity(isDisabled ? 0.6 : 1)
        .allowsHitTesting(!isDisabled)
    }

    private var hasMacros: Bool {
        (item.protein ?? 0) > 0 || (item.fat ?? 0) > 0 || (item.carbs ?? 0) > 0
    }

    private var weightField: some View {
        fieldPill(
            title: "Weight",
            text: $item.weightText,
            unit: item.weightUnitLabel,
            keyboard: .decimalPad,
            unitMenu: {
                Menu {
                    ForEach(item.availableWeightUnits) { unit in
                        Button {
                            item.selectWeightUnit(unit)
                            item.rescaleFromWeight()
                        } label: {
                            if unit == item.weightUnit {
                                Label(unit.menuTitle, systemImage: "checkmark")
                            } else {
                                Text(unit.menuTitle)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(item.weightUnitLabel)
                        Image(systemName: "chevron.down")
                            .font(Font.dsCustom(weight: .semiBold, size: 9))
                    }
                    .font(.dsCaption)
                    .foregroundColor(DSColors.textSecondary)
                    .frame(minWidth: 40, minHeight: 40, alignment: .trailing)
                }
                .buttonStyle(.plain)
            }
        )
    }

    private func fieldPill(title: String, text: Binding<String>, unit: String, keyboard: UIKeyboardType) -> some View {
        fieldPill(title: title, text: text, unit: unit, keyboard: keyboard) {
            Text(unit)
                .font(.dsCaption)
                .foregroundColor(DSColors.textSecondary)
        }
    }

    private func fieldPill<UnitView: View>(
        title: String,
        text: Binding<String>,
        unit: String,
        keyboard: UIKeyboardType,
        @ViewBuilder unitMenu: () -> UnitView
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.dsCaption)
                .foregroundColor(DSColors.textSecondary)
            HStack(spacing: DSSpacing.xxs) {
                TextField("0", text: text)
                    .keyboardType(keyboard)
                    .font(.dsBodyEmphasized)
                    .foregroundColor(DSColors.textPrimary)
                    .monospacedDigit()
                unitMenu()
            }
        }
        .padding(.horizontal, DSSpacing.smd)
        .padding(.vertical, DSSpacing.xs)
        .frame(minHeight: 64)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.md, style: .continuous)
                .fill(DSColors.surface)
        )
    }

    private func macroRow(title: String, value: Double, color: Color) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.dsSubheadline)
                .foregroundColor(DSColors.textSecondary)
            Spacer()
            Text(formatMacro(value))
                .font(.dsHeadline)
                .foregroundColor(DSColors.textPrimary)
                .monospacedDigit()
        }
        .frame(minHeight: 30)
    }

    private func formatMacro(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))g" : String(format: "%.1fg", value)
    }
}

// MARK: - Sheet content

struct NutritionSheetView: View {
    @State private var items: [EditableItem]
    private let baseNutrition: NutritionData?
    private let onSave: (NutritionData) -> Void
    private let onClose: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isSaving = false
    @State private var selectedPage = 0

    private let dragThreshold: CGFloat = 100

    init(
        items: [NutritionItem],
        blockText: String,
        baseNutrition: NutritionData?,
        onSave: @escaping (NutritionData) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.baseNutrition = baseNutrition
        self.onSave = onSave
        self.onClose = onClose
        _items = State(initialValue: Self.buildEditableItems(items: items, blockText: blockText, base: baseNutrition))
    }

    private var totalCalories: Int {
        items.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            header
            pageIndicator
                .padding(.bottom, DSSpacing.sm)

            TabView(selection: $selectedPage) {
                ForEach(loopedPageIndices, id: \.self) { page in
                    ItemCard(item: itemBinding(at: realItemIndex(for: page)), isDisabled: isSaving)
                        .padding(.horizontal, DSSpacing.lg)
                        .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 410)
            .padding(.bottom, DSSpacing.xs)

            saveButton
                .padding(.horizontal, DSSpacing.lg)
                .padding(.bottom, DSSpacing.mlg)
                .padding(.top, DSSpacing.xs)
        }
        .onAppear {
            selectedPage = 0
        }
        .onChange(of: selectedPage) { page in
            wrapLoopedPageIfNeeded(page)
        }
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.xxl, style: .continuous)
                .fill(DSColors.surface)
                .shadow(color: DSColors.shadowMedium, radius: 1, x: 0, y: 0)
        )
        .offset(y: max(0, dragOffset))
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    if value.translation.height > 0,
                       abs(value.translation.height) > abs(value.translation.width) {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    isDragging = false
                    let velocity = value.predictedEndLocation.y - value.location.y
                    let mostlyVertical = abs(value.translation.height) > abs(value.translation.width)
                    if mostlyVertical && (dragOffset > dragThreshold || velocity > 300) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = UIScreen.main.bounds.height
                        } completion: { onClose() }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
    }

    private var loopedPageIndices: [Int] {
        guard items.count > 1 else { return [0] }
        return [-1] + Array(items.indices) + [items.count]
    }

    private var selectedItemIndex: Int {
        realItemIndex(for: selectedPage)
    }

    private func realItemIndex(for page: Int) -> Int {
        guard !items.isEmpty else { return 0 }
        if page < 0 { return items.count - 1 }
        if page >= items.count { return 0 }
        return page
    }

    private func itemBinding(at index: Int) -> Binding<EditableItem> {
        Binding(
            get: { items[index] },
            set: { items[index] = $0 }
        )
    }

    private func wrapLoopedPageIfNeeded(_ page: Int) {
        guard items.count > 1, page == -1 || page == items.count else { return }
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedPage = page == -1 ? items.count - 1 : 0
            }
        }
    }

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: DSCornerRadius.full)
            .fill(DSColors.textSecondary.opacity(0.2))
            .frame(width: 48, height: 3)
            .padding(.top, DSSpacing.smd)
            .padding(.bottom, DSSpacing.mlg)
    }

    private var header: some View {
        VStack(spacing: DSSpacing.xxs) {
            HStack {
                Text(itemCountText)
                    .dsTypography(.subheadline)
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline) {
                Text("\(totalCalories)")
                    .font(.dsLargeNumber)
                    .foregroundColor(DSColors.primary)
                    .monospacedDigit()

                Text("kcal total")
                    .font(.dsSubheadline)
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.bottom, DSSpacing.sm)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(DSColors.primary.opacity(index == selectedItemIndex ? 1 : 0.22))
                    .frame(maxWidth: .infinity)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .frame(maxWidth: .infinity)
        .opacity(items.count > 1 ? 1 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: selectedItemIndex)
    }

    private var itemCountText: String {
        "\(items.count) \(items.count == 1 ? "item" : "items")"
    }

    private var saveButton: some View {
        Button(action: performSave) {
            HStack(spacing: DSSpacing.xs) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                Text("Save")
                    .font(Font.dsCustom(weight: .medium, size: 17))
            }
            .foregroundColor(DSColors.textInverted)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule(style: .continuous).fill(DSColors.primary))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    private func performSave() {
        guard !isSaving else { return }
        isSaving = true

        let nutritionItems = items.map { $0.toNutritionItem() }
        let sumD: (KeyPath<NutritionItem, Double?>) -> Double = { kp in
            nutritionItems.reduce(0.0) { $0 + ($1[keyPath: kp] ?? 0) }
        }
        let totalWeight = nutritionItems.compactMap { $0.weight }.reduce(0, +)

        let nutrition = NutritionData(
            calories: totalCalories,
            protein: sumD(\.protein),
            fat: sumD(\.fat),
            carbs: sumD(\.carbs),
            fiber: sumD(\.fiber),
            sugar: sumD(\.sugar),
            sodium: sumD(\.sodium),
            weight: totalWeight > 0 ? totalWeight : baseNutrition?.weight,
            metric_description: baseNutrition?.metric_description,
            confidence: baseNutrition?.confidence,
            userModified: true,
            items: nutritionItems
        )

        onSave(nutrition)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                dragOffset = UIScreen.main.bounds.height
            } completion: {
                onClose()
            }
        }
    }

    /// Builds the editable list. When the block has no AI item breakdown (old
    /// entries, manual blocks), synthesize a single item from the block totals so
    /// the UI is consistent and editable everywhere.
    private static func buildEditableItems(items: [NutritionItem], blockText: String, base: NutritionData?) -> [EditableItem] {
        if !items.isEmpty {
            return items.map { item in
                EditableItem(
                    name: item.name,
                    sourceText: item.source_text,
                    quantity: item.quantity,
                    caloriesText: item.calories.map(String.init) ?? "",
                    weightText: item.weight.map { formatWeight($0) } ?? "",
                    weightUnit: .grams,
                    protein: item.protein,
                    fat: item.fat,
                    carbs: item.carbs,
                    fiber: item.fiber,
                    sugar: item.sugar,
                    sodium: item.sodium,
                    metricDescription: item.metric_description,
                    confidence: item.confidence,
                    baseCalories: item.calories ?? 0,
                    baseWeight: item.weight,
                    baseProtein: item.protein,
                    baseFat: item.fat,
                    baseCarbs: item.carbs,
                    baseFiber: item.fiber,
                    baseSugar: item.sugar,
                    baseSodium: item.sodium
                )
            }
        }

        let name = cleanedName(from: blockText)
        return [
            EditableItem(
                name: name,
                sourceText: blockText.isEmpty ? nil : blockText,
                quantity: nil,
                caloriesText: base?.calories.map(String.init) ?? "",
                weightText: base?.weight.map { formatWeight($0) } ?? "",
                weightUnit: .grams,
                protein: base?.protein,
                fat: base?.fat,
                carbs: base?.carbs,
                fiber: base?.fiber,
                sugar: base?.sugar,
                sodium: base?.sodium,
                metricDescription: base?.metric_description,
                confidence: base?.confidence,
                baseCalories: base?.calories ?? 0,
                baseWeight: base?.weight,
                baseProtein: base?.protein,
                baseFat: base?.fat,
                baseCarbs: base?.carbs,
                baseFiber: base?.fiber,
                baseSugar: base?.sugar,
                baseSodium: base?.sodium
            )
        ]
    }

    private static func cleanedName(from blockText: String) -> String {
        let firstLine = blockText
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? blockText
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Item" }
        return trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : trimmed
    }

    private static func formatWeight(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Full-screen overlay container

struct NutritionSheetContainer: View {
    let items: [NutritionItem]
    let blockText: String
    let baseNutrition: NutritionData?
    let onSave: (NutritionData) -> Void
    let onDismiss: () -> Void

    @State private var popupOffset: CGFloat = UIScreen.main.bounds.height

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                gradient: Gradient(colors: [
                    DSColors.primary.opacity(0.6),
                    DSColors.primary.opacity(0)
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()
            .onTapGesture { dismiss() }

            NutritionSheetView(
                items: items,
                blockText: blockText,
                baseNutrition: baseNutrition,
                onSave: onSave,
                onClose: dismiss
            )
            .padding(.horizontal, DSSpacing.md)
            .padding(.bottom, DSSpacing.md)
            .offset(y: popupOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                popupOffset = 0
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            popupOffset = UIScreen.main.bounds.height
        } completion: {
            onDismiss()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NutritionSheet_Previews: PreviewProvider {
    static var previews: some View {
        let multi = [
            NutritionItem(name: "Flat white", source_text: "flat white", quantity: 1, calories: 120, protein: 7, fat: 6, carbs: 10, fiber: 0, sugar: 9, sodium: 60, weight: 180, metric_description: "1 cup", confidence: 0.9),
            NutritionItem(name: "Cappuccino", source_text: "cappuccino", quantity: 1, calories: 110, protein: 6, fat: 5, carbs: 9, fiber: 0, sugar: 8, sodium: 55, weight: 160, metric_description: "1 cup", confidence: 0.9)
        ]

        Group {
            ZStack {
                DSColors.background.ignoresSafeArea()
                NutritionSheetContainer(items: multi, blockText: "Flat white and cappuccino", baseNutrition: nil, onSave: { _ in }, onDismiss: {})
            }
            .previewDisplayName("Multi item")

            ZStack {
                DSColors.background.ignoresSafeArea()
                NutritionSheetContainer(
                    items: [],
                    blockText: "Chicken burger",
                    baseNutrition: NutritionData(calories: 500, protein: 25, fat: 28, carbs: 40, fiber: 3, sugar: 8, sodium: 900, weight: 250, metric_description: "1 burger", confidence: 0.8),
                    onSave: { _ in },
                    onDismiss: {}
                )
            }
            .previewDisplayName("Single (synthesized)")
        }
    }
}
#endif
