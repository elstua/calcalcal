import SwiftUI

// MARK: - Design System Configuration
/// Central configuration struct that holds all customizable design system settings.
/// This allows context-specific overrides via the SwiftUI environment.
///
/// Usage:
/// ```swift
/// // Apply custom card style to a subtree
/// SomeView()
///     .dsCardStyle(.compact)
///
/// // Override primary color in a section
/// SomeView()
///     .environment(\.dsConfiguration.colors.primaryColor, .green)
/// ```

// MARK: - Main Configuration
/// Root configuration containing all design system settings
struct DSConfiguration {
    var colors = ColorsConfiguration()
    var typography = TypographyConfiguration()
    var cards = CardsConfiguration()
    var buttons = ButtonsConfiguration()
    var spacing = SpacingConfiguration()
    
    // MARK: - Colors Configuration
    struct ColorsConfiguration {
        var primaryColor: Color = DSColors.primary
        var secondaryColor: Color = DSColors.secondary
        var errorColor: Color = DSColors.error
        var successColor: Color = DSColors.success
        var warningColor: Color = DSColors.warning
    }
    
    // MARK: - Typography Configuration
    struct TypographyConfiguration {
        var defaultStyle: DSTypographyStyle = .body
        var useCustomFonts: Bool = true  // Set to false to fall back to system fonts
    }
    
    // MARK: - Cards Configuration
    struct CardsConfiguration {
        var defaultStyle: DSCardStyle = .standard
        var primaryCornerRadius: CGFloat = DSCornerRadius.cardPrimary
        var standardCornerRadius: CGFloat = DSCornerRadius.card
        var compactCornerRadius: CGFloat = DSCornerRadius.cardCompact
        var showShadows: Bool = true
    }
    
    // MARK: - Buttons Configuration
    struct ButtonsConfiguration {
        var defaultSize: DSButtonSize = .regular
        var cornerRadius: CGFloat = DSCornerRadius.button
        var showPressAnimation: Bool = true
    }
    
    // MARK: - Spacing Configuration
    struct SpacingConfiguration {
        var baseUnit: CGFloat = DSSpacing.base
        var screenPadding: CGFloat = DSSpacing.screenPadding
        var cardPadding: CGFloat = DSSpacing.cardPadding
    }
}

// MARK: - Default Instance
extension DSConfiguration {
    /// The default design system configuration
    static let `default` = DSConfiguration()
}
