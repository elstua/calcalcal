import SwiftUI

// MARK: - Design System Button
/// Reusable button component with consistent styling across the app.
///
/// Usage:
/// ```swift
/// DSButton("Sign In", style: .primary) {
///     // action
/// }
///
/// DSButton("Settings", icon: "gear", style: .secondary) {
///     // action
/// }
/// ```

// MARK: - Button Style
/// Available button style variants
enum DSButtonStyle {
    /// Filled button with primary color - for main CTAs
    case primary
    
    /// Outlined button - for secondary actions
    case secondary
    
    /// Red filled/outlined button - for destructive actions (delete, sign out)
    case destructive
    
    /// Text-only button - for subtle/tertiary actions
    case text
    
    /// Ghost button - minimal styling, just text
    case ghost
    
    // MARK: - Style Properties
    
    var backgroundColor: Color {
        switch self {
        case .primary:
            return DSColors.primary
        case .secondary:
            return .clear
        case .destructive:
            return DSColors.error
        case .text, .ghost:
            return .clear
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary:
            return DSColors.textInverted
        case .secondary:
            return DSColors.primary
        case .destructive:
            return DSColors.textInverted
        case .text:
            return DSColors.primary
        case .ghost:
            return DSColors.textSecondary
        }
    }
    
    var borderColor: Color? {
        switch self {
        case .secondary:
            return DSColors.primary
        case .primary, .destructive, .text, .ghost:
            return nil
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .secondary:
            return 1.5
        default:
            return 0
        }
    }
    
    var cornerRadius: CGFloat {
        return DSCornerRadius.button  // 8pt
    }
}

// MARK: - Button Size
/// Available button sizes
enum DSButtonSize {
    /// Small button for compact layouts
    case small
    
    /// Regular button (default)
    case regular
    
    /// Large button for prominent CTAs
    case large
    
    var verticalPadding: CGFloat {
        switch self {
        case .small:
            return DSSpacing.xs  // 4pt
        case .regular:
            return DSSpacing.smd  // 12pt
        case .large:
            return DSSpacing.md  // 16pt
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return DSSpacing.sm  // 8pt
        case .regular:
            return DSSpacing.md  // 16pt
        case .large:
            return DSSpacing.lg  // 24pt
        }
    }
    
    var font: Font {
        switch self {
        case .small:
            return .dsSubheadline
        case .regular:
            return .dsBodyEmphasized
        case .large:
            return .dsHeadline
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .small:
            return 14
        case .regular:
            return 17
        case .large:
            return 20
        }
    }
}

// MARK: - DSButton View
/// A styled button component
struct DSButton: View {
    let title: String
    let icon: String?
    let iconPosition: IconPosition
    let style: DSButtonStyle
    let size: DSButtonSize
    let isFullWidth: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    enum IconPosition {
        case leading
        case trailing
    }
    
    /// Creates a button with the specified configuration
    /// - Parameters:
    ///   - title: The button text
    ///   - icon: Optional SF Symbol name
    ///   - iconPosition: Where to place the icon (leading or trailing)
    ///   - style: Visual style variant
    ///   - size: Size variant
    ///   - isFullWidth: Whether button should expand to fill width
    ///   - isLoading: Shows loading indicator instead of content
    ///   - isDisabled: Disables interaction and dims appearance
    ///   - action: Closure to execute on tap
    init(
        _ title: String,
        icon: String? = nil,
        iconPosition: IconPosition = .leading,
        style: DSButtonStyle = .primary,
        size: DSButtonSize = .regular,
        isFullWidth: Bool = false,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.iconPosition = iconPosition
        self.style = style
        self.size = size
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if !isLoading && !isDisabled {
                action()
            }
        }) {
            HStack(spacing: DSSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                        .tint(style.foregroundColor)
                } else {
                    if let icon = icon, iconPosition == .leading {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize, weight: .medium))
                    }
                    
                    Text(title)
                        .font(size.font)
                    
                    if let icon = icon, iconPosition == .trailing {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize, weight: .medium))
                    }
                }
            }
            .foregroundColor(isDisabled ? DSColors.disabled : style.foregroundColor)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .fill(isDisabled ? DSColors.disabled.opacity(0.3) : style.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .strokeBorder(
                        isDisabled ? DSColors.disabled : (style.borderColor ?? .clear),
                        lineWidth: style.borderWidth
                    )
            )
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Icon-Only Button
/// A button that displays only an icon
struct DSIconButton: View {
    let icon: String
    let style: DSButtonStyle
    let size: DSButtonSize
    let isDisabled: Bool
    let action: () -> Void
    
