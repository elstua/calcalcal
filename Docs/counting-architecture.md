## Counting architecture: frontend + backend

This document consolidates how day counting and nutrition totals flow across the app. It defines the data model, client logic, API contracts, backend behavior, and a validation checklist. It reflects the current text-only persistence (images deferred) and pre-AI state where totals are zero until analysis is added.

### Scope
- Frontend: day timeline generation, get-or-create behavior, text serialization, autosave, showing server totals
- Backend: `diary_entries` schema, triggers to derive `blocks` and totals from `content`, RLS
- Out of scope (for now): image upload & mapping, AI analysis

### Glossary
- Local day: A calendar day computed using the user’s timezone offset
- Blocks: Editor units in the client (text/image/spacer). For v1 persistence we serialize only text paragraphs
- Content: A single `text` column persisted on the server, produced by joining text paragraphs with a double newline

---

## Data model (backend)

Table `public.diary_entries` (subset relevant to v1):
- `id uuid` primary key
- `user_id uuid` (RLS-enforced to `auth.uid()`)
- `date date` user-local day (stored as UTC `date`)
- `content text` — joined paragraphs from client
- `blocks jsonb` — derived from `content` (text paragraphs with stable fields)
- Totals: `total_calories integer`, `total_protein decimal`, `total_fat decimal`, `total_carbs decimal`, `total_fiber decimal`, `total_sugar decimal`, `total_sodium decimal`
- `images text[]` — deferred in v1
- `created_at`, `updated_at`
- `unique(user_id, date)`

RLS policies restrict all CRUD to the authenticated user (see migrations).

### Derivation functions and triggers
- `parse_content_into_blocks(content_text text) returns jsonb` — splits `content` on double newlines into text blocks, initializes nutrition fields with zero
- `calculate_diary_totals(blocks_json jsonb) returns jsonb` — sums nutrition across blocks
- `set_diary_entry_content_derived()` — trigger function that:
  - On INSERT: derives `blocks` and totals from `content`
  - On UPDATE (when `content` changes): re-derives `blocks` and totals; sets `ai_analysis_status = 'pending'`
- Triggers:
  - BEFORE INSERT ON `diary_entries` → `set_diary_entry_content_derived()`
  - BEFORE UPDATE ON `diary_entries` → `set_diary_entry_content_derived()`

Result: Server is the source of truth for `blocks` and totals, derived from `content` on both create and update.

---

## Client-side editor model

Types in iOS client:
- `BlockType`: `.text(String)`, `.image(Data, UUID)`, `.imageText(Data, UUID, String)`, `.spacer`
- `Block`: `{ type: BlockType, calorieData: String? }` (UI metadata only for now)
- `DiaryEntry`: `{ id: UUID, date: Date, blocks: [Block], totalCalories: Int?, lastModified: Date, aiGeneratedSummary: String? }`

### Serialization (v1)
- Blocks → `content` string: take text-bearing blocks and join their text with a double newline
- `content` → blocks: split by double newline, produce `.text` blocks
- Image/spacer info is not persisted in v1

Utilities (client):
- `[Block].toContentString()`
- `String.toTextBlocks()`

---

## Day timeline (frontend)

Helpers:
- `LocalDayMath.startOfLocalDay(for:offsetMinutes:)`
- `LocalDayMath.yyyymmdd(for:offsetMinutes:)`
- `LocalDayMath.localDayStartUTC(anchor:offsetMinutes:daysBack:)`
- `DayTimelineGenerator` builds a sparse timeline with collapsed empty runs per the product rules

Behavior:
- Default window: last 30 days anchored at today
- No pre-created DB rows for empty days; placeholders are client-rendered
- Collapsed runs for >14 consecutive empty days; expandable in 14-day steps

---

## Networking (client)

Headers on REST calls:
- `Authorization: Bearer <access_token>` (from keychain session)
- `apikey: <anon_key>`

Endpoints (PostgREST):
- List range: `GET /rest/v1/diary_entries?select=id,user_id,date,content,images,total_calories,updated_at&date=gte.{from}&date=lte.{to}&order=date.desc`
- Get by date: `GET /rest/v1/diary_entries?select=id,user_id,date,content,images,total_calories,updated_at&date=eq.{YYYY-MM-DD}&limit=1`
- Insert: `POST /rest/v1/diary_entries` body `[ { user_id, date, content, images: [] } ]`, header `Prefer: resolution=merge-duplicates, return=representation`
- Update content: `PATCH /rest/v1/diary_entries?id=eq.{id}` body `{ content }`, header `Prefer: return=representation`

Client wrapper (`DiaryAPI`):
- `listEntries(dateFrom:dateTo:) -> [Row]`
- `getByDate(_:) -> Row?`
- `insert(date:content:userId:) -> Row`
- `updateContent(id:content:) -> Row`
- `upsertContent(date:userId:content:) -> Row` (get-or-create)

---

## Editor interactions

Get-or-create today:
- On first actual typing (non-placeholder, non-empty), autosave calls `upsertContent(date:userId:content:)`
- If the row exists: `UPDATE content` triggers re-derivation on server
- If the row doesn’t exist: `INSERT` with content triggers derivation on server

Autosave policy:
- Debounce: 1s after change, flush on close
- Last-write-wins: device favors local content and writes without preconditions (can add `updated_at` guards later)

Totals display:
- After upsert returns, client reads `total_calories` from response rows
- Editor updates its footer immediately
- A notification (`diaryEntryTotalsUpdated`) updates day list cards for the same entry id

Notifications:
- `editorOverlayDidCommit` — overlay closed; writes blocks back to list
- `diaryEntryTotalsUpdated` — payload `{ entryId: UUID, totalCalories: Int? }`

---

## Validation checklist (text-only)

Environment
- Ensure Supabase is reachable from target (Simulator can use `127.0.0.1`; physical device requires LAN IP)
- Sign in so `current_user_id` is stored (UserDefaults key used by insert)

Initial load
- Open diary → last 30 days load via `listEntries`
- If the account is new, placeholders show and no network rows exist

Get-or-create
- Tap today placeholder, type a non-placeholder line
- Console shows: scheduled → firing → upserting → success/error
- DB row inserted for today with `content` set; `blocks` derived as non-empty array

Update
- Edit text again; console logs and DB row `updated_at` changes
- `blocks` and totals re-derived (totals remain zero before AI)

Totals
- Editor footer shows `… kcal` initially, then switches to `0 kcal` after first success
- Day card shows the same total after `diaryEntryTotalsUpdated`

Edge cases
- Empty/placeholder text is ignored (no insert/update)
- Missing `current_user_id` delays insert until auth is restored
- Timezone: `LocalDayMath` ensures `YYYY-MM-DD` key matches user-local midnight

---

## Future: AI analysis (outline)

Trigger:
- After content save (or explicit action), client sends `{ entryId, blocks }` to `functions/v1/ai/analyze`

Server:
- Uses cache by content hash when possible
- Updates `diary_entries.blocks` with per-block nutrition; recomputes totals
- Sets `ai_analysis_status` to `completed`/`failed`

Client:
- Poll or subscribe to entry updates
- Replace zero totals with computed values and show per-block nutrition

---

## Notes on images (deferred)
- Upload binary to Supabase Storage bucket `images` via signed URL
- Persist only storage paths/URLs in `diary_entries.images`
- Maintain `imageUUID -> { localPath, storageURL? }` mapping; background upload and update entry after URL is available


