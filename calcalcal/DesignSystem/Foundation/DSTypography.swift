import SwiftUI

// MARK: - Design System Typography
/// Centralized typography system using InstrumentSans font family.
/// Provides consistent text styles throughout the app.
///
/// Usage:
/// ```swift
/// Text("Welcome")
///     .font(.dsTitle1)
///
/// // Or using the view modifier:
/// Text("Hello")
///     .dsTypography(.headline)
/// ```

// MARK: - Font Names
/// Internal font name constants matching the registered fonts in Info.plist
private enum DSFontName {
    static let regular = "InstrumentSans-Regular"
    static let medium = "InstrumentSans-Medium"
    static let semiBold = "InstrumentSans-SemiBold"
    static let bold = "InstrumentSans-Bold"
    static let condensedRegular = "InstrumentSansCondensed-Regular"
    static let condensedMedium = "InstrumentSansCondensed-Medium"
}

// MARK: - Typography Styles
/// All available typography styles in the design system
enum DSTypographyStyle {
    /// 34pt Bold - For large headings and hero text
    case display
    
    /// 28pt Bold - Primary section titles
    case title1
    
    /// 22pt SemiBold - Secondary section titles
    case title2
    
    /// 20pt SemiBold - Card headers, tertiary titles
    case title3
    
    /// 17pt SemiBold - List headers, emphasized content
    case headline
    
    /// 17pt Regular - Default body text
    case body
    
    /// 17pt Medium - Emphasized body text
    case bodyEmphasized
    
    /// 16pt Regular - Secondary content, callouts
    case callout
    
    /// 15pt Regular - Metadata, timestamps
    case subheadline
    
    /// 13pt Regular - Small supporting text
    case footnote
    
    /// 12pt Regular - Tiny labels, badges
    case caption
    
    /// 12pt Medium - Emphasized tiny labels
    case captionEmphasized
    
    // MARK: - Special Styles
    
    /// 48pt Bold Condensed - Large numbers (calories display)
    case largeNumber
    
    /// 24pt Medium - Medium numbers
    case mediumNumber
    
    /// 17pt Medium Condensed - Compact numbers
    case compactNumber
}

// MARK: - Font Extension
/// Static font properties for easy access
extension Font {
    
    // MARK: - Standard Styles
    
    /// 34pt Bold - For large headings
    static let dsDisplay = Font.custom(DSFontName.bold, size: 34)
    
    /// 28pt Bold - Primary section titles
    static let dsTitle1 = Font.custom(DSFontName.bold, size: 28)
    
    /// 22pt SemiBold - Secondary section titles
    static let dsTitle2 = Font.custom(DSFontName.semiBold, size: 22)
    
    /// 20pt SemiBold - Card headers
    static let dsTitle3 = Font.custom(DSFontName.semiBold, size: 20)
    
    /// 17pt SemiBold - List headers
    static let dsHeadline = Font.custom(DSFontName.semiBold, size: 17)
    
    /// 17pt Regular - Default body text
    static let dsBody = Font.custom(DSFontName.regular, size: 17)
    
    /// 17pt Medium - Emphasized body text
    static let dsBodyEmphasized = Font.custom(DSFontName.medium, size: 17)
    
    /// 16pt Regular - Secondary content
    static let dsCallout = Font.custom(DSFontName.regular, size: 16)
    
    /// 15pt Regular - Metadata
    static let dsSubheadline = Font.custom(DSFontName.regular, size: 15)
    
    /// 13pt Regular - Small text
    static let dsFootnote = Font.custom(DSFontName.regular, size: 13)
    
    /// 12pt Regular - Tiny text
    static let dsCaption = Font.custom(DSFontName.regular, size: 12)
    
    /// 12pt Medium - Emphasized tiny text
    static let dsCaptionEmphasized = Font.custom(DSFontName.medium, size: 12)
    
    // MARK: - Special Styles
    
