import SwiftUI

// MARK: - Design System Environment
/// SwiftUI environment keys and modifiers for design system configuration.
/// Enables context-specific customization of design system components.
///
/// Usage:
/// ```swift
/// // Read configuration in a view
/// @Environment(\.dsConfiguration) var config
///
/// // Override card style for a subtree
/// VStack {
///     // All DSCards here will use compact style
/// }
/// .dsCardStyle(.compact)
/// ```

// MARK: - Environment Keys

/// Environment key for the main design system configuration
private struct DSConfigurationKey: EnvironmentKey {
    static let defaultValue = DSConfiguration.default
}

/// Environment key for card style override
private struct DSCardStyleKey: EnvironmentKey {
    static let defaultValue: DSCardStyle = .standard
}

/// Environment key for button size override
private struct DSButtonSizeKey: EnvironmentKey {
    static let defaultValue: DSButtonSize = .regular
}

// MARK: - EnvironmentValues Extension
extension EnvironmentValues {
    
    /// The current design system configuration
    var dsConfiguration: DSConfiguration {
        get { self[DSConfigurationKey.self] }
        set { self[DSConfigurationKey.self] = newValue }
    }
    
    /// The current card style override
    var dsCardStyle: DSCardStyle {
        get { self[DSCardStyleKey.self] }
        set { self[DSCardStyleKey.self] = newValue }
    }
    
    /// The current button size override
    var dsButtonSize: DSButtonSize {
        get { self[DSButtonSizeKey.self] }
        set { self[DSButtonSizeKey.self] = newValue }
    }
}

// MARK: - View Modifiers

extension View {
    
    /// Sets the design system configuration for this view and its descendants
    ///
    /// Usage:
    /// ```swift
    /// ContentView()
    ///     .dsConfiguration(customConfig)
    /// ```
    func dsConfiguration(_ configuration: DSConfiguration) -> some View {
        environment(\.dsConfiguration, configuration)
    }
    
    /// Sets the default card style for DSCard components in this view tree
    ///
    /// Usage:
    /// ```swift
    /// VStack {
    ///     DSCard { ... }  // Will use .compact style
    ///     DSCard { ... }  // Will also use .compact style
    /// }
    /// .dsCardStyle(.compact)
    /// ```
    func dsCardStyle(_ style: DSCardStyle) -> some View {
        environment(\.dsCardStyle, style)
    }
    
    /// Sets the default button size for DSButton components in this view tree
    ///
    /// Usage:
    /// ```swift
    /// VStack {
    ///     DSButton("Small") { }  // Will use .small size
    /// }
    /// .dsButtonSize(.small)
    /// ```
    func dsButtonSize(_ size: DSButtonSize) -> some View {
        environment(\.dsButtonSize, size)
    }
    
    /// Sets the primary color throughout the design system
    ///
    /// Usage:
    /// ```swift
    /// ContentView()
    ///     .dsPrimaryColor(.green)
    /// ```
    func dsPrimaryColor(_ color: Color) -> some View {
        transformEnvironment(\.dsConfiguration) { config in
            config.colors.primaryColor = color
        }
    }
    
//    /// Sets the accent color throughout the design system
//    func dsAccentColor(_ color: Color) -> some View {
//        transformEnvironment(\.dsConfiguration) { config in
//            config.colors.accentColor = color
//        }
//    }
    
    /// Disables shadows on cards in this view tree
    func dsDisableShadows() -> some View {
        transformEnvironment(\.dsConfiguration) { config in
            config.cards.showShadows = false
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
/// A wrapper view that displays design system components with their current configuration
struct DSPreviewContainer<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(title)
                .dsTypography(.headline)
                .foregroundColor(DSColors.textSecondary)
            
            content
        }
        .padding(DSSpacing.md)
        .background(DSColors.backgroundSecondary)
    }
}
#endif

// MARK: - Environment-Aware Components
/// Extended card component that respects environment settings

struct DSEnvironmentAwareCard<Content: View>: View {
    @Environment(\.dsCardStyle) private var environmentStyle
    @Environment(\.dsConfiguration) private var config
    
    let style: DSCardStyle?
    let content: Content
    
    init(
        style: DSCardStyle? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.content = content()
    }
    
    var body: some View {
        let effectiveStyle = style ?? environmentStyle
        
        content
            .padding(effectiveStyle.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(
                    cornerRadius: effectiveStyle.cornerRadius,
                    style: .continuous
                )
                .fill(effectiveStyle.backgroundColor)
                .applyIf(config.cards.showShadows) { view in
                    view.dsShadow(effectiveStyle.shadow)
                }
            )
    }
}

// MARK: - Conditional Modifier Helper
extension View {
    /// Applies a transformation only if the condition is true
    @ViewBuilder
    func applyIf<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
