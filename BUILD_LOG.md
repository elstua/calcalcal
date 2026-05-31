# Build Log

## 2026-05-24 - entry identity Combine publisher

Files changed:
- `calcalcal/Models/EntryIdentityCoordinator.swift`
- `calcalcal/DiaryList/DiaryListView.swift`
- `calcalcal/DiaryList/DiaryTabView.swift`
- `calcalcal/Extensions/NotificationNames.swift`

Summary:
- Replaced the `diaryEntryCanonicalIdResolved` NotificationCenter fan-out with `EntryIdentityCoordinator.shared.canonicalizations`.
- Added the co-located `EntryCanonicalization` struct with `localId` and `serverId` fields.
- Kept cache migration and the main-queue dispatch in `EntryIdentityCoordinator.canonicalize(localId:serverId:blocks:)`.
- Updated both iOS receivers to consume the typed Combine event and removed the notification name declaration.
- Verified `rg -n "diaryEntryCanonicalIdResolved" calcalcal` returns no matches.

Caveats:
- Did not run Xcode/build, per request.
- `Docs/state-consolidation-audit-2026-05-23.md` was not present in this checkout.

## 2026-05-24 - editor analysis error published state

Files changed:
- `calcalcal/Services/EditorAutosaveService.swift`
- `calcalcal/Views/EditorOverlay.swift`
- `calcalcal/Extensions/NotificationNames.swift`

Summary:
- Replaced the editor analysis-error NotificationCenter transport with `EditorAutosaveService.lastAnalysisError`.
- Kept the existing `postAnalysisError(_:)` call sites and made the helper assign the published message.
- Updated `EditorOverlay` to show the toast from the per-editor autosave service and reset the message to `nil` so repeated errors can fire.
- Removed the `editorAnalysisError` notification name declaration and verified no references remain.

Caveats:
- Did not run Xcode/build, per request.
- `Docs/state-consolidation-audit-2026-05-23.md` was not present in this checkout.

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

## 2026-05-24 - editor paragraph signals closures

Files changed:
- `calcalcal/EditorV2/BlockEditorRepresentable.swift`
- `calcalcal/EditorV2/BlockEditorTextView.swift`
- `calcalcal/DiaryList/EntryCard.swift`
- `calcalcal/Views/EditorOverlay.swift`
- `calcalcal/Extensions/NotificationNames.swift`

Summary:
- Replaced the paragraph commit/edit NotificationCenter transport with per-editor SwiftUI closures.
- Threaded `onParagraphCommitted` and `onSavedParagraphEdited` from `EditorOverlay` through `EntryCard` into `BlockEditorRepresentable` and `BlockEditorTextView`.
- Removed the two notification name declarations and verified no references remain.

Caveats:
- Did not run Xcode/build, per request.
- `Docs/state-consolidation-audit-2026-05-23.md` was not present in this checkout.

## 2026-05-24 - editor image overlay reveal direct call

Files changed:
- `calcalcal/Views/EditorOverlay.swift`
- `calcalcal/DiaryList/EntryCard.swift`
- `calcalcal/EditorV2/BlockEditorTextView.swift`
- `calcalcal/Extensions/NotificationNames.swift`

Summary:
- Replaced the image overlay reveal NotificationCenter handoff with a direct `BlockEditorTextView.revealImageOverlay(for:)` call after the fly-to animation completes.
- Added a private `WeakRef<BlockEditorTextView>` holder in `EditorOverlay` because `@State` cannot store a `weak` property directly.
- Threaded `onTextViewReady` through `EntryCard` into the existing `BlockEditorRepresentable` callback to capture the text view weakly.
- Removed the reveal observer, handler, and `editorRevealImageOverlay` notification name declaration.

Caveats:
- Did not run Xcode/build, per request.
- `Docs/state-consolidation-audit-2026-05-23.md` was not present in this checkout.

## 2026-05-24 - editor per-block metadata subject

Files changed:
- `calcalcal/Services/EditorAutosaveService.swift`
- `calcalcal/Views/EditorOverlay.swift`
- `calcalcal/DiaryList/EntryCard.swift`
- `calcalcal/EditorV2/BlockEditorRepresentable.swift`
- `calcalcal/EditorV2/BlockEditorTextView.swift`
- `calcalcal/Extensions/NotificationNames.swift`

Summary:
- Replaced the `editorApplyPerBlockMetadata` NotificationCenter transport with an `EditorAutosaveService.metadataUpdates` `PassthroughSubject`.
- Added the co-located `EditorMetadataUpdate` payload while preserving the existing `[[String: Any]]` block dictionaries.
- Threaded the subject from `EditorOverlay` through `EntryCard` and `BlockEditorRepresentable` to both per-editor subscribers.
- Kept the subject on the existing per-editor `EditorAutosaveService` instead of adding a parallel `EditorViewModel`, because the service is already the `@StateObject` that owns this editor's save/analyze lifecycle.
- Replaced the manual calorie edit self-post with a direct `BlockEditorTextView.onMetadataApplied` callback into the coordinator snapshot path.
- Removed the `editorApplyPerBlockMetadata` notification name and verified no references remain.

Caveats:
- Did not run Xcode/build, per request.
- Left `diaryEntryCaloriesUpdated` and `streaksDataUpdated` NotificationCenter usage untouched for future PRs.

## 2026-05-24 - diary entry calorie updates subject

Files changed:
- `calcalcal/Models/DiaryEntryUpdatesCoordinator.swift`
- `calcalcal/Services/EditorAutosaveService.swift`
- `calcalcal/EditorV2/BlockEditorTextView.swift`
- `calcalcal/DiaryList/DiaryListView.swift`
- `calcalcal/DiaryList/DiaryTabView.swift`
- `calcalcal/Extensions/NotificationNames.swift`

Summary:
- Replaced the `diaryEntryCaloriesUpdated` NotificationCenter transport with a typed `DiaryEntryUpdatesCoordinator.calorieUpdates` `PassthroughSubject`.
- Kept both state holders subscribed: `DiaryTabViewModel` via `DiaryTabView`, and `DiaryListView`'s local `@State entries` for the regular list and `AllDaysOverlay`.
- Preserved the old nil-total behavior by ignoring `EntryCalorieUpdate.totalCalories == nil` at both receivers.
- Deferred deletion of the defensive calorie-preservation block in `DiaryTabViewModel.apply(entries:)` to a follow-up PR after observing the new transport in production.

Caveats:
- Did not run Xcode/build, per request.
- `streaksDataUpdated` NotificationCenter usage remained for a separate future PR.

## 2026-05-30 - streak updates subject

Files changed:
- `calcalcal/Models/DiaryEntryUpdatesCoordinator.swift`
- `calcalcal/Services/EditorAutosaveService.swift`
- `calcalcal/DiaryList/DiaryListView.swift`
- `calcalcal/DiaryList/DiaryTabView.swift`
- `calcalcal/Extensions/NotificationNames.swift`
- `calcalcal/CLAUDE.md`

Summary:
- Replaced the `streaksDataUpdated` NotificationCenter transport with a typed `DiaryEntryUpdatesCoordinator.streakUpdates` `PassthroughSubject`.
- Kept both streak refresh producers intact: the legacy popup save path in `DiaryListView` and the editor close flush path in `EditorAutosaveService`.
- Removed the last custom `Notification.Name` declaration file and updated the iOS guide to point at typed Combine coordinators instead.

Caveats:
- System `NotificationCenter` usage for UIKit keyboard and text-selection notifications remains intentionally unchanged.
