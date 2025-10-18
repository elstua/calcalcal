### Unified Editor: Metadata-Only Updates (Device Text as Source of Truth)

#### Goals
- **No delays/guards**: Remove timing-based protections. Updates must feel instant.
- **Device text is canonical**: The `UITextView.textStorage` content (characters) is the source of truth.
- **Metadata-only application**: Server results update only per-paragraph metadata (calories/nutrition), never text.
- **Conflict policy**: If content diverges, prefer the latest on-device text. Server data never overwrites text.
- **Future extensibility**: Content-changing features (e.g., auto description for photo) use a separate, explicit path.

#### Current Pain Point
- Server/LLM responses sometimes cause `blocks` assignments that trigger partial/full re-renders of the editor, which can wipe freshly typed text or move the caret.
- There is a 0.6s idle guard and deferred apply, which still leaves room for data races and slows perceived responsiveness.

#### Design Overview
1. **Canonical Source**
   - Canon: `UITextView.textStorage` text + `UnifiedTextContentStorage` paragraph attributes.
   - SwiftUI `blocks` binding is derived from the text storage when needed (reconstruction), not a driver of text mutations from server.

2. **Metadata Channel (calories/nutrition)**
   - Introduce an editor API that applies nutrition/calorie metadata in-place to paragraphs without touching characters:
     - `UnifiedTextView.applyNutritionMetadata(analyzedBlocks: [AnalyzedBlock])`
   - Matching strategy:
     - Build the list of non-empty textual paragraphs (text and imageText) from current text storage via `enumerateParagraphs`.
     - First pass: match by exact trimmed text equality `analyzed.content.trim == paragraph.text.trim` (device-wins semantics: only update when it still matches).
     - Second pass (fallback): apply remaining analyzed blocks by sequential position to unmatched paragraphs (best-effort, harmless since metadata-only).
   - For each match, update attributes via `UnifiedTextContentStorage.setBlockMetadata` for that paragraph range:
     - Update only `calorieData` and `nutritionJSON`.
     - Refresh visuals (`updateBlockBackgroundViews`, `setNeedsDisplay`).

3. **Model Synchronization (non-invasive)**
   - After applying attributes, reconstruct `blocks` from the current text storage (existing logic) and bubble up via `onBlocksChange` to keep SwiftUI state in sync.
   - This preserves characters as typed and only fills metadata fields on the corresponding `Block`s.

4. **Notification Bridge (no IDs on paragraphs required)**
   - `UnifiedTextEditor` gains `entryId: UUID` (propagated to `UnifiedTextView`).
   - A new notification (scoped per entry) carries analyzed results to the active editor:
     - Name: `.editorApplyPerBlockMetadata`
     - Payload: `{ entryId: UUID, analyzedBlocks: [AnalyzedBlock] }`
   - `UnifiedTextView` listens and calls `applyNutritionMetadata(...)` immediately. No delays or caret disruptions.

5. **Overlay/Autosave Flow Changes**
   - Replace all places where we currently do `self.blocks = updated` based on server/DB analysis with posting `.editorApplyPerBlockMetadata` (with `entryId`).
   - Continue posting `.diaryEntryTotalsUpdated` for live totals as today.

6. **Conflict & Duplicates Handling**
   - If paragraph text changed after save, exact-match will skip that analyzed block (device-wins). No content overwrite.
   - For repeated identical lines, first-pass exact-match pairs in order; remaining pairs use positional fallback. Only metadata changes, so mistakes are low-impact and self-correct on next analysis.

7. **Future Content-Changing Features**
   - Add a distinct API for server-proposed content edits (e.g., add description to photo): `proposeContentChanges(_)`.
   - These are explicit, user-visible changes with undo/accept, and never piggyback on the metadata channel.

#### Implementation Plan (Incremental)
1. `UnifiedTextView`
   - Add `entryId: UUID` property.
   - Add observer for `.editorApplyPerBlockMetadata` and filter by `entryId`.
   - Implement `applyNutritionMetadata(analyzedBlocks:)`:
     - Enumerate paragraphs; build `[(range, text, metadata)]` for non-empty textual blocks.
     - Perform exact-match pairing, then positional fallback.
     - For each match: mutate `calorieData` and `nutritionJSON` in attributes using `setBlockMetadata`.
     - Refresh visuals. Reconstruct `blocks` from text storage and notify parent via `onBlocksChange` (through the existing `UnifiedTextEditor` bridge).

2. `UnifiedTextEditor`
   - Accept `entryId` in init and pass to `UnifiedTextView`.
   - Ensure the reconstruction path already present (`updateBlocksFromTextStorage`) forwards updated blocks via `onBlocksChange`.

3. `EditorOverlay`
   - Where server analysis returns (initial load and autosave polling), replace `self.blocks = updated` with posting `.editorApplyPerBlockMetadata` with `{ entryId, analyzedBlocks }`.
   - Keep totals updates (`.diaryEntryTotalsUpdated`) unchanged.

4. Types & Notifications
   - Reuse existing `AnalyzedBlock` model.
   - Add notification name and userInfo keys.

#### Risks & Mitigations
- Ambiguous duplicate text lines:
  - Mitigation: exact-match first, then positional fallback. Only metadata changes, safe to update; future analyses will converge.
- Image paragraphs without caption text:
  - We only apply when there is non-empty paragraph text (or choose to allow image-only matching by `imageReference` later).
- Performance on large documents:
  - Paragraph enumeration and string trim compares are linear; updates are attribute-only; should be fast. We retain throttled display refresh.

#### Testing Scenarios
- Type paragraph A, press Enter, start paragraph B; server returns for A → A’s calories update; B unaffected; caret stable.
- Insert paragraph above A before analysis returns → match still finds A by content; metadata applied correctly.
- Edit a paragraph’s text after save, before results → analyzed content no longer matches; metadata for that block is skipped (device-wins).
- Image+caption blocks → metadata applied to those paragraphs based on caption text.

#### Out of Scope (for now)
- Changing user text from server. Will come via `proposeContentChanges(_)` with explicit UX.

#### Rollout
- Implement behind internal flag at first if needed; default on after verification.


