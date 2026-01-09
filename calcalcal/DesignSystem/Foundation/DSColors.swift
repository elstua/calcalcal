import SwiftUI
import UIKit

// MARK: - Design System Colors
/// Centralized color tokens for the CalCalCal app.
/// All colors are semantic and adapt to light/dark mode automatically.
///
/// Usage:
/// ```swift
/// Text("Hello")
///     .foregroundColor(DSColors.textPrimary)
///
/// Rectangle()
///     .fill(DSColors.background)
/// ```

struct DSColors {
    
    // MARK: - Brand Colors
    // These are placeholder colors - replace with your actual brand colors later
    
    /// Primary brand color - used for main actions, links, and emphasis
    static let primary = Color.blue
    
    /// Secondary brand color - used for accents and highlights
    static let secondary = Color.orange
    
    /// Accent color for special highlights (calories, achievements)
    static let accent = Color.green
    
    // MARK: - Background Colors
    // These adapt automatically to light/dark mode
    
    /// Main background color for the app
    static let background = Color(hex: 0xEDECE8)  // RGB: 237, 236, 232 - warm off-white
    
    /// Secondary background for grouped content (like list sections)
    static let backgroundSecondary = Color(uiColor: .systemGroupedBackground)
    
    /// Tertiary background for nested grouped content
    static let backgroundTertiary = Color(uiColor: .secondarySystemGroupedBackground)
    
    /// Surface color for cards and elevated content
    static let surface = Color(uiColor: .systemBackground)
    
    /// Subtle surface color for info sections
    static let surfaceSecondary = Color(uiColor: .systemGray6)
    
    // MARK: - Semantic Colors
    // Used to communicate meaning (success, error, etc.)
    
    /// Success state - positive actions, confirmations
    static let success = Color.green
    
    /// Warning state - caution, attention needed
    static let warning = Color.orange
    
    /// Error/destructive state - errors, delete actions, sign out
    static let error = Color.red
    
    /// Info state - neutral informational content
    static let info = Color.blue
    
    // MARK: - Text Colors
    // These match iOS text hierarchy and adapt to light/dark mode
    
    /// Primary text - most important content
    static let textPrimary = Color.primary
    
    /// Secondary text - supporting content, labels
    static let textSecondary = Color.secondary
    
    /// Tertiary text - least important content, hints
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    
    /// Placeholder text - empty states, placeholders
    static let textPlaceholder = Color(uiColor: .placeholderText)
    
    /// Inverted text - for use on dark backgrounds
    static let textInverted = Color.white
    
    // MARK: - Separator Colors
    
    /// Default separator color
    static let separator = Color(uiColor: .separator)
    
    /// Opaque separator for when transparency isn't desired
    static let separatorOpaque = Color(uiColor: .opaqueSeparator)
    
    // MARK: - Interactive Colors
    // Colors for interactive elements
    
    /// Link color
    static let link = Color.blue
    
    /// Disabled state color
    static let disabled = Color(uiColor: .systemGray3)
    
    // MARK: - Shadow Colors
    
    /// Light shadow for subtle elevation
    static let shadowLight = Color.black.opacity(0.04)
    
    /// Medium shadow for cards
    static let shadowMedium = Color.black.opacity(0.08)
    
    /// Heavy shadow for prominent elements
    static let shadowHeavy = Color.black.opacity(0.15)
    
    // MARK: - Overlay Colors
    
    /// Light overlay for dimming backgrounds
    static let overlayLight = Color.black.opacity(0.2)
    
    /// Medium overlay for modal backgrounds
    static let overlayMedium = Color.black.opacity(0.4)
    
    /// Heavy overlay for focus states
    static let overlayHeavy = Color.black.opacity(0.6)
}

// MARK: - Configuration
// Environment-based color configuration for context-specific overrides

extension DSColors {
    
    /// Configuration struct for environment-based color overrides
    struct Configuration {
        var primaryColor: Color = DSColors.primary
        var secondaryColor: Color = DSColors.secondary
        var accentColor: Color = DSColors.accent
    }
}

// MARK: - Color Convenience Extensions

extension Color {
    
    /// Creates a color with the given hex value
    /// Usage: Color(hex: 0xFF5733)
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
