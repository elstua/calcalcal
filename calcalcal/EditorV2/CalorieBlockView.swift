import SwiftUI
import UIKit

final class CalorieBlockView: UIView {
    static let loadingToken = "__calcalcal_analysis_loading__"

    private let label = UILabel()
    private let typingLoader = TypingDotsLoaderView()
    private var chipViews: [NutritionBurstChipView] = []
    private var pendingChipWorkItems: [DispatchWorkItem] = []
    private var lastText: String?
    private static weak var activeMenuHost: UIViewController?

    // Context menu data
    private var currentCalories: Int = 0
    private var currentWeight: Double?
    private var currentNutrition: NutritionData?
    private var blockText: String = ""
    private var blockID: BlockID?

    // Callbacks
    private var onSave: ((NutritionData, BlockID) -> Void)?
    private var presentingViewController: UIViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        isUserInteractionEnabled = true
        clipsToBounds = false
        label.font = UIFont(name: "InstrumentSansCondensed-Medium", size: 24) ?? .systemFont(ofSize: 24, weight: .medium)
        label.textColor = UIColor(DSColors.primary)
        label.textAlignment = .right
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.72
        addSubview(label)

        typingLoader.alpha = 0
        addSubview(typingLoader)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
        let loaderSize = typingLoader.intrinsicContentSize
        typingLoader.frame = CGRect(
            x: bounds.maxX - loaderSize.width,
            y: bounds.midY - (loaderSize.height / 2.0),
            width: loaderSize.width,
            height: loaderSize.height
        )
        layoutChipViews()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let target = label.sizeThatFits(size)
        return CGSize(width: target.width, height: max(20, target.height))
    }

    override var intrinsicContentSize: CGSize {
        sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
    }

    func setCaloriesAnimated(_ text: String) {
        let previousText = lastText
        guard text != lastText else { return }
        lastText = text
        if text == Self.loadingToken {
            label.text = nil
            label.alpha = 0
            typingLoader.startAnimating()
            cancelNutritionBurst()
            return
        }

        typingLoader.stopAnimating()
        label.alpha = 1
        if window != nil {
            UIView.transition(with: label, duration: 0.15, options: .transitionCrossDissolve, animations: {
                self.label.text = text
            }, completion: nil)
        } else {
            label.text = text
        }

        if shouldShowNutritionBurst(previousText: previousText, newText: text) {
            showNutritionBurst()
        }
    }

    // MARK: - Context Menu Configuration

    func configureContextMenu(
        calories: Int,
        weight: Double? = nil,
        nutrition: NutritionData?,
        blockText: String,
        blockID: BlockID,
        presentingViewController: UIViewController,
        onSave: @escaping (NutritionData, BlockID) -> Void
    ) {
        self.currentCalories = calories
        // Use weight from nutrition data if available, otherwise use the weight parameter
        self.currentWeight = nutrition?.weight ?? weight
        self.currentNutrition = nutrition
        self.blockText = blockText
        self.blockID = blockID
        self.presentingViewController = presentingViewController
        self.onSave = onSave
    }

    private func shouldShowNutritionBurst(previousText: String?, newText: String) -> Bool {
        guard newText != Self.loadingToken else { return false }
        guard !nutritionBurstChips().isEmpty else { return false }
        return previousText == Self.loadingToken || (previousText != nil && previousText != newText)
    }

    private func showNutritionBurst() {
        cancelNutritionBurst()

        let chips = nutritionBurstChips()
        guard !chips.isEmpty else { return }

        chipViews = chips.map { chip in
            let view = NutritionBurstChipView(chip: chip)
            view.alpha = 0
            addSubview(view)
            return view
        }
        setNeedsLayout()
        layoutIfNeeded()

        for (index, view) in chipViews.enumerated() {
            let showDelay = Double(index) * 0.11
            let hideDelay = 1.2 + Double(index) * 0.08

            view.prepareForEntrance()
            view.transform = view.hiddenTransform
            view.layer.shadowOpacity = 0

            UIView.animate(
                withDuration: 0.34,
                delay: showDelay,
                usingSpringWithDamping: 0.82,
                initialSpringVelocity: 0.35,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: {
                    view.alpha = 1
                    view.transform = view.visibleTransform
                    view.layer.shadowOpacity = 0.12
                    view.revealFocus()
                },
                completion: nil
            )

            let hideItem = DispatchWorkItem { [weak self, weak view] in
                guard let view else { return }
                UIView.animate(
                    withDuration: 0.16,
                    delay: 0,
                    options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState],
                    animations: {
                        view.transform = view.exitTransform
                        view.layer.shadowOpacity = 0.04
                        view.blurForExit()
                    }, completion: { _ in
                        UIView.animate(
                            withDuration: 0.16,
                            delay: 0,
                            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState],
                            animations: {
                                view.alpha = 0
                                view.layer.shadowOpacity = 0
                            },
                            completion: { _ in
                                view.removeFromSuperview()
                                self?.chipViews.removeAll { $0 === view }
                            }
                        )
                    }
                )
            }
            pendingChipWorkItems.append(hideItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: hideItem)
        }
    }

    private func cancelNutritionBurst() {
        pendingChipWorkItems.forEach { $0.cancel() }
        pendingChipWorkItems.removeAll()
        chipViews.forEach { view in
            view.layer.removeAllAnimations()
            view.removeFromSuperview()
        }
        chipViews.removeAll()
    }

    private func nutritionBurstChips() -> [NutritionBurstChip] {
        guard let nutrition = currentNutrition else { return [] }

        var chips: [NutritionBurstChip] = []
        if let weight = currentWeight, weight > 0 {
            chips.append(
                NutritionBurstChip(
                    text: Self.formattedWeight(weight),
                    textColor: UIColor.dsTextPrimary,
                    backgroundColor: UIColor.dsSurface.withAlphaComponent(0.96),
                    angle: -0.14,
                    slot: .topLeading
                )
            )
        }
        if let protein = nutrition.protein, protein > 0 {
            chips.append(
                NutritionBurstChip(
                    text: "P \(Self.formattedMacro(protein))",
                    textColor: UIColor(DSColors.success),
                    backgroundColor: UIColor(DSColors.success).withAlphaComponent(0.18),
                    angle: 0.12,
                    slot: .topTrailing
                )
            )
        }
        if let fat = nutrition.fat, fat > 0 {
            chips.append(
                NutritionBurstChip(
                    text: "F \(Self.formattedMacro(fat))",
                    textColor: UIColor(DSColors.secondary),
                    backgroundColor: UIColor(DSColors.secondary).withAlphaComponent(0.16),
                    angle: 0.15,
                    slot: .bottomLeading
                )
            )
        }
        if let carbs = nutrition.carbs, carbs > 0 {
            chips.append(
                NutritionBurstChip(
                    text: "C \(Self.formattedMacro(carbs))",
                    textColor: UIColor(DSColors.info),
                    backgroundColor: UIColor(DSColors.info).withAlphaComponent(0.16),
                    angle: -0.08,
                    slot: .bottomTrailing
                )
            )
        }
        return chips
    }

    private func layoutChipViews() {
        let calorieRect = measuredCalorieTextRect()
        for view in chipViews {
            let size = view.sizeThatFits(CGSize(width: 78, height: 22))
            let origin: CGPoint
            switch view.chip.slot {
            case .topLeading:
                origin = CGPoint(x: calorieRect.minX - size.width + 12, y: calorieRect.minY - size.height + 4)
            case .topTrailing:
                origin = CGPoint(x: calorieRect.maxX - 10, y: calorieRect.minY - size.height + 2)
            case .bottomLeading:
                origin = CGPoint(x: calorieRect.minX - size.width + 18, y: calorieRect.maxY - 5)
            case .bottomTrailing:
                origin = CGPoint(x: calorieRect.maxX - size.width + 22, y: calorieRect.maxY - 6)
            }
            view.frame = CGRect(origin: origin, size: size)
        }
    }

    private func measuredCalorieTextRect() -> CGRect {
        guard let text = label.text, !text.isEmpty else { return bounds }

        let measuredSize = (text as NSString).size(withAttributes: [.font: label.font as Any])
        let width = min(bounds.width, ceil(measuredSize.width))
        let height = min(bounds.height, ceil(measuredSize.height))
        let x = bounds.maxX - width
        let y = bounds.midY - (height / 2.0)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func formattedMacro(_ value: Double) -> String {
        if value >= 10 || value.rounded() == value {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    private static func formattedWeight(_ grams: Double) -> String {
        if grams >= 1000 {
            let kilograms = grams / 1000
            let value = kilograms >= 10 || kilograms.rounded() == kilograms
                ? String(Int(kilograms.rounded()))
                : String(format: "%.1f", kilograms)
            return "\(value) kg"
        }
        return "\(Int(grams.rounded())) g"
    }

    @objc private func handleTap() {
        guard lastText != Self.loadingToken else { return }
        guard let presentingViewController = presentingViewController,
              let blockID = blockID else { return }

        dismissActiveContextMenu()

        let sheet = NutritionSheetContainer(
            items: currentNutrition?.items ?? [],
            blockText: blockText,
            baseNutrition: currentNutrition,
            onSave: { [weak self] nutrition in
                self?.onSave?(nutrition, blockID)
            },
            onDismiss: { Self.dismissActiveContextMenu() }
        )

        let hostingController = UIHostingController(rootView: sheet)
        hostingController.view.backgroundColor = .clear
        hostingController.modalPresentationStyle = .overFullScreen
        hostingController.modalTransitionStyle = .crossDissolve

        Self.activeMenuHost = hostingController
        presentingViewController.present(hostingController, animated: false)
    }

    private static func dismissActiveContextMenu() {
        guard let activeMenuHost else { return }
        self.activeMenuHost = nil
        activeMenuHost.dismiss(animated: false)
    }

private func dismissActiveContextMenu() {
        Self.dismissActiveContextMenu()
    }

    deinit {
        cancelNutritionBurst()
        dismissActiveContextMenu()
    }
}

private final class TypingDotsLoaderView: UIView {
    private let dotViews = [
        TypingLoaderDotView(),
        TypingLoaderDotView(),
        TypingLoaderDotView()
    ]
    private var isAnimating = false
    private let dotSize: CGFloat = 5
    private let dotGap: CGFloat = 4

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: dotSize * 3 + dotGap * 2, height: 18)
    }

    private func setupView() {
        isUserInteractionEnabled = false
        clipsToBounds = false
        isHidden = true
        alpha = 0

        dotViews.forEach { dotView in
            addSubview(dotView)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let totalWidth = dotSize * 3 + dotGap * 2
        var x = bounds.midX - totalWidth / 2.0
        let y = bounds.midY - dotSize / 2.0

        for dotView in dotViews {
            dotView.frame = CGRect(x: x, y: y, width: dotSize, height: dotSize)
            x += dotSize + dotGap
        }
    }

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        isHidden = false
        layer.removeAllAnimations()

        dotViews.forEach { dotView in
            dotView.layer.removeAllAnimations()
            dotView.prepareForEntrance()
        }

        alpha = 0
        transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.alpha = 1
                self.transform = .identity
                self.dotViews.forEach { $0.revealFocus() }
            },
            completion: { [weak self] _ in
                self?.startDotBounce()
            }
        )
    }

    func stopAnimating() {
        guard isAnimating || alpha > 0 else { return }
        isAnimating = false

        dotViews.forEach { dotView in
            dotView.freezePresentationState()
            dotView.blurForExit()
        }

        UIView.animate(
            withDuration: 0.14,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            },
            completion: { [weak self] _ in
                guard let self else { return }
                UIView.animate(
                    withDuration: 0.16,
                    delay: 0,
                    options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState],
                    animations: {
                        self.alpha = 0
                    },
                    completion: { _ in
                        self.dotViews.forEach { dotView in
                            dotView.layer.removeAllAnimations()
                            dotView.transform = .identity
                        }
                        self.transform = .identity
                        self.isHidden = true
                    }
                )
            }
        )
    }

    private func startDotBounce() {
        guard isAnimating else { return }
        for (index, dotView) in dotViews.enumerated() {
            dotView.startBounce(delay: Double(index) * 0.11)
        }
    }
}

