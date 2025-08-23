## Backend counting and diary data plan

This document outlines the preparation and implementation plan to send and receive user's calories. It focuses on removing frontend mocks, defining day-list behavior, persisting diary text (without LLM first), and shaping the future AI analysis flow.

### Scope (now vs later)
- Now: clean up mocks, decide day range behavior, wire saving/reading plain text + images per day, ensure DB linking and RLS, define contracts.
- Later: AI analysis for calories/macros, batching requests, caching, error handling, realtime updates.

### Current state snapshot
- Editor: `UnifiedTextEditor` and `UnifiedTextView` support blocks with text/image metadata. Demo view injects mock calories and placeholder text.
- iOS models: `DiaryEntry` exists; `Block`/`BlockType` capture editor content locally.
- Network: `APIClient` exists; no specific diary endpoints yet.
- DB: `diary_entries` with `content` (text), derived `blocks` (jsonb), daily totals, images, and RLS policies are in place. Triggers parse `content` into text blocks and compute totals as 0 without AI.
- Edge functions: `ai/analyze` exists (JSON-in/JSON-out), `storage/upload-url` for images, `auth-profile` for session checks.

### Work plan (pre-LLM)
1) Frontend cleanup (Editor and Diary UI)
- Remove demo-only random calories and placeholder content from user-visible paths; keep demo view isolated.
- Implement `updateBlocksFromTextStorage` to reconstruct `[Block]` from `textStorage` + metadata.
- Decide how images are represented for persistence (per-entry `images: [String]` URLs), and ensure block image UUIDs map to URLs for round-trip.
- Extract editor debug logs and overlays from production flows.

Images persistence approach (hybrid)
- Hybrid strategy:
  - Local cache in app sandbox for fast display/offline.
  - Upload binary to Supabase Storage bucket `images`; persist only URLs/paths in `diary_entries.images`.
- Avoid base64: increases size (~33%), bloats DB rows, hurts perf/CDN; do not embed images in JSON/DB.
- Maintain mapping `imageUUID -> { localPath, storageURL? }` to support round‑trip in editor and future AI payloads.
- Background uploads: queue uploads and update the entry with the final storage URL on completion.
- Deletion: when removed from an entry, drop URL from `diary_entries.images`, schedule remote delete (optional), and purge local cache.

2) Day list behavior (when user is new or has gaps)
 - Default range: show last N days including today. N = 30 (matches `Docs/diary-list.md`).
- Do not pre-create rows for empty days. Render placeholders client-side; lazily create an entry when the user types or attaches an image.
- Timezone boundary: use `user_profiles.timezone_offset` to compute local-day on client for queries and creation.

Day counting responsibility (frontend)
- Generate the timeline of days on the client (today backward) using the user's timezone offset to compute local-day boundaries.
- The client applies sparse/collapsed rendering and manages 14‑day expansion of empty runs.
- Backend provides data only: earliest entry date and entries for requested date windows (including pagination by date cursor). No server-side day generation.

Gap handling & pagination
- Always anchor the list at today to encourage current logging. Show placeholders for the last 30 days.
- Sparse timeline rendering:
  - Always show: Today, Yesterday, Day before yesterday and two more days
  - Show at most 1–2 empty placeholders immediately before the latest entry segment.
  - Collapse any run of >14 consecutive empty days into a single summarized row (e.g., "17–1 Sept • 17 empty days"), with on-demand expansion in 14‑day slices.
  - When expanded, insert actual day rows for the next 14 days (placeholders if empty); allow repeated expansion until the run is fully revealed.
- If the user's most recent entry is older than 30 days, prefer the collapsed card rather than rendering each empty day.
- Infinite scroll upwards still loads older periods, but initial render remains sparse; expansion actions request only the needed window.
- Backend support:
  - Earliest date: `select min(date) from diary_entries where user_id = auth.uid()` to determine oldest boundary and initial collapsed segments.
  - Paged fetch by cursor: `GET /rest/v1/diary_entries?select=*&date=lte.{cursor}&order=date.desc&limit=30` (client sends `cursor` as local-day YYYY-MM-DD). For expansions, compute the exact date window to reveal and fetch entries only for that window.
- UX details:
  - Keep "Today" at top; render condensed segments without explicit jump actions.

