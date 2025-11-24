# EditorV2 – TextKit 2 Block Editor (Current Logic & Plan)

## 1. High-level Goals
- **True block semantics**: each paragraph/image behaves as its own block with independent spacing and visual chrome.
- **UITextView as host**: reuse Apple’s IME, selection, accessibility, dictation, etc., instead of rebuilding them.
- **Device-text-first**: the `NSTextStorage` string is always the source of truth; block metadata and calories are overlays, never replacing user text.
- **Crash-safe TextKit 2**: avoid the typical `NSRangeException` and TK1/TK2 “fallback” traps.

---

## 2. Current Architecture (Working Prototype)

### 2.1 Object graph
```
UITextView (BlockEditorTextView)
    ├─ NSTextLayoutManager        (from UITextView, TextKit 2)
    │    └─ BlockTextLayoutController (delegate + rendering attributes)
    └─ NSTextContentStorage
         └─ BlockTextContentStorage  (backingStore + block model)
```

- **`BlockDocument` / `BlockMetadata` / `BlockStyle`**
  - Derived model from the current `NSTextStorage` contents.
  - One `BlockMetadata` per paragraph (for now, only `.paragraph` kind).
  - Stores: range in storage, spacing before/after, content insets, background styling, future calorie metadata.

- **`BlockTextContentStorage`**
  - Owns a private `NSTextStorage` (`backingStore`) and exposes it via `textStorage`.
  - On any edit (`textStorage(_:didProcessEditing:...)`):
    - Rebuilds `BlockDocument` by enumerating paragraphs in `backingStore`.
    - Invalidates TextKit 2 rendering attributes for the whole document range.
    - Schedules a **deferred** attribute update on the next run loop tick.
  - Deferred `applyBlockAttributes()`:
    - Runs on main queue outside TextKit’s internal editing cycle.
    - Clears block-related attributes on the full range.
    - For each block, clamps its `NSRange` to the current storage length and applies:
      - `BlockIdentifierAttribute` (UUID backing).
      - Paragraph-level `NSParagraphStyle` with our block spacing and line height.

- **`BlockTextLayoutController`**
  - Attached as the `NSTextLayoutManager.delegate`.
  - Provides `renderingAttributesValidator`:
    - For each `NSTextLayoutFragment`, looks up the matching `BlockMetadata` via `rangeInElement`.
    - Optionally reinforces per-fragment paragraph style via `setRenderingAttributes(_:for:)` (safe rendering-time override).

- **`BlockEditorTextView`**
  - Created with `textContainer: nil` → UITextView configures TextKit 2.
  - Grabs `textLayoutManager`, calls `replace(_:)` with our content storage and attaches `BlockTextLayoutController`.
  - Exposes `updateTextIfNeeded(_:)` for SwiftUI wrapper.

- **`BlockEditorRepresentable` / `BlockEditorTestView`**
  - Embeds `BlockEditorTextView` in SwiftUI, syncing plain `String` via delegate.
  - Used as our playground; no backend or calorie integration yet.

### 2.2 Crash-safety constraints we now respect
- Never mutate attributes from inside TextKit callbacks like gesture handling or `renderingAttributesValidator`; all mutations are queued via `DispatchQueue.main.async`.
- Every time we apply attributes, we:
  - Capture `storageLength` once.
  - Clamp all block ranges to `[0, storageLength]`.
  - Use a single `beginEditing` / `endEditing` transaction.
- We avoid touching `layoutManager` (TextKit 1) anywhere in EditorV2; we only use `.textLayoutManager`.

---

## 3. Planned Implementation Phases

### Phase 1 – Solid text blocks (now)
- **Done**
  - Stable typing, selection, and tapping in previews.
  - Paragraph blocks with custom spacing via paragraph styles.
  - Basic block model (`BlockDocument`) + attribute pipeline.
  - SwiftUI test view to iterate on UX.
- **Polish to add**
  - Visual block chrome in `ParagraphBlockLayoutFragment` (backgrounds, subtle separators).
  - Configurable global spacing / per-block variants via `BlockStyle`.