private final class TypingLoaderDotView: UIView {
    private let softDot = UIView()
    private let sharpDot = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        isUserInteractionEnabled = false
        clipsToBounds = false

        softDot.backgroundColor = UIColor(DSColors.primary).withAlphaComponent(0.28)
        softDot.layer.shadowColor = UIColor(DSColors.primary).cgColor
        softDot.layer.shadowOpacity = 0.58
        softDot.layer.shadowRadius = 3
        softDot.layer.shadowOffset = .zero
        softDot.transform = CGAffineTransform(scaleX: 1.55, y: 1.55)
        addSubview(softDot)

        sharpDot.backgroundColor = UIColor(DSColors.primary)
        sharpDot.alpha = 0
        addSubview(sharpDot)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        softDot.frame = bounds
        sharpDot.frame = bounds
        softDot.layer.cornerRadius = bounds.width / 2.0
        sharpDot.layer.cornerRadius = bounds.width / 2.0
    }

    func prepareForEntrance() {
        transform = .identity
        softDot.alpha = 1
        sharpDot.alpha = 0
    }

    func revealFocus() {
        softDot.alpha = 0
        sharpDot.alpha = 1
    }

    func blurForExit() {
        softDot.alpha = 1
        sharpDot.alpha = 0
    }

    func startBounce(delay: Double) {
        layer.removeAllAnimations()
        UIView.animateKeyframes(
            withDuration: 0.78,
            delay: delay,
            options: [.repeat, .calculationModeCubic, .allowUserInteraction],
            animations: {
                UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.24) {
                    self.transform = CGAffineTransform(translationX: 0, y: -5)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.24, relativeDuration: 0.24) {
                    self.transform = .identity
                }
                UIView.addKeyframe(withRelativeStartTime: 0.48, relativeDuration: 0.52) {
                    self.transform = .identity
                }
            },
            completion: nil
        )
    }

    func freezePresentationState() {
        if let y = layer.presentation()?.value(forKeyPath: "transform.translation.y") as? CGFloat {
            transform = CGAffineTransform(translationX: 0, y: y)
        }
        layer.removeAllAnimations()
        UIView.animate(
            withDuration: 0.16,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.transform = .identity
            },
            completion: nil
        )
    }
}

