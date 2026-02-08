import UIKit
import SwiftUI

// MARK: - Design System UIKit Bridge
/// Use these when you need design system colors or typography inside UIKit views
/// (e.g. UITextView, UILabel). They stay in sync with the SwiftUI design system.
///
/// **Why this file exists:** The design system is built around SwiftUI types (`Color`, `Font`).
/// UIKit uses `UIColor` and `UIFont`. This bridge exposes the same semantic tokens so
/// UIKit code (like `BlockEditorTextView`) can match the rest of the app.

// MARK: - UIColor (Design System)
extension UIColor {

    /// Primary text color – use for main editor/content text in UIKit.
    static var dsTextPrimary: UIColor { UIColor(DSColors.textPrimary) }

    /// Placeholder or hint text.
    static var dsTextPlaceholder: UIColor { UIColor(DSColors.textPlaceholder) }

    /// Secondary text (supporting content).
    static var dsTextSecondary: UIColor { UIColor(DSColors.textSecondary) }

    /// Main app background (for consistency with SwiftUI screens).
    static var dsBackground: UIColor { UIColor(DSColors.background) }

    /// Surface color (cards, elevated content).
    static var dsSurface: UIColor { UIColor(DSColors.surface) }
}
