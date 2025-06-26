import UIKit
import Foundation


// MARK: - TextKit 2 Compatibility Extensions

@available(iOS 16.0, *)
extension NSTextRange {
    func range(offsetBy characterRange: NSRange) -> NSTextRange? {
        // This is a simplified implementation - in a real app you'd want more robust range conversion
        return self
    }
}

/// Custom text view for unified block-based editing
class UnifiedTextView: UITextView, NSTextStorageDelegate, UITextViewDelegate {
    
    // MARK: - Components
    
    private(set) var unifiedContentStorage: UnifiedTextContentStorage!
    private(set) var unifiedLayoutManager: UnifiedTextLayoutManager!
    
    // MARK: - State tracking
    
    /// Track if exclusion paths need updating
    internal var needsExclusionPathUpdate = true
    
    /// Track current block structure to avoid unnecessary updates
    internal var currentBlockStructure: String = ""
    
    /// Dictionary to store image placeholder views by image reference UUID
    internal var imageViews: [UUID: UIView] = [:]
    
    /// Dictionary to store block background views by paragraph range
    internal var blockBackgroundViews: [String: UIView] = [:]
    
    /// Track last update time to throttle rapid updates
    internal var lastUpdateTime: TimeInterval = 0
    
    /// Minimum time between updates (in seconds) to prevent excessive processing
    internal let updateThrottleInterval: TimeInterval = 0.016 // ~60fps
    
    // MARK: - Configuration
    
    /// Default block spacing for new blocks
    var defaultBlockSpacing: CGFloat = 16.0 {
        didSet {
            unifiedLayoutManager?.defaultBlockSpacing = defaultBlockSpacing
            setNeedsDisplay()
        }
    }
    
    /// The default height for the invisible spacer
    var defaultSpacerHeight: CGFloat = 24.0
    
    // MARK: - Initialization
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupComponents()
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupComponents()
        setupView()
    }
    
    deinit {
        // Clean up image views
        for (_, imageView) in imageViews {
            imageView.removeFromSuperview()
        }
        imageViews.removeAll()
        
        // Clean up block background views
        for (_, backgroundView) in blockBackgroundViews {
            backgroundView.removeFromSuperview()
        }
        blockBackgroundViews.removeAll()
    }
    
    private func setupComponents() {
        // Create our custom components
        unifiedContentStorage = UnifiedTextContentStorage()
        unifiedLayoutManager = UnifiedTextLayoutManager()
        
        // Store reference to our text storage
        unifiedContentStorage.textStorage = self.textStorage
        
        // Set up text storage delegate to monitor changes
        self.textStorage.delegate = self
    }
    
    private func setupView() {
        // Configure text container
        textContainer.lineFragmentPadding = 16
        textContainer.widthTracksTextView = true
        
        // Configure appearance
        backgroundColor = .systemBackground
        font = UIFont.systemFont(ofSize: 16)
        textColor = .label
        
        // Enable editing
        isEditable = true
        isSelectable = true
        
        // Add padding
        textContainerInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        
        // Set up delegate
        delegate = self
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Only update exclusion paths if needed or on layout changes
        if needsExclusionPathUpdate {
            updateExclusionPaths()
            updateImageViews()
            updateBlockBackgroundViews()
            needsExclusionPathUpdate = false
        }
    }
    
    // MARK: - Drawing
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // Additional drawing for calorie labels
        drawCalorieLabels(in: rect)
    }
    
    // MARK: - Caret Rect Customization
    override func caretRect(for position: UITextPosition) -> CGRect {
        var rect = super.caretRect(for: position)
        if let font = self.font {
            rect.size.height = font.lineHeight
        }
        return rect
    }
    
    // MARK: - UIResponder Standard Edit Actions
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Enable standard actions
        if action == #selector(copy(_:)) ||
            action == #selector(cut(_:)) ||
            action == #selector(paste(_:)) ||
            action == #selector(select(_:)) ||
            action == #selector(selectAll(_:)) {
            return true
        }
        // Fallback to super for other actions
        return super.canPerformAction(action, withSender: sender)
    }
    
    // MARK: - Helper Methods
    
    // MARK: - UITextViewDelegate
    
    /// Mapping from imageReference UUID to UIImage for image blocks
    public var imageMap: [UUID: UIImage] = [:]
} 
