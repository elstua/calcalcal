import SwiftUI

// MARK: - Design System Spacing
/// Centralized spacing constants using a 4pt base unit grid system.
/// All spacing values are multiples of 4 for visual consistency.
///
/// Usage:
/// ```swift
/// VStack(spacing: DSSpacing.md) {
///     // content
/// }
/// .padding(DSSpacing.lg)
/// ```

struct DSSpacing {
    
    // MARK: - Base Unit
    /// The base unit for the spacing system (4 points)
    static let base: CGFloat = 4
    
    // MARK: - Spacing Scale
    
    /// 2pt - Micro spacing for tight layouts
    static let xxs: CGFloat = 2
    
    /// 4pt - Extra small spacing
    static let xs: CGFloat = 4
    
    /// 8pt - Small spacing
    static let sm: CGFloat = 8
    
    /// 12pt - Small-medium spacing
    static let smd: CGFloat = 12
    
    /// 16pt - Medium spacing (default)
    static let md: CGFloat = 16
    
    /// 20pt - Medium-large spacing
    static let mlg: CGFloat = 20
    
    /// 24pt - Large spacing
    static let lg: CGFloat = 24
    
    /// 32pt - Extra large spacing
    static let xl: CGFloat = 32
    
    /// 40pt - Double extra large spacing
    static let xxl: CGFloat = 40
    
    /// 48pt - Triple extra large spacing
    static let xxxl: CGFloat = 48
    
    /// 64pt - Huge spacing for major sections
    static let huge: CGFloat = 64
    
    // MARK: - Semantic Spacing
    // Named spacing for specific use cases
    
    /// Padding inside cards and containers
    static let cardPadding: CGFloat = md
    
    /// Padding for screen edges
    static let screenPadding: CGFloat = md
    
    /// Spacing between list items
    static let listItemSpacing: CGFloat = sm
    
    /// Spacing between sections
    static let sectionSpacing: CGFloat = lg
    
    /// Spacing between form fields
    static let formFieldSpacing: CGFloat = smd
    
    /// Spacing between icon and text
    static let iconTextSpacing: CGFloat = sm
    
    /// Minimum touch target size (44pt as per Apple HIG)
    static let minTouchTarget: CGFloat = 44
}

// MARK: - Corner Radius
/// Standardized corner radius values for consistent rounded corners
struct DSCornerRadius {
    
    /// 4pt - Subtle rounding for small elements
    static let xs: CGFloat = 4
    
    /// 8pt - Small rounding for buttons, inputs
    static let sm: CGFloat = 8
    
    /// 12pt - Medium rounding for compact cards
    static let md: CGFloat = 12
    
    /// 16pt - Large rounding for standard cards
    static let lg: CGFloat = 16
    
    /// 20pt - Extra large rounding
    static let xl: CGFloat = 20
    
    /// 24pt - Full rounding for primary cards
    static let xxl: CGFloat = 24
    
    /// Fully rounded (circle/pill shape)
    static let full: CGFloat = .infinity
    
    // MARK: - Semantic Radii
    
    /// For small buttons and tags
    static let button: CGFloat = sm
    
    /// For standard cards in list
    static let card: CGFloat = lg
    
    /// For primary/featured cards
    static let cardPrimary: CGFloat = xxl
    
    /// For compact info sections
    static let cardCompact: CGFloat = md
    
    /// For input fields
    static let input: CGFloat = sm
    
    /// For avatar images
    static let avatar: CGFloat = full
}

// MARK: - Shadow Configurations
/// Standardized shadow styles for elevation
struct DSShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    // MARK: - Predefined Shadows
    
    /// No shadow
    static let none = DSShadow(color: .clear, radius: 0, x: 0, y: 0)
    
    /// Subtle shadow for minimal elevation
    static let subtle = DSShadow(
        color: DSColors.shadowLight,
        radius: 2,
        x: 0,
        y: 1
    )
    
    /// Small shadow for buttons and inputs
    static let small = DSShadow(
        color: DSColors.shadowLight,
        radius: 4,
        x: 0,
        y: 2
    )
    
    /// Medium shadow for cards
    static let medium = DSShadow(
        color: DSColors.shadowMedium,
        radius: 8,
        x: 0,
        y: 4
    )
    
    /// Large shadow for prominent cards
    static let large = DSShadow(
        color: DSColors.shadowMedium,
        radius: 12,
        x: 0,
        y: 6
    )
    
    /// Extra large shadow for modals and overlays
    static let xlarge = DSShadow(
        color: DSColors.shadowHeavy,
        radius: 20,
        x: 0,
        y: 10
    )
}

// MARK: - View Extension for Shadows
extension View {
    
    /// Applies a design system shadow to the view
    ///
    /// Usage:
    /// ```swift
    /// RoundedRectangle(cornerRadius: DSCornerRadius.card)
    ///     .dsShadow(.medium)
    /// ```
    func dsShadow(_ shadow: DSShadow) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
}

// MARK: - Padding Extensions
extension View {
    
    /// Applies horizontal padding using design system spacing
    func dsPaddingHorizontal(_ spacing: CGFloat = DSSpacing.md) -> some View {
        self.padding(.horizontal, spacing)
    }
    
    /// Applies vertical padding using design system spacing
    func dsPaddingVertical(_ spacing: CGFloat = DSSpacing.md) -> some View {
        self.padding(.vertical, spacing)
    }
    
    /// Applies screen edge padding
    func dsScreenPadding() -> some View {
        self.padding(.horizontal, DSSpacing.screenPadding)
    }
    
    /// Applies card internal padding
    func dsCardPadding() -> some View {
        self.padding(DSSpacing.cardPadding)
    }
}
