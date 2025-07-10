# Unified Text Editor: Model-Driven Architecture & Logic Overview

## Introduction

The Unified Text Editor is a custom, model-driven text editing component for iOS, combining the flexibility of UIKit and SwiftUI with a block-based editing experience. All content is represented as an array of `Block` structs, supporting advanced features such as block metadata, calorie overlays, custom spacing, and extensibility for images, rich text, and more.

---

## Core Approach

- **Model-Driven Editing:** The editor's content is a Swift array of `Block` structs, each representing a logical unit (text, image, image+text, spacer, etc). All rendering, editing, and metadata are derived from this model.
- **UIKit Foundation:** Built on top of TextKit (UIKit), with custom storage, layout, and drawing logic for block-based editing.
- **SwiftUI Integration:** The editor is wrapped in a SwiftUI view (`UnifiedTextEditor`), supporting state binding and event callbacks.
- **Custom Metadata & Drawing:** Each block can store metadata (e.g., calorie data), and custom drawing logic renders overlays, backgrounds, and spacing.

---

## Architecture

```mermaid
flowchart TD
    A[BlockModel<br/>(Block & BlockType)]
    B[UnifiedTextView<br/>(UITextView + Model Rendering)]
    C[UnifiedTextContentStorage<br/>(Block Metadata)]
    D[UnifiedTextLayoutManager<br/>(Layout Helpers)]
    E[UnifiedTextEditor<br/>(SwiftUI Wrapper)]

    A --> B
    B --> C
    B --> D
    B --> E
```

### Components

- **BlockModel.swift**
  - Defines `BlockType` enum: `.text(String)`, `.image(Data, UUID)`, `.imageText(Data, UUID, String)`, `.spacer`, and extensible for more types.
  - Defines `Block` struct: `{ type: BlockType, calorieData: String? }`.
  - All editor content is an array of `Block`.
- **UnifiedTextView**
  - Subclass of `UITextView` that renders the `[Block]` model into attributed text and manages block metadata.
  - Handles block management, rendering, and synchronization with the model.
  - Custom drawing for block backgrounds, calorie overlays, and visual separation.
- **UnifiedTextContentStorage**
  - Maintains per-block metadata (type, spacing, image reference, calorie data, etc) using custom NSAttributedString attributes.
  - Provides APIs to set/get metadata for text ranges.
- **UnifiedTextLayoutManager**
  - Provides layout calculations and drawing helpers (e.g., for calorie labels, block spacing).
- **UnifiedTextEditor**
  - SwiftUI wrapper that binds to `[Block]` and synchronizes changes between the model and the view.
  - Exposes configuration via view modifiers (e.g., block spacing, onBlocksChange).

---

## Logic & Features

- **Block Model:**
  - All content is represented as `[Block]`, with each block being one of the supported types.
  - Example block types:
    - `text(String)` — plain text block
    - `image(Data, UUID)` — image block (data for model, UIImage for UI)
    - `imageText(Data, UUID, String)` — image with associated text
    - `spacer` — visual separator block
  - Each block can have optional `calorieData` and is extensible for more metadata.

- **Rendering & Metadata:**
  - The editor renders the `[Block]` array into the text storage, assigning custom metadata for each block.
  - Block backgrounds, overlays, and spacing are drawn based on block type and metadata.
  - Calorie overlays are rendered for blocks with `calorieData`.

- **Editing & Synchronization:**
  - All editing actions (insert, delete, split, merge) operate on the `[Block]` model.
  - The view parses the text storage and metadata to reconstruct `[Block]` after user edits.
  - The SwiftUI wrapper keeps the model and view in sync, supporting two-way binding.

- **Spacer Blocks:**
  - Special block type for visual separation (e.g., between text and image blocks).
  - Rendered as a full-width, 24pt-high block with a grey background.
  - Managed as a first-class block, easy to insert/delete, and always inherits correct style.
  - Used programmatically and by user action.

- **Image & ImageText Blocks:**
  - Support for image-only and image+text blocks, with flexible layouts (e.g., 30/70 split).
  - Images are stored as `Data` in the model and mapped to `UIImage` for UI rendering.
  - Each image block has a unique UUID for reference and metadata.

- **Calorie Integration:**
  - Each block can store and display calorie data as an overlay.
  - Calorie labels are positioned using layout helpers and drawn in the block background.

- **Extensibility:**
  - The architecture is designed for easy addition of new block types (e.g., checklist, table, rich text).
  - Metadata and layout logic are extensible for new features.

---

## Usage Example

```swift
struct MyView: View {
    @State private var blocks: [Block] = [
        Block(type: .text("Hello, World!"), calorieData: nil),
        Block(type: .spacer, calorieData: nil),
        Block(type: .imageText(imageData, UUID(), "Image description"), calorieData: "120")
    ]

    var body: some View {
        UnifiedTextEditor(blocks: $blocks)
            .blockSpacing(20)
            .onBlocksChange { newBlocks in
                print("Blocks changed: \(newBlocks)")
            }
    }
}
```

---

## Demo

To see the editor in action, run `UnifiedEditorDemoView`. The demo showcases:
- Multiple block types (text, image, image+text, spacer)
- Calorie overlays
- Add/remove/split/merge block functionality
- Visual block separation and spacing
- Model-driven editing and SwiftUI integration

---

## Extensibility & Next Steps

- **New Block Types:** Add support for checklists, tables, and rich text formatting.
- **Performance:** Ongoing optimization for large documents and complex layouts.
- **Block Interactions:** Tap/long-press gestures for block-level actions.
- **Deeper Calorie Integration:** Connect with calorie calculation systems and external data sources. 