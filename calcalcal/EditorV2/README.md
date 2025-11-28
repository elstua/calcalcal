# EditorV2 – TextKit 2 Block Editor

## 1. High-level Goals

- **True block semantics**: each paragraph/image behaves as its own block with independent spacing and visual chrome.
- **UITextView as host**: reuse Apple's IME, selection, accessibility, dictation, etc., instead of rebuilding them.
- **Device-text-first**: the `NSTextStorage` string is always the source of truth; block metadata and calories are overlays, never replacing user text.
- **Crash-safe TextKit 2**: avoid the typical `NSRangeException` and TK1/TK2 "fallback" traps.
- **Normal caret behavior**: image blocks don't affect caret/selection sizing.

---

## 2. Current Architecture (Working Implementation)

### 2.1 Object graph

```
UITextView (BlockEditorTextView)
    ├─ NSTextLayoutManager        (default from UITextView, TextKit 2)
    │    └─ BlockTextLayoutController (delegate for custom fragments)
    ├─ NSTextContentStorage       (default, NOT subclassed)
    │    └─ NSTextStorage         (default)
    ├─ BlockDocumentController    (observes storage, builds BlockDocument)
    └─ Image Overlays             (UIHostingController<ImageComponent> subviews)
```

### 2.2 Key design decisions

#### Why we don't subclass `NSTextContentStorage`

Early attempts used a custom `BlockTextContentStorage` subclass, but this caused persistent `NSRangeException` crashes when editing around attachments. TextKit 2's internal invariants are fragile when you replace the content storage.

**Solution**: We use the **default** `NSTextContentStorage` provided by `UITextView` and observe it via `BlockDocumentController` (which implements `NSTextStorageDelegate`). This keeps TextKit's internal state consistent.

#### Why we don't use `NSTextAttachment` for images

Using `NSTextAttachment` causes the caret to grow to the attachment's height, which breaks the editing UX.

**Solution**: We insert an **invisible marker character** (`\u{FFFC}`) and overlay `ImageComponent` as a `UIHostingController` subview positioned at the marker's layout rect. This keeps the caret at normal text height.

#### How paragraph spacing works

Using `renderingAttributesValidator` to apply paragraph styles causes caret/selection mismatch (TextKit computes selection from storage attributes, not rendering attributes).

**Solution**: Paragraph spacing is baked into the actual `NSAttributedString` via `typingAttributes`, so storage and layout stay in sync. After every storage edit, `BlockDocumentController` rebuilds the block list and triggers `applyBlockStyles()`, which rewrites paragraph styles for each block range based on its kind. This makes block spacing deterministic and prevents newly created text blocks from inheriting an image block’s large spacing.

---

## 3. Components

### 3.1 `BlockDocument` / `BlockMetadata` / `BlockStyle` / `BlockKind`

**File**: `BlockModels.swift`

- **`BlockKind`**: `.paragraph` or `.image`
- **`BlockStyle`**: spacing, insets, corner radius, background color
- **`BlockMetadata`**: id, kind, style, range, optional image reference
- **`BlockDocument`**: array of `BlockMetadata`, rebuilt from `NSTextStorage` on each edit

Detection logic:
- Paragraphs containing the marker character (`\u{FFFC}`) are classified as `.image` blocks.
- For image blocks, the `BlockID` is extracted from a custom attribute (`imageBlockID`) on the marker.

### 3.2 `BlockDocumentController`

**File**: `BlockDocumentController.swift`

- Implements `NSTextStorageDelegate`.
- On `textStorage(_:didProcessEditing:...)`, rebuilds `BlockDocument`.
- Calls `onDocumentChange` callback so the text view can update image overlays.
- Provides `block(for:)` to look up block metadata by `NSTextRange`.

### 3.3 `BlockTextLayoutController`

**File**: `BlockTextLayoutManager.swift`

- Implements `NSTextLayoutManagerDelegate`.
- Provides custom `NSTextLayoutFragment` subclasses per block kind:
  - `ParagraphBlockLayoutFragment` for text blocks (draws background card).
  - `ImageBlockLayoutFragment` for image blocks.
- Does **not** use `renderingAttributesValidator` for spacing (to avoid caret mismatch).

### 3.4 `ParagraphBlockLayoutFragment` / `ImageBlockLayoutFragment`

**File**: `ParagraphBlockLayoutFragment.swift`

- Subclasses of `NSTextLayoutFragment`.
- Override `draw(at:in:)` to render block backgrounds (rounded rect cards).
- `blockMetadata` property provides styling info.

### 3.5 `BlockEditorTextView`

**File**: `BlockEditorTextView.swift`

Main text view that ties everything together:

- Uses default TextKit 2 stack (no custom content storage).
- Lazily creates `BlockDocumentController` and `BlockTextLayoutController`.
- Manages **image overlays** as `UIHostingController<ImageComponent>` subviews.
- Provides `insertImageBlock(image:)` to add image blocks.

#### Image block insertion flow

1. Generate a new `BlockID`.
2. Store the `UIImage` in `imagesByBlockID[blockID]`.
3. Build attributed string:
   - **Marker** (`\u{FFFC}`): invisible (`.foregroundColor: .clear`), tagged with `imageBlockID` attribute.
   - **Sample text** ("Description here"): visible, shares the image block spacing, no head indent (text wraps via exclusion paths).
   - **Newline**: normal attributes for the next paragraph so it starts as a regular text block.
4. Insert into `attributedText`.
5. Set `typingAttributes` to image block style so continued typing maintains the block’s spacing while text still flows around the overlay via `textContainer.exclusionPaths`.
6. Call `updateImageOverlays()`.

#### Image overlay positioning

On `layoutSubviews()` and document changes:

1. Enumerate `.image` blocks from `BlockDocument`.
2. For each block, get the marker's layout rect via `enumerateTextSegments`.
3. Position `ImageComponent` at:
   - **X**: `textContainerInset.left` (left edge, not marker's indented X).
   - **Y**: marker's `rect.minY + textContainerInset.top`.
4. Remove overlays for deleted blocks.

### 3.6 `BlockEditorRepresentable` / `BlockEditorTestView`

**Files**: `BlockEditorRepresentable.swift`, `BlockEditorTestView.swift`

- SwiftUI wrappers for `BlockEditorTextView`.
- `BlockEditorTestView` provides a test harness with "Insert sample image block" button.

### 3.7 `BlockTextAttributes`

**File**: `BlockTextAttributes.swift`

Custom attribute keys:
- `blockIdentifier`: UUID for block tracking.
- `blockKind`: block type marker.
- `imageBlockID`: UUID linking marker character to its image overlay.

---

## 4. Text & Spacing Configuration

### Paragraph blocks

```swift
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.paragraphSpacingBefore = 10
paragraphStyle.paragraphSpacing = 10
paragraphStyle.lineHeightMultiple = 1.14
```

### Image blocks

```swift
let imageParagraphStyle = NSMutableParagraphStyle()
imageParagraphStyle.paragraphSpacingBefore = 8
imageParagraphStyle.paragraphSpacing = 88        // image height (80) + padding (8)
imageParagraphStyle.lineHeightMultiple = 1.14
```

Text in image blocks flows around the overlay using `textContainer.exclusionPaths`, so no `headIndent` is required.

---

## 5. Crash-safety constraints

1. **No custom `NSTextContentStorage` subclass** – use the default provided by `UITextView`.
2. **No attribute mutations from inside TextKit callbacks** – only observe and rebuild the model.
3. **No `renderingAttributesValidator` for spacing** – bake spacing into storage via `typingAttributes`.
4. **Clamp all ranges** before any storage access.
5. **Use marker + overlay for images** – don't use `NSTextAttachment` (causes caret sizing issues).

---

## 6. Future work

### Phase 1 – Block interactions (next)
- Tap / long-press on blocks for context menu, move, delete.
- "Focus" state with highlighted background.

### Phase 2 – Calorie metadata & overlays
- Extend `BlockMetadata` with `calorieLabel`.
- Draw calorie labels in `ParagraphBlockLayoutFragment.draw(at:in:)`.
- **Goals**
  - Show per-block calorie labels (similar to current editor) without affecting 
  text layout.
- **Approach**
  - Extend `BlockMetadata` with `calorieLabel` (and later richer nutrition JSON).
  - In `ParagraphBlockLayoutFragment.draw(at:in:)`, after drawing background:
    - Compute a label rect (right edge of the block, last line baseline).
    - Draw calories using Core Graphics / UIKit (or add a sublayer if needed).
  - Reuse the existing server → device “metadata only” pattern:
    - Apply analyzed calories via notification → update `BlockDocument` → re-render 
    fragments, without touching text.

### Phase 3 – Diary integration
- Replace existing editor with EditorV2.
- Migrate calorie update flow to target `BlockDocument`.

---

## 7. File overview

| File | Purpose |
|------|---------|
| `BlockModels.swift` | `BlockID`, `BlockKind`, `BlockStyle`, `BlockMetadata`, `BlockDocument` |
| `BlockDocumentController.swift` | Observes `NSTextStorage`, rebuilds `BlockDocument` |
| `BlockTextLayoutManager.swift` | `NSTextLayoutManagerDelegate`, provides custom fragments |
| `ParagraphBlockLayoutFragment.swift` | Custom fragment drawing (backgrounds) |
| `BlockEditorTextView.swift` | Main text view, image overlay management |
| `BlockEditorRepresentable.swift` | SwiftUI wrapper |
| `BlockEditorTestView.swift` | Test harness |
| `BlockTextAttributes.swift` | Custom attribute keys |
| `PlainAttachmentEditor.swift` | Minimal test view for vanilla TextKit 2 + attachments |
