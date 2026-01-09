# CalCalCal Design System

A modular SwiftUI design system for the CalCalCal iOS app, providing consistent colors, typography, spacing, and reusable components.

## Table of Contents

- [Structure](#structure)
- [Foundation](#foundation)
  - [Colors](#colors)
  - [Typography](#typography)
  - [Spacing](#spacing)
- [Components](#components)
  - [Cards](#cards)
  - [Buttons](#buttons)
- [Configuration](#configuration)
- [Migration Guide](#migration-guide)

---

## Structure

```
DesignSystem/
├── Foundation/
│   ├── DSColors.swift          # Color tokens
│   ├── DSTypography.swift      # Typography styles (InstrumentSans)
│   └── DSSpacing.swift         # Spacing, corner radius, shadows
├── Components/
│   ├── DSCard.swift            # Card components
│   └── DSButton.swift          # Button components
└── Configuration/
    ├── DSConfiguration.swift   # Central configuration
    └── DSEnvironment.swift     # SwiftUI environment integration
```

---

## Foundation

### Colors

All colors are semantic and automatically adapt to light/dark mode.

#### Color Categories

| Category | Token | Usage |
|----------|-------|-------|
| **Brand** | `DSColors.primary` | Main CTAs, links, emphasis |
| | `DSColors.secondary` | Accents, highlights |
| | `DSColors.accent` | Special highlights (achievements) |
| **Background** | `DSColors.background` | Main app background |
| | `DSColors.backgroundSecondary` | Grouped content |
| | `DSColors.surface` | Cards, elevated content |
| **Semantic** | `DSColors.success` | Positive states |
| | `DSColors.warning` | Caution states |
| | `DSColors.error` | Errors, destructive actions |
| **Text** | `DSColors.textPrimary` | Main content |
| | `DSColors.textSecondary` | Supporting content |
| | `DSColors.textTertiary` | Hints, placeholders |

#### Usage

```swift
Text("Hello")
    .foregroundColor(DSColors.textPrimary)

Rectangle()
    .fill(DSColors.background)
```

---

### Typography

Uses the **InstrumentSans** font family with a consistent type scale.

#### Type Scale

| Style | Size/Weight | Usage |
|-------|-------------|-------|
| `display` | 34pt Bold | Hero headings |
| `title1` | 28pt Bold | Section titles |
| `title2` | 22pt SemiBold | Subsection titles |
| `title3` | 20pt SemiBold | Card headers |
| `headline` | 17pt SemiBold | List headers |
| `body` | 17pt Regular | Default text |
| `bodyEmphasized` | 17pt Medium | Emphasized body |
| `callout` | 16pt Regular | Secondary content |
| `subheadline` | 15pt Regular | Metadata |
| `footnote` | 13pt Regular | Small text |
| `caption` | 12pt Regular | Tiny labels |
| `largeNumber` | 48pt Condensed | Calorie displays |

#### Usage

```swift
// Using Font extension
Text("Welcome")
    .font(.dsTitle1)

// Using view modifier
Text("Hello World")
    .dsTypography(.headline)

// Custom size with specific weight
Text("Custom")
    .font(.dsCustom(weight: .semiBold, size: 18))
```

---

### Spacing

Based on a 4pt grid system for visual consistency.

#### Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| `xxs` | 2pt | Micro spacing |
| `xs` | 4pt | Extra small |
| `sm` | 8pt | Small |
| `smd` | 12pt | Small-medium |
| `md` | 16pt | Medium (default) |
| `mlg` | 20pt | Medium-large |
| `lg` | 24pt | Large |
| `xl` | 32pt | Extra large |
| `xxl` | 40pt | Double extra large |

#### Corner Radius

| Token | Value | Usage |
|-------|-------|-------|
| `DSCornerRadius.sm` | 8pt | Buttons, inputs |
| `DSCornerRadius.md` | 12pt | Compact cards |
| `DSCornerRadius.lg` | 16pt | Standard cards |
| `DSCornerRadius.xxl` | 24pt | Primary cards |

#### Shadows

| Token | Usage |
|-------|-------|
| `DSShadow.subtle` | Minimal elevation |
| `DSShadow.small` | Buttons, inputs |
| `DSShadow.medium` | Cards |
| `DSShadow.large` | Prominent cards |

#### Usage

```swift
VStack(spacing: DSSpacing.md) {
    // content
}
.padding(DSSpacing.lg)

// Semantic spacing
.dsScreenPadding()
.dsCardPadding()

// Shadows
RoundedRectangle(cornerRadius: DSCornerRadius.card)
    .dsShadow(.medium)
```

---

## Components

### Cards

Standardized card containers for consistent content presentation.

#### Card Styles

| Style | Corner Radius | Shadow | Usage |
|-------|--------------|--------|-------|
| `.primary` | 24pt | Medium | Today's entry, featured |
| `.standard` | 16pt | Small | List items, diary entries |
| `.compact` | 12pt | Subtle | Info sections, settings |
| `.flat` | 12pt | None | Embedded content |

#### Usage

```swift
// Using DSCard component
DSCard(.primary) {
    VStack {
        Text("Today")
            .dsTypography(.title2)
        Text("Write what you ate")
            .dsTypography(.body)
    }
}

// Using view modifier
VStack {
    Text("Content")
}
.dsCard(.standard)

// Specialized cards
DSListItemCard {
    HStack {
        Text("Breakfast")
        Spacer()
        Text("450 cal")
    }
}

DSInfoCard(tintColor: .orange) {
    Text("Warning message")
}

// Card header component
DSCardHeader(
    title: "Health Information",
    subtitle: "From Apple Health",
    actionLabel: "Edit",
    action: { }
)
```

---

### Buttons

Styled button components with multiple variants.

#### Button Styles

| Style | Appearance | Usage |
|-------|------------|-------|
| `.primary` | Filled blue | Main CTAs |
| `.secondary` | Outlined | Secondary actions |
| `.destructive` | Red | Delete, sign out |
| `.text` | Text only | Tertiary actions |
| `.ghost` | Subtle text | Minimal actions |

#### Button Sizes

| Size | Vertical Padding | Usage |
|------|-----------------|-------|
| `.small` | 4pt | Compact layouts |
| `.regular` | 12pt | Default |
| `.large` | 16pt | Prominent CTAs |

#### Usage

```swift
// DSButton component
DSButton("Sign In", style: .primary) {
    // action
}

DSButton(
    "Continue",
    icon: "arrow.right",
    iconPosition: .trailing,
    style: .primary,
    isFullWidth: true
) {
    // action
}

DSButton("Delete", style: .destructive, isLoading: isDeleting) {
    // action
}

// Icon-only button
DSIconButton(icon: "xmark") {
    dismiss()
}

// Using button styles with standard SwiftUI Button
Button("Submit") { }
    .dsPrimaryButton(isFullWidth: true)

Button("Cancel") { }
    .dsSecondaryButton()
```

---

## Configuration

The design system can be customized via SwiftUI environment.

### Environment Modifiers

```swift
// Override card style for a subtree
VStack {
    DSCard { ... }  // Will use .compact
}
.dsCardStyle(.compact)

// Override button size
VStack {
    DSButton("Small") { }  // Will use .small
}
.dsButtonSize(.small)

// Override primary color
ContentView()
    .dsPrimaryColor(.green)

// Disable shadows in a section
SettingsView()
    .dsDisableShadows()
```

### Reading Configuration

```swift
struct MyView: View {
    @Environment(\.dsConfiguration) var config
    @Environment(\.dsCardStyle) var cardStyle
    
    var body: some View {
        // Use config.colors.primaryColor, etc.
    }
}
```

---

## Migration Guide

Replace hardcoded values with design system tokens incrementally.

### Colors

```swift
// Before
.foregroundColor(.blue)
.background(Color(.systemGray6))

// After
.foregroundColor(DSColors.primary)
.background(DSColors.surfaceSecondary)
```

### Typography

```swift
// Before
.font(.system(size: 17, weight: .semibold))
.font(.title2).fontWeight(.semibold)

// After
.font(.dsHeadline)
.dsTypography(.title2)
```

### Spacing

```swift
// Before
.padding(16)
.cornerRadius(12)

// After
.padding(DSSpacing.md)
.cornerRadius(DSCornerRadius.md)
```

### Cards

```swift
// Before
ZStack {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    content
}

// After
DSCard(.primary) {
    content
}
```

### Buttons

```swift
// Before
Button("Sign Out") { }
    .foregroundColor(.red)

// After
DSButton("Sign Out", style: .destructive) { }
```

### Shadows

```swift
// Before
.shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

// After
.dsShadow(.medium)
```

---

## Quick Reference

### Import

All design system components are available without explicit imports within the app target.

### Common Patterns

```swift
// Standard card with content
DSCard(.standard) {
    VStack(alignment: .leading, spacing: DSSpacing.sm) {
        Text("Title")
            .dsTypography(.headline)
        Text("Description")
            .dsTypography(.body)
            .foregroundColor(DSColors.textSecondary)
    }
}

// Full-width primary button
DSButton("Continue", style: .primary, isFullWidth: true) {
    // action
}

// Info section
DSInfoCard(tintColor: .orange) {
    HStack(spacing: DSSpacing.sm) {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.orange)
        Text("Important message")
            .dsTypography(.subheadline)
    }
}
```

---

## Updating Brand Colors

When you're ready to replace placeholder colors with your actual brand colors:

1. Open `DSColors.swift`
2. Update the brand color values:

```swift
// Replace these with your brand colors
static let primary = Color(hex: 0xYOUR_HEX)
static let secondary = Color(hex: 0xYOUR_HEX)
static let accent = Color(hex: 0xYOUR_HEX)
```

All components using these tokens will automatically update.
