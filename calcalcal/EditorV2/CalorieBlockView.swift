import UIKit
import SwiftUI

final class CalorieBlockView: UIView, UIPopoverPresentationControllerDelegate {
    private let label = UILabel()
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
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .systemGray
        label.textAlignment = .right
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        addSubview(label)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
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
        hostingController.preferredContentSize = CGSize(width: 240, height: 356)
        hostingController.modalPresentationStyle = .popover

        if let popover = hostingController.popoverPresentationController {
            popover.sourceView = self
            popover.sourceRect = bounds
            popover.permittedArrowDirections = []
            popover.delegate = self
        }

        presentingViewController.present(hostingController, animated: true)
    }

    // MARK: - UIPopoverPresentationControllerDelegate

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none // This ensures it's always a popover, even on iPhone.
    }
}