Implementation notes (client algorithm)
- Maintain a set of entry dates returned from backend; generate a condensed sequence of days from today backward.
- Identify contiguous empty runs; if length > 14, render a collapsed card with count and date range.
- Expansion: convert the collapsed segment into a bounded window (next 14 days), append to list, and request entries only for those dates to fill in content.
- Preserve scroll position on expansion; throttle repeated expansions.

Constants and labels
- Threshold for collapsing empty runs is fixed at 14 days.
- Interim label format: "17 days, Sep 1–17" (final formatting to be defined later).

 Tasks (UI/logic)
- Create `CollapsedEmptyRunView` with label and an expand action (14‑day increments).
- Implement condensed list generator and expansion logic (with timezone-aware date math).
- Wire backend fetch for: earliest date, entries for a specific date window, and cursor-based older pages.

3) Persisting and retrieving text (no AI)
- Save: send a single `content` string for the day (joined paragraphs) plus `images` array of URLs. Rely on DB trigger to parse simple text blocks and compute totals (zero for now).
- Read: fetch `diary_entries` for a date range. Use `content` for editor; optionally show totals if present.
- Mapping from blocks to `content`:
  - Text blocks: join with double newline between paragraphs.
  - ImageText blocks: include the text portion in `content`; upload image to storage; append URL to `images`.
  - Spacer blocks: ignore when serializing.

Image handling details (client)
- Local caching: store originals or downscaled JPEG/HEIF in the app sandbox cache; do not rely on Photos `PHAsset` identifiers as a source of truth.
- Upload policy: background upload to Supabase via signed PUT; update the entry with the resulting URL when available.
- Encoding & size: resize to max width ~1080px; JPEG quality ~0.7 (or HEIF if acceptable); strip metadata when possible.
- Mapping: maintain `imageUUID -> { localPath, storageURL? }`.

4) Storage and linking
- Ensure images go to `storage` bucket `images`.
- Access model: prefer a private bucket; serve via short‑lived signed URLs. Public bucket is acceptable if no PII in paths and simpler UX is preferred.
- Persist only storage paths/URLs in `diary_entries.images`.
- Avoid base64 storage of images in DB columns.
- Linkage: `diary_entries.user_id = auth.uid()`, unique per `(user_id, date)`.
- RLS already enforces per-user access.

5) iOS API surface (to add)
- getOrCreateTodayEntry(): fetch today, create if missing on first edit/save.
- listEntries(dateFrom, dateTo): paginated range query.
- updateEntryContent(entryId, content, images): PATCH `content` and `images` (no AI). `images` is an ordered array of storage URLs.
- uploadImage(file): call signed URL function, then PUT binary; return final storage URL (or a path that can be resolved to a signed URL for display).
- image cache helpers: resolve/download storage URLs into local cache; maintain `imageUUID -> storageURL` mapping and update entries post-upload.

### AI analysis (v1)

Goal
- Add text-only AI analysis that turns paragraph blocks into per-block macros and day totals, with caching and clear client/server contracts. Images, multi-model fallback, and RAG come later.

Trigger
- After a successful upsert of `content` for a day (non-empty), client calls `POST /functions/v1/ai/analyze` with `{ entryId, blocks }`.

Endpoint contract
- Headers:
  - `Authorization: Bearer <access_token>` (required)
  - `apikey: <anon_key>`
  - `Content-Type: application/json`
- Request body:
```
{
  "entryId": "uuid",
  "blocks": [
    {
      "id": "string",
      "position": 1,
      "type": "text",
      "content": "1 banana and 2 eggs"
    }
  ]
}
```
- Response body (success):
```
{
  "success": true,
  "updatedBlocksCount": 3,
  "ai_analysis_status": "completed"
}
```

Expected AI result schema (per block)
```
{
  "id": "echo from input",
  "calories": 0,
  "protein": 0.0,
  "fat": 0.0,
  "carbs": 0.0,
  "fiber": 0.0,
  "sugar": 0.0,
  "sodium": 0.0,
  "confidence": 0.0,
  "food_name": "optional, normalized",
  "serving": { "quantity": 1, "unit": "piece|g|ml|serving" }
}
```
- We copy numeric fields onto the block, and store the full object under `block.ai_analysis`.

Prompt spec (LLM)
- System prompt:
```
You are a nutrition expert. Given a single paragraph describing what a person ate, output only JSON that conforms to the schema:
{
  "id": "string",
  "calories": number,
  "protein": number,
  "fat": number,
  "carbs": number,
  "fiber": number,
  "sugar": number,
  "sodium": number,
  "confidence": number,
  "food_name": "string",
  "serving": { "quantity": number, "unit": "piece|g|ml|serving" }
}
Assume common portion sizes if unspecified; avoid unrealistic values; prefer typical USDA-like averages. Return ONLY the JSON object, no prose.
```
- User content: one block’s text with its `id`.