private enum NutritionBurstChipSlot {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}

private struct NutritionBurstChip {
    let text: String
    let textColor: UIColor
    let backgroundColor: UIColor
    let angle: CGFloat
    let slot: NutritionBurstChipSlot
}

private final class NutritionBurstChipView: UIView {
    let chip: NutritionBurstChip

    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
    private let softLabel = UILabel()
    private let label = UILabel()
    private let horizontalPadding: CGFloat = 4
    private let verticalPadding: CGFloat = 2

    var visibleTransform: CGAffineTransform {
        CGAffineTransform(rotationAngle: chip.angle)
    }

    var hiddenTransform: CGAffineTransform {
        visibleTransform
            .translatedBy(x: 0, y: 5)
            .scaledBy(x: 0.74, y: 0.74)
    }

    var exitTransform: CGAffineTransform {
        visibleTransform
            .translatedBy(x: 0, y: -3)
            .scaledBy(x: 0.86, y: 0.86)
    }

    init(chip: NutritionBurstChip) {
        self.chip = chip
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        isUserInteractionEnabled = false
        clipsToBounds = false

        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 9
        layer.shadowOpacity = 0

        effectView.isUserInteractionEnabled = false
        effectView.clipsToBounds = true
        effectView.layer.cornerRadius = 6
        effectView.layer.cornerCurve = .continuous
        addSubview(effectView)

        configureTextLabel(softLabel)
        softLabel.alpha = 1
        softLabel.textColor = chip.textColor.withAlphaComponent(0.32)
        softLabel.layer.shadowColor = chip.textColor.cgColor
        softLabel.layer.shadowOpacity = 0.55
        softLabel.layer.shadowRadius = 2.5
        softLabel.layer.shadowOffset = .zero
        softLabel.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
        addSubview(softLabel)

        configureTextLabel(label)
        label.alpha = 0
        addSubview(label)

        backgroundColor = .clear
        effectView.contentView.backgroundColor = chip.backgroundColor
    }

