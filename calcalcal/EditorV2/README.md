# EditorV2 (TextKit 2 Block Sandbox)

## Goals
- Prove the block-based editor concept on top of pure TextKit 2 primitives.
- Keep `UITextView` as the IME host for first-class keyboard, dictation, and accessibility.
- Treat every paragraph/image as an isolated block with its own spacing and chrome.
- Keep the device text storage as the single source of truth; metadata augments it.

## Stack Overview
```
BlockDocument (value model + metadata)
        ↓
BlockTextContentStorage (NSTextContentStorage subclass)
        ↓
BlockTextLayoutManager (NSTextLayoutManager subclass)
        ↓
ParagraphBlockLayoutFragment / AttachmentBlockLayoutFragment
        ↓
BlockEditorTextView (UITextView host)
        ↓
BlockEditorRepresentable (SwiftUI bridge + demo view)
```

### Key Ideas
- Paragraph metadata is stored as attributes inside the backing `NSTextStorage`, so fragments can resolve their block ID with zero heuristics.
- `BlockTextLayoutManager` asks `BlockTextContentStorage` for the block configuration while instantiating a fragment and injects padding/background information before rendering.
- Custom layout fragments draw their own block background and inset the text so adjacent blocks never influence each other.
- All synchronisation flows from the device text storage; a `BlockDocument` snapshot is emitted to SwiftUI consumers for analytics/metadata.

## Current Status (Milestone 0)
- ✅ Bootstrapped TextKit 2 pipeline (content storage + layout manager + container).
- ✅ Paragraph block model + attribute propagation.
- ✅ Custom `ParagraphBlockLayoutFragment` with independent padding + background drawing.
- ✅ SwiftUI demo wrapper that keeps a binding in sync with the TextKit storage.

## Next Steps
1. Implement attachment/image blocks via `NSTextAttachmentViewProvider`.
2. Add gesture routing (tap/long-press) that reports the touched `BlockID`.
3. Surface calorie/nutrition overlays through fragment metadata.
4. Stress-test with multi-screen diaries and polish layout invalidation.

When these pieces are stable we can start swapping `EditorV2` into production flows behind a feature flag and hook up the existing analysis pipeline.