Backend behavior (Edge function)
- Auth & ownership: verify the `entryId` belongs to `auth.uid()` using the caller’s access token; abort 403 otherwise.
- Set `ai_analysis_status = 'processing'`.
- For each block with non-empty `content`:
  - Compute `sha256(content)`; check `ai_analysis_cache` and reuse if present.
  - Otherwise call OpenAI with model from `AI_MODEL` (default existing), `temperature <= 0.3`.
  - Parse JSON; on parse error, retry once with a stricter instruction; if still invalid, treat as zeros and low confidence.
  - Merge numeric fields onto block and attach full `ai_analysis` payload and `confidence`.
- Recompute totals using `public.calculate_diary_totals(updatedBlocks)` and update `diary_entries` totals and `blocks` atomically; set `ai_analysis_status = 'completed'`.
- On error: set `ai_analysis_status = 'failed'` and `ai_analysis_error`.
- Limits: cap blocks per call (e.g., 50) and content length per block.

Client behavior (iOS)
- Trigger after successful `upsertContent` when `content.trim() != ""`.
- Build `[Block]` array with `{ id, position, type: "text", content }` and call the function.
- UI: show processing state; poll the entry (`id=eq.{entryId}`) for `ai_analysis_status` until `completed|failed` and update totals when done.
- Retries: backoff on 429/5xx (e.g., 2s/5s/10s, max 3 attempts); allow manual retry on failure.
- Concurrency: avoid overlapping analyze calls for the same entry; cancel previous if content changes.

Future
- Persist stable `id` and `position` for each paragraph block sent to AI to preserve mapping across updates.
- Maintain a client-side map from editor paragraphs to block ids; reuse ids when content changes but the paragraph remains semantically the same.
- Store `id`, `position`, and optional `created_at` inside `diary_entries.blocks` JSON when AI results are written back; server totals remain derived from these blocks.
- Navigation and grouping continue to use `diary_entries.date` as the canonical day; per-block dates are not required.
 - Multi-model fallback and RAG with food DB can be layered later behind the same contract.

### Open questions
- Timezone: should the source of truth be server-side (based on `user_profiles.timezone_offset`) or client-only? How do we handle DST changes?
- Empty days UX: show placeholders for all N past days, or only days with entries plus today? For brand-new users, show only today or a week of placeholders?
- Entry creation: create on first keystroke vs. save button vs. background autosave cadence?
- Blocks vs content: should we persist full editor block structure client-side (including image positions) in a separate column, or is plain `content` + `images[]` enough for v1?
- Images in analyzed blocks: if we add image-based AI later, reuse the `imageUUID -> storageURL` mapping and include signed URLs in the payload.
- Totals display before AI: do we show zero, a placeholder, or hide totals until analysis completes?

### Risks and mitigations
- Editor/block mismatch with backend: keep v1 contract minimal (`content`, `images`), let DB derive simple blocks.
- Timezone inconsistencies: centralize date handling in a helper using user offset; store dates as UTC-only `date`.
- Race conditions on autosave: debounce saves and avoid overwriting newer server data; include `updated_at` precondition if needed.
- Large images / upload failures: show explicit progress and retry; cap image size client-side.

### Concrete tasks checklist
- Frontend cleanup (done)
  - Remove random calorie injection and placeholder demo text from production flows
  - Implement `updateBlocksFromTextStorage` to sync `[Block]` from editor
  - Define serialization: blocks -> `content` string; collect image URLs separately
  - Hide/remove debug overlays and excessive logging

- iOS networking (done)
  - Add diary API methods: list range, get by date, patch content/images
  - Add image upload flow (signed URL + PUT)
  - Implement local image cache + background upload queue
  - Maintain `imageUUID -> storageURL` mapping and update entries post-upload
  - Add get-or-create entry behavior on edit

- Backend contracts (done)
  - Confirm `diary_entries` schema and RLS (already present)
  - Define client->server content format and server response fields used by iOS
  - Validate `update_diary_entry_content` trigger behavior in local dev

- Day list (done)
  - Implement client-side range generation for last N days (configurable)
  - Placeholder UI for empty days; no row creation until user edits
  - Respect `timezone_offset` for day boundaries

