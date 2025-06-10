# Unified Text Editor: Architecture & Logic Overview

## Introduction

The Unified Text Editor is a custom text editing component designed for iOS, combining the flexibility of UIKit's text system with a block-based editing experience. It is built to support advanced features such as block metadata, custom spacing, calorie overlays, and future extensibility for images and rich text.

---

## Core Approach

- **Block-Based Editing:** Each paragraph is treated as a distinct block, allowing for individual metadata, custom layout, and visual separation.
- **UIKit Foundation:** Built on top of TextKit 1 (UIKit), ensuring stability and native performance.
- **Custom Metadata & Drawing:** Uses custom storage and drawing logic to manage block attributes and visual presentation, without relying on complex or unstable frameworks.

---

## Architecture

```mermaid
flowchart TD
    A[UnifiedTextContentStorage<br/>(Metadata Management)]
    B[UnifiedTextView<br/>(UITextView + Custom Drawing)]
    C[UnifiedTextLayoutManager<br/>(Layout Helpers)]
    D[UnifiedTextEditor<br/>(SwiftUI Wrapper)]

    A --> B
    B --> C
    B --> D
```

### Components

- **UnifiedTextContentStorage**
  - Manages metadata for each block (type, spacing, calorie data, etc.)
  - Works alongside standard NSTextStorage for text content.
- **UnifiedTextView**
  - Subclass of `UITextView` with custom drawing for block backgrounds, separators, and overlays.
  - Exposes APIs for block management and visual updates.
- **UnifiedTextLayoutManager**
  - Provides layout calculations and drawing helpers (e.g., for calorie labels, block spacing).
- **UnifiedTextEditor**
  - SwiftUI wrapper for seamless integration in SwiftUI apps.
  - Exposes configuration via view modifiers.

---

## Logic & Features

- **Block Detection:** Paragraphs are automatically detected using NSString methods and treated as blocks.
- **Metadata Management:** Each block can store custom attributes (e.g., calorie count, block type).
- **Custom Drawing:** Visual separation and overlays (like calorie labels) are rendered via custom drawing in the text view.
- **Configurable Spacing:** Visual spacing between blocks is managed independently of text layout.
- **SwiftUI Integration:** The editor can be used as a SwiftUI view, supporting state binding and event callbacks.

---

## Extensibility & Next Steps

- **Image Support:** Planned support for image-text blocks with flexible layouts (e.g., 30/70 split).
- **Calorie Integration:** Deeper connection with calorie calculation systems.
- **Block Interactions:** Tap/long-press gestures for block-level actions.
- **Rich Text:** Formatting options like bold, italic, etc.
- **Performance:** Ongoing optimization for large documents.

---

## Usage Example

```swift
struct MyView: View {
    @State private var text = "Hello, World!"

    var body: some View {
        UnifiedTextEditor(text: $text)
            .blockSpacing(20)
            .onTextChange { newText in
                print("Text changed: \(newText)")
            }
    }
}
```

---

## Demo

To see the editor in action, run `UnifiedEditorDemoView`. The demo showcases:
- Multiple text blocks
- Block counter
- Add/remove block functionality
- Visual block separation and spacing 