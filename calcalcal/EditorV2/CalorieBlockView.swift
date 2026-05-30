import SwiftUI
import UIKit

final class CalorieBlockView: UIView {
    static let loadingToken = "__calcalcal_analysis_loading__"

    private let label = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var lastText: String?
    private static weak var activeMenuHost: UIViewController?

    // Context menu data
    private var currentCalories: Int = 0
    private var currentWeight: Double?
    private var currentNutrition: NutritionData?
    private var blockID: BlockID?

    // Callbacks
    private var onCalorieUpdate: ((Int?, Double?, BlockID) -> Void)?
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
        label.font = UIFont.dsBody
        label.textColor = .dsTextSecondary
        label.textAlignment = .right
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        addSubview(label)

        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .dsTextSecondary
        addSubview(activityIndicator)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
        let side = min(bounds.height, 18)
        activityIndicator.frame = CGRect(
            x: bounds.maxX - side,
            y: bounds.midY - (side / 2.0),
            width: side,
            height: side
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let target = label.sizeThatFits(size)
        return CGSize(width: target.width, height: max(20, target.height))
    }

    override var intrinsicContentSize: CGSize {
        sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
    }

    func setCaloriesAnimated(_ text: String) {
        guard text != lastText else { return }
        lastText = text
        if text == Self.loadingToken {
            label.text = nil
            label.alpha = 0
            activityIndicator.startAnimating()
            return
        }

        activityIndicator.stopAnimating()
        label.alpha = 1
        if window != nil {
            UIView.transition(with: label, duration: 0.15, options: .transitionCrossDissolve, animations: {
                self.label.text = text
            }, completion: nil)
        } else {
            label.text = text
        }
    }

    // MARK: - Context Menu Configuration

    func configureContextMenu(
        calories: Int,
        weight: Double? = nil,
        nutrition: NutritionData?,
        blockID: BlockID,
        presentingViewController: UIViewController,
        onUpdate: @escaping (Int?, Double?, BlockID) -> Void
    ) {
        self.currentCalories = calories
        // Use weight from nutrition data if available, otherwise use the weight parameter
        self.currentWeight = nutrition?.weight ?? weight
        self.currentNutrition = nutrition
        self.blockID = blockID
        self.presentingViewController = presentingViewController
        self.onCalorieUpdate = onUpdate
    }

    @objc private func handleTap() {
        guard lastText != Self.loadingToken else { return }
        guard let presentingViewController = presentingViewController,
              let blockID = blockID else { return }

        dismissActiveContextMenu()

        let sourceFrame = convert(bounds, to: presentingViewController.view)
        let overlay = CalorieContextMenuOverlayView(
            sourceFrame: sourceFrame,
            calories: currentCalories,
            weight: currentWeight,
            nutrition: currentNutrition,
            onDismiss: {
                Self.dismissActiveContextMenu()
            },
            onUpdate: { [weak self] updatedCalories, updatedWeight in
                self?.onCalorieUpdate?(updatedCalories, updatedWeight, blockID)
            }
        )

        let hostingController = UIHostingController(rootView: overlay)
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
        dismissActiveContextMenu()
    }
}

private struct CalorieContextMenuOverlayView: View {
    let sourceFrame: CGRect
    let calories: Int
    let weight: Double?
    let nutrition: NutritionData?
    let onDismiss: () -> Void
    let onUpdate: (Int?, Double?) -> Void

    private let cardSize = CGSize(width: 320, height: 404)
    private let edgePadding: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let frame = menuFrame(in: proxy.size, safeAreaInsets: proxy.safeAreaInsets)

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)

                CalorieContextMenuView(
                    calories: calories,
                    weight: weight,
                    nutrition: nutrition,
                    onDismiss: onDismiss,
                    onUpdate: onUpdate
                )
                .frame(width: cardSize.width, height: cardSize.height, alignment: .top)
                .position(x: frame.midX, y: frame.midY)
            }
        }
        .background(Color.clear)
    }

    private func menuFrame(in containerSize: CGSize, safeAreaInsets: EdgeInsets) -> CGRect {
        let minX = safeAreaInsets.leading + edgePadding
        let maxX = containerSize.width - safeAreaInsets.trailing - edgePadding - cardSize.width
        let minY = safeAreaInsets.top + edgePadding
        let maxY = containerSize.height - safeAreaInsets.bottom - edgePadding - cardSize.height

        let proposedX = sourceFrame.maxX - cardSize.width
        let proposedY = sourceFrame.midY - 112

        return CGRect(
            x: proposedX.clamped(to: minX...max(minX, maxX)),
            y: proposedY.clamped(to: minY...max(minY, maxY)),
            width: cardSize.width,
            height: cardSize.height
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