- AI analysis (v1)
  - Backend: verify ownership (`entryId` belongs to caller) before processing
  - Backend: set `processing`, analyze blocks with cache-by-hash, write `blocks` and totals, set `completed`
  - Backend: env-driven model (`AI_MODEL`), block limit, parse-retry on invalid JSON, basic metrics/logging
  - Backend: error path sets `failed` and `ai_analysis_error`
  - iOS: build block payload from editor, trigger analyze after upsert, debounce/concurrency control
  - iOS: show processing state, poll for status, update totals on completion, retry with backoff on errors
  - QA: seed cache case (same content twice) returns without LLM call; verify totals recompute

### Deliverables for this phase
- Clean editor behavior with no mock calories in production UI
- Reliable save/read of `content` + `images` per day
- Hybrid image handling working end-to-end (local cache + storage URLs persisted)
- Day list showing last N days with proper empty states
- API surface on iOS covering list, get-or-create, update, and upload
- AI v1 working: per-block macros computed, day totals updated, cache hit path verified

### Acceptance criteria
- New user sees today plus last N days as placeholders (no crashes, no mock data visible)
- Typing into today creates/saves an entry; reopening shows persisted text
- Images added are cached locally immediately, uploaded in background, and their storage URLs are persisted; removed images are removed from the entry and cache
- After save + analyze, `ai_analysis_status` transitions `pending → processing → completed` (or `failed` on error)
- Blocks gain numeric nutrition fields and `ai_analysis` payload; day `total_*` columns reflect the sum
- Cache hit: identical block content is served from `ai_analysis_cache` without a new LLM call
- Failure path: `failed` status set with `ai_analysis_error`, user can retry; no crashes

### Implementation tasks for AI (small, testable)
- Backend – auth & ownership check in `ai/analyze`
  - Outcome: Function rejects requests where `entryId` is not owned by `auth.uid()` with 403; owned entries proceed.
  - Verify: Call with another user's token → 403; call with owner token → 200 and status flips to `processing`.
- Backend – totals recompute from analyzed blocks before updating row
  - Outcome: After analysis, `diary_entries.total_*` reflect the sum of updated block fields in the same write.
  - Verify: Seed blocks with known outputs, call analyze (or mock cache), then `select total_*` equals sum of block values.
- Backend – env-driven `AI_MODEL` with default; temperature <= 0.3
  - Outcome: Model can be switched via `AI_MODEL` env; default remains current; temperature set to <= 0.3.
  - Verify: Set `AI_MODEL=gpt-4o-mini` (or other), observe outbound `model` in logs; responses still parsed.
- Backend – block limit and empty-content short-circuit; parse-retry once
  - Outcome: Requests with > limit return 400; empty/whitespace blocks skipped; one retry on invalid JSON before fallback to zeros.
  - Verify: Send 100 blocks → 400; send empty block → skipped in update count; force malformed JSON → logged retry then zeros.
- Backend – basic metrics logs (cache hit/miss, duration); structured errors
  - Outcome: Logs include per-request block count, cache hit ratio, elapsed ms; errors include `ai_step` and message.
  - Verify: Inspect function logs for fields; provoke cache hit/miss and an error path.
- iOS – build `{ id, position, content }` payload from editor
  - Outcome: Utility produces array for current editor paragraphs with stable ids and positions.
  - Verify: Unit test comparing expected payload for sample blocks; ids remain stable across minor edits.
- iOS – call analyze after successful upsert; debounce and cancel on new edits
  - Outcome: Analyze triggers only after save, debounced; if user types again quickly, prior analyze is cancelled/skipped.
  - Verify: Add rapid edits; observe single network call; new edit cancels previous in-flight call.
- iOS – poll entry status and update UI totals on completion
  - Outcome: UI shows processing; when `completed`, editor/footer and day card totals update from server.
  - Verify: Simulate function completion; observe UI totals change and status indicator clear.
- iOS – retry/backoff policy; surface failure state with retry action
  - Outcome: On 429/5xx, client retries with backoff up to N; on `failed`, user sees retry option.
  - Verify: Stub server to return 500/429; observe 3 attempts with backoff; manual retry succeeds.
- QA – unit tests for payload builder; integration test hitting local function; cache hit scenario
  - Outcome: Tests cover payload formation, end-to-end analyze happy path, and cache reuse (no second LLM call).
  - Verify: Run tests locally/CI; assert cache table hit and no outbound AI call on second identical request.


