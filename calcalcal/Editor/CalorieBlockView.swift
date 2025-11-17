import UIKit

final class CalorieBlockView: UIView {
    private let label = UILabel()
    private var lastText: String?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .systemGray
        label.textAlignment = .right
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        addSubview(label)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .systemGray
        label.textAlignment = .right
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        addSubview(label)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
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
}