    init(
        icon: String,
        style: DSButtonStyle = .ghost,
        size: DSButtonSize = .regular,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.size = size
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundColor(isDisabled ? DSColors.disabled : style.foregroundColor)
                .frame(width: DSSpacing.minTouchTarget, height: DSSpacing.minTouchTarget)
                .background(
                    Circle()
                        .fill(style.backgroundColor)
                )
        }
        .disabled(isDisabled)
    }
}

// MARK: - Button Style Extensions for Native SwiftUI Buttons
/// Custom ButtonStyle implementations for use with standard SwiftUI Buttons

struct DSPrimaryButtonStyle: ButtonStyle {
    let size: DSButtonSize
    let isFullWidth: Bool
    
    init(size: DSButtonSize = .regular, isFullWidth: Bool = false) {
        self.size = size
        self.isFullWidth = isFullWidth
    }
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundColor(DSColors.textInverted)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.button, style: .continuous)
                    .fill(DSColors.primary)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DSSecondaryButtonStyle: ButtonStyle {
    let size: DSButtonSize
    let isFullWidth: Bool
    
    init(size: DSButtonSize = .regular, isFullWidth: Bool = false) {
        self.size = size
        self.isFullWidth = isFullWidth
    }
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundColor(DSColors.primary)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.button, style: .continuous)
                    .strokeBorder(DSColors.primary, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DSDestructiveButtonStyle: ButtonStyle {
    let size: DSButtonSize
    let isFullWidth: Bool
    
    init(size: DSButtonSize = .regular, isFullWidth: Bool = false) {
        self.size = size
        self.isFullWidth = isFullWidth
    }
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundColor(DSColors.error)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - View Extension for Button Styles
extension View {
    
    /// Applies primary button styling
    func dsPrimaryButton(size: DSButtonSize = .regular, isFullWidth: Bool = false) -> some View {
        self.buttonStyle(DSPrimaryButtonStyle(size: size, isFullWidth: isFullWidth))
    }
    
    /// Applies secondary button styling
    func dsSecondaryButton(size: DSButtonSize = .regular, isFullWidth: Bool = false) -> some View {
        self.buttonStyle(DSSecondaryButtonStyle(size: size, isFullWidth: isFullWidth))
    }
    
    /// Applies destructive button styling
    func dsDestructiveButton(size: DSButtonSize = .regular, isFullWidth: Bool = false) -> some View {
        self.buttonStyle(DSDestructiveButtonStyle(size: size, isFullWidth: isFullWidth))
    }
}

// MARK: - Configuration
extension DSButton {
    
    /// Configuration for environment-based button customization
    struct Configuration {
        var primaryColor: Color = DSColors.primary
        var destructiveColor: Color = DSColors.error
        var defaultSize: DSButtonSize = .regular
    }
}

// MARK: - Previews
#if DEBUG
struct DSButton_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: DSSpacing.lg) {
                // Primary Buttons
                Group {
                    Text("Primary Buttons")
                        .dsTypography(.headline)
                    
                    DSButton("Sign In", style: .primary, action: {})
                    DSButton("Continue", icon: "arrow.right", iconPosition: .trailing, style: .primary, action: {})
                    DSButton("Full Width", style: .primary, isFullWidth: true, action: {})
                }
                
                Divider()
                
                // Secondary Buttons
                Group {
                    Text("Secondary Buttons")
                        .dsTypography(.headline)
                    
                    DSButton("Settings", style: .secondary, action: {})
                    DSButton("Sync Now", icon: "arrow.triangle.2.circlepath", style: .secondary, action: {})
                }
                
                Divider()
                
                // Destructive Buttons
                Group {
                    Text("Destructive Buttons")
                        .dsTypography(.headline)
                    
                    DSButton("Sign Out", style: .destructive, action: {})
                    DSButton("Delete Account", icon: "trash", style: .destructive, action: {})
                }
                
                Divider()
                
                // Text Buttons
                Group {
                    Text("Text Buttons")
                        .dsTypography(.headline)
                    
                    DSButton("Learn More", style: .text, action: {})
                    DSButton("Skip", style: .ghost, action: {})
                }
                
                Divider()
                
                // States
                Group {
                    Text("States")
                        .dsTypography(.headline)
                    
                    DSButton("Loading...", style: .primary, isLoading: true, action: {})
                    DSButton("Disabled", style: .primary, isDisabled: true, action: {})
                }
                
                Divider()
                
                // Icon Buttons
                Group {
                    Text("Icon Buttons")
                        .dsTypography(.headline)
                    
                    HStack(spacing: DSSpacing.md) {
                        DSIconButton(icon: "xmark", action: {})
                        DSIconButton(icon: "gear", style: .secondary, action: {})
                        DSIconButton(icon: "heart.fill", style: .primary, action: {})
                    }
                }
            }
            .padding(DSSpacing.md)
        }
        .background(DSColors.background)
    }
}
#endif