### Phase 2 – Block interactions
- **Goals**
  - Tap / long-press on a paragraph block (e.g. for context menu, move, delete).
  - “Focus” state for a block (highlighted background).
- **Approach**
  - Add hit-testing helpers on `BlockEditorTextView`:
    - Convert touch location → `NSTextLayoutFragment` via `textLayoutManager.textLayoutFragment(forPosition:)`.
    - Map fragment range → `BlockMetadata` via `BlockTextContentStorage.block(for:)`.
  - Wire `UILongPressGestureRecognizer` (or use `UITextItemInteraction`) to surface `BlockID` and block rect to SwiftUI.

### Phase 3 – Image blocks
- **Goals**
  - Support `.image` blocks with:
    - Minimum height.
    - Block spacing that keeps following text **below** the image.
    - No ability to put text “next to” the image (only above/below).
- **Approach**
  - Model:
    - Extend `BlockKind` with `.image(imageID)` (or data/URL, depending on existing pipeline).
    - Define `BlockStyle.imageDefault` with larger `spacingBefore/After` and content insets.
  - Layout / rendering:
    - Use `NSTextAttachment` per image-block paragraph.
    - Introduce `ImageBlockLayoutFragment` subclass for drawing the image inside a rounded-rect block surface.
    - For image paragraphs, set `minimumLineHeight`/`maximumLineHeight` from `BlockStyle` via `paragraphStyle(for:)`.
    - Ensure a paragraph separator after each image block so the next text block always starts below.
  - UX:
    - Initially, image blocks are non-editable text-wise (no caption) to keep behavior simple.
    - Tap = open image picker / full-screen.

### Phase 4 – Calorie metadata & overlays
- **Goals**
  - Show per-block calorie labels (similar to current editor) without affecting text layout.
- **Approach**
  - Extend `BlockMetadata` with `calorieLabel` (and later richer nutrition JSON).
  - In `ParagraphBlockLayoutFragment.draw(at:in:)`, after drawing background:
    - Compute a label rect (right edge of the block, last line baseline).
    - Draw calories using Core Graphics / UIKit (or add a sublayer if needed).
  - Reuse the existing server → device “metadata only” pattern:
    - Apply analyzed calories via notification → update `BlockDocument` → re-render fragments, without touching text.

### Phase 5 – Integration with Diary & feature flag
- **Goals**
  - Replace the existing editor in diary entry screens with EditorV2, gated behind a flag.
- **Approach**
  - Add a SwiftUI wrapper mirroring today’s `UnifiedTextEditor` API surface as much as reasonable:
    - Bindings for full text plus `[Block]` for analytics.
    - Hooks for external save / analysis triggers.
  - Side-by-side mode:
    - Keep the old editor for some users; use EditorV2 for others (A/B or dev-only).
  - Migrate metadata-only calorie updates to target `BlockDocument` / `BlockTextContentStorage`.

---

## 4. Implementation Order (Concrete TODOs)

1. **Stabilize text-only blocks**
   - Finalize `paragraphStyle(for:)` semantics and `BlockStyle` presets.
   - Add simple block background drawing (soft cards) to visually prove the model.
2. **Block interactions**
   - Implement hit-testing → `BlockID`.
   - Expose tap / long-press callbacks in `BlockEditorRepresentable`.
3. **Image blocks (MVP)**
   - Add `.image` kind with attachment-based rendering and vertical-only flow.
   - Ensure height + spacing rules match diary UX expectations.
4. **Calorie overlays**
   - Port the per-paragraph calorie rendering logic to EditorV2 fragments.
5. **Diary integration**
   - Add a new editor view in Diary screens using EditorV2 behind a flag.
   - Run through common flows (short entry, long entry, edits after sync) and tune.

This doc reflects the **current, working** TextKit 2 setup plus a stepwise plan to reach full block-based behavior (including images and calories) without reintroducing the crashes we just eliminated.
