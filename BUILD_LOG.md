# Build Log

## 2026-05-24 - editor scroll offset binding

Files changed:
- `calcalcal/EditorV2/BlockEditorRepresentable.swift`
- `calcalcal/EditorV2/BlockEditorTextView.swift`
- `calcalcal/DiaryList/EntryCard.swift`
- `calcalcal/Views/EditorOverlay.swift`
- `calcalcal/Extensions/NotificationNames.swift`

Summary:
- Replaced the editor scroll-offset NotificationCenter transport with a `Binding<CGFloat>` passed from `EditorOverlay` through `EntryCard` into `BlockEditorRepresentable`.
- Routed `BlockEditorTextView.scrollViewDidScroll` through the representable coordinator to update the binding.
- Removed both scroll-offset notification post sites, the receive site, and the notification name declaration.

Caveats:
- Did not run Xcode/build, per request.
- `Docs/state-consolidation-audit-2026-05-23.md` was not present in this checkout.