    private func configureTextLabel(_ textLabel: UILabel) {
        textLabel.font = UIFont(name: "InstrumentSans-Regular", size: 12) ?? .systemFont(ofSize: 12, weight: .regular)
        textLabel.textColor = chip.textColor
        textLabel.textAlignment = .center
        textLabel.text = chip.text
        textLabel.adjustsFontSizeToFitWidth = true
        textLabel.minimumScaleFactor = 0.78
        textLabel.layer.allowsEdgeAntialiasing = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        effectView.frame = bounds
        softLabel.frame = bounds.insetBy(dx: horizontalPadding, dy: verticalPadding)
        label.frame = bounds.insetBy(dx: horizontalPadding, dy: verticalPadding)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let labelSize = label.sizeThatFits(size)
        return CGSize(
            width: min(78, max(34, labelSize.width + horizontalPadding * 2)),
            height: 22
        )
    }

    func prepareForEntrance() {
        softLabel.alpha = 1
        label.alpha = 0
    }

    func revealFocus() {
        softLabel.alpha = 0
        label.alpha = 1
    }

    func blurForExit() {
        softLabel.alpha = 1
        label.alpha = 0
    }
}

#if DEBUG
private struct CalorieBlockDebugPreview: View {
    @State private var replayToken = UUID()
    @State private var calories = 700