    /// 48pt Bold Condensed - Large calorie numbers
    static let dsLargeNumber = Font.custom(DSFontName.condensedMedium, size: 48)
    
    /// 24pt Medium - Medium numbers
    static let dsMediumNumber = Font.custom(DSFontName.medium, size: 24)
    
    /// 17pt Medium Condensed - Compact numbers
    static let dsCompactNumber = Font.custom(DSFontName.condensedMedium, size: 17)
    
    // MARK: - Custom Size Helper
    
    /// Creates a custom font with the specified weight and size
    static func dsCustom(weight: DSFontWeight, size: CGFloat) -> Font {
        return Font.custom(weight.fontName, size: size)
    }
}

// MARK: - Font Weight
/// Available font weights in the InstrumentSans family
enum DSFontWeight {
    case regular
    case medium
    case semiBold
    case bold
    case condensedRegular
    case condensedMedium
    
    var fontName: String {
        switch self {
        case .regular:
            return DSFontName.regular
        case .medium:
            return DSFontName.medium
        case .semiBold:
            return DSFontName.semiBold
        case .bold:
            return DSFontName.bold
        case .condensedRegular:
            return DSFontName.condensedRegular
        case .condensedMedium:
            return DSFontName.condensedMedium
        }
    }
}

// MARK: - View Modifier
/// Applies the design system typography style to a view
struct DSTypographyModifier: ViewModifier {
    let style: DSTypographyStyle
    
    func body(content: Content) -> some View {
        content.font(font(for: style))
    }
    
    private func font(for style: DSTypographyStyle) -> Font {
        switch style {
        case .display:
            return .dsDisplay
        case .title1:
            return .dsTitle1
        case .title2:
            return .dsTitle2
        case .title3:
            return .dsTitle3
        case .headline:
            return .dsHeadline
        case .body:
            return .dsBody
        case .bodyEmphasized:
            return .dsBodyEmphasized
        case .callout:
            return .dsCallout
        case .subheadline:
            return .dsSubheadline
        case .footnote:
            return .dsFootnote
        case .caption:
            return .dsCaption
        case .captionEmphasized:
            return .dsCaptionEmphasized
        case .largeNumber:
            return .dsLargeNumber
        case .mediumNumber:
            return .dsMediumNumber
        case .compactNumber:
            return .dsCompactNumber
        }
    }
}

// MARK: - View Extension
extension View {
    
    /// Applies a design system typography style to the view
    ///
    /// Usage:
    /// ```swift
    /// Text("Hello World")
    ///     .dsTypography(.headline)
    /// ```
    func dsTypography(_ style: DSTypographyStyle) -> some View {
        modifier(DSTypographyModifier(style: style))
    }
}

// MARK: - Line Height Configuration
/// Recommended line heights for each typography style (for custom layouts)
extension DSTypographyStyle {
    
    /// The recommended line height for this typography style
    var lineHeight: CGFloat {
        switch self {
        case .display:
            return 41
        case .title1:
            return 34
        case .title2:
            return 28
        case .title3:
            return 25
        case .headline, .body, .bodyEmphasized:
            return 22
        case .callout:
            return 21
        case .subheadline:
            return 20
        case .footnote:
            return 18
        case .caption, .captionEmphasized:
            return 16
        case .largeNumber:
            return 52
        case .mediumNumber:
            return 29
        case .compactNumber:
            return 22
        }
    }
    
    /// The recommended letter spacing for this typography style
    var letterSpacing: CGFloat {
        switch self {
        case .display:
            return 0.4
        case .title1:
            return 0.36
        case .title2:
            return 0.35
        case .title3:
            return 0.38
        case .headline:
            return -0.41
        case .body, .bodyEmphasized:
            return -0.41
        case .callout:
            return -0.32
        case .subheadline:
            return -0.24
        case .footnote:
            return -0.08
        case .caption, .captionEmphasized:
            return 0
        case .largeNumber, .mediumNumber, .compactNumber:
            return -0.5
        }
    }
}
