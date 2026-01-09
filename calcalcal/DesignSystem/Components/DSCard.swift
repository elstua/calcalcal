import SwiftUI

// MARK: - Design System Card
/// Reusable card component with consistent styling across the app.
/// Cards are the primary container for content in CalCalCal.
///
/// Usage:
/// ```swift
/// DSCard(.primary) {
///     Text("Today's Entry")
/// }
///
/// DSCard(.standard) {
///     VStack {
///         Text("Breakfast")
///         Text("500 cal")
///     }
/// }
/// ```

// MARK: - Card Style
/// Available card style variants
enum DSCardStyle {
    /// Large cards with prominent shadow - for today's entry, featured content
    case primary
    
    /// Standard cards with subtle shadow - for list items, diary entries
    case standard
    
    /// Compact cards with minimal shadow - for info sections, settings
    case compact
    
    /// Flat cards with no shadow - for embedded content
    case flat
    
    // MARK: - Style Properties
    
    var cornerRadius: CGFloat {
        switch self {
        case .primary:
            return DSCornerRadius.cardPrimary  // 24pt
        case .standard:
            return DSCornerRadius.card  // 16pt
        case .compact:
            return DSCornerRadius.cardCompact  // 12pt
        case .flat:
            return DSCornerRadius.md  // 12pt
        }
    }
    
    var shadow: DSShadow {
        switch self {
        case .primary:
            return .medium
        case .standard:
            return .small
        case .compact:
            return .subtle
        case .flat:
            return .none
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .primary, .standard:
            return DSColors.surface
        case .compact:
            return DSColors.surfaceSecondary
        case .flat:
            return .clear
        }
    }
    
    var padding: CGFloat {
        switch self {
        case .primary:
            return DSSpacing.lg
        case .standard:
            return DSSpacing.md
        case .compact, .flat:
            return DSSpacing.smd
        }
    }
}

// MARK: - DSCard View
/// A container view that applies card styling to its content
struct DSCard<Content: View>: View {
    let style: DSCardStyle
    let content: Content
    
    /// Creates a card with the specified style and content
    /// - Parameters:
    ///   - style: The visual style of the card
    ///   - content: The content to display inside the card
    init(
        _ style: DSCardStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(style.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .fill(style.backgroundColor)
                    .dsShadow(style.shadow)
            )
    }
}

// MARK: - Card Modifier
/// A view modifier that applies card styling to any view
struct DSCardModifier: ViewModifier {
    let style: DSCardStyle
    let includePadding: Bool
    
    func body(content: Content) -> some View {
        Group {
            if includePadding {
                content.padding(style.padding)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(style.backgroundColor)
                .dsShadow(style.shadow)
        )
    }
}

extension View {
    
    /// Applies card styling to the view
    ///
    /// Usage:
    /// ```swift
    /// VStack {
    ///     Text("Content")
    /// }
    /// .dsCard(.standard)
    /// ```
    func dsCard(_ style: DSCardStyle = .standard, includePadding: Bool = true) -> some View {
        modifier(DSCardModifier(style: style, includePadding: includePadding))
    }
}

// MARK: - Specialized Card Variants

/// A card specifically designed for list items
struct DSListItemCard<Content: View>: View {
    let content: Content
    let isHighlighted: Bool
    
    init(
        isHighlighted: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.isHighlighted = isHighlighted
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.card, style: .continuous)
                    .fill(DSColors.surface)
                    .dsShadow(isHighlighted ? .medium : .small)
            )
    }
}

/// A card for info/settings sections
struct DSInfoCard<Content: View>: View {
    let content: Content
    let tintColor: Color?
    
    init(
        tintColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tintColor = tintColor
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.cardCompact, style: .continuous)
                    .fill(tintColor?.opacity(0.1) ?? DSColors.surfaceSecondary)
            )
    }
}

// MARK: - Card Header Component
/// A standardized card header with title and optional subtitle/action
struct DSCardHeader: View {
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let actionLabel: String?
    
    init(
        title: String,
        subtitle: String? = nil,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionLabel = actionLabel
        self.action = action
    }
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(title)
                    .dsTypography(.headline)
                    .foregroundColor(DSColors.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .dsTypography(.subheadline)
                        .foregroundColor(DSColors.textSecondary)
                }
            }
            
            Spacer()
            
            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                        .dsTypography(.subheadline)
                        .foregroundColor(DSColors.primary)
                }
            }
        }
    }
}

// MARK: - Configuration
extension DSCard {
    
    /// Configuration for environment-based card customization
    struct Configuration {
        var defaultStyle: DSCardStyle = .standard
        var primaryBackgroundColor: Color = DSColors.surface
        var standardBackgroundColor: Color = DSColors.surface
        var compactBackgroundColor: Color = DSColors.surfaceSecondary
    }
}

// MARK: - Previews
#if DEBUG
struct DSCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: DSSpacing.lg) {
                // Primary Card
                DSCard(.primary) {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Today")
                            .dsTypography(.title2)
                        Text("Write what you ate today")
                            .dsTypography(.body)
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                
                // Standard Card
                DSCard(.standard) {
                    HStack {
                        Text("Breakfast")
                            .dsTypography(.headline)
                        Spacer()
                        Text("450 cal")
                            .dsTypography(.bodyEmphasized)
                            .foregroundColor(DSColors.primary)
                    }
                }
                
                // Compact Card
                DSCard(.compact) {
                    DSCardHeader(
                        title: "Health Information",
                        subtitle: "From Apple Health"
                    )
                }
                
                // Info Card with tint
                DSInfoCard(tintColor: .orange) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Temporary Account")
                            .dsTypography(.headline)
                    }
                }
            }
            .padding(DSSpacing.md)
        }
        .background(DSColors.backgroundSecondary)
    }
}
#endif