    var body: some View {
        VStack(spacing: 28) {
            CalorieBlockDebugRepresentable(calories: calories, replayToken: replayToken)
                .frame(width: 240, height: 132)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach([70, 700, 1200, 10000], id: \.self) { value in
                        Button(String(value)) {
                            calories = value
                            replayToken = UUID()
                        }
                        .font(.dsCaptionEmphasized)
                        .buttonStyle(.bordered)
                    }
                }

                Button("Replay chips") {
                    replayToken = UUID()
                }
                .font(.dsBodyEmphasized)
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 360, height: 260)
        .background(DSColors.background)
    }
}

private struct CalorieBlockDebugRepresentable: UIViewRepresentable {
    let calories: Int
    let replayToken: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> DebugCalorieChipContainerView {
        DebugCalorieChipContainerView()
    }

    func updateUIView(_ uiView: DebugCalorieChipContainerView, context: Context) {
        uiView.configure(calories: calories, nutrition: sampleNutrition)

        guard context.coordinator.lastReplayToken != replayToken else { return }
        context.coordinator.lastReplayToken = replayToken

        uiView.replay(calories: calories)
    }

    private var sampleNutrition: NutritionData {
        NutritionData(
            calories: calories,
            protein: 32,
            fat: 24,
            carbs: 24,
            weight: 320,
            confidence: 0.9
        )
    }

    final class Coordinator {
        var lastReplayToken: UUID?
    }
}

private final class DebugCalorieChipContainerView: UIView {
    private let calorieView = CalorieBlockView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = false
        backgroundColor = .clear
        addSubview(calorieView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        calorieView.frame = CGRect(
            x: bounds.midX - (CalorieOverlayMetrics.labelMaxWidth / 2.0),
            y: bounds.midY - (CalorieOverlayMetrics.labelHeight / 2.0),
            width: CalorieOverlayMetrics.labelMaxWidth,
            height: CalorieOverlayMetrics.labelHeight
        )
    }

    func configure(calories: Int, nutrition: NutritionData) {
        calorieView.configureContextMenu(
            calories: calories,
            weight: nutrition.weight,
            nutrition: nutrition,
            blockText: "Cheese omelette with 2 bacon slices, black coffee",
            blockID: BlockID(),
            presentingViewController: UIViewController(),
            onSave: { _, _ in }
        )
    }

    func replay(calories: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.setNeedsLayout()
            self?.layoutIfNeeded()
            self?.calorieView.setCaloriesAnimated(CalorieBlockView.loadingToken)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                self?.calorieView.setCaloriesAnimated(String(calories))
            }
        }
    }
}

#Preview("Calorie chips") {
    CalorieBlockDebugPreview()
}
#endif
