import UIKit
import SwiftUI

final class CalorieBlockView: UIView, UIPopoverPresentationControllerDelegate {
    static let loadingToken = "__calcalcal_analysis_loading__"

    private let label = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var lastText: String?

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

        let calorieContextMenu = CalorieContextMenuView(
            calories: currentCalories,
            weight: currentWeight,
            nutrition: currentNutrition
        ) { updatedCalories, updatedWeight in
            self.onCalorieUpdate?(updatedCalories, updatedWeight, blockID)
        }

        let hostingController = UIHostingController(rootView: calorieContextMenu)
        hostingController.view.backgroundColor = .clear
        hostingController.preferredContentSize = CGSize(width: 320, height: 404)
        hostingController.modalPresentationStyle = .popover

        if let popover = hostingController.popoverPresentationController {
            popover.sourceView = self
            popover.sourceRect = bounds
            popover.permittedArrowDirections = []
            popover.backgroundColor = .clear
            popover.delegate = self
        }

        presentingViewController.present(hostingController, animated: true)
    }

    // MARK: - UIPopoverPresentationControllerDelegate

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none // This ensures it's always a popover, even on iPhone.
    }
}
