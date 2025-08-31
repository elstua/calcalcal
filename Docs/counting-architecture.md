## Counting architecture: frontend + backend

This document consolidates how day counting and nutrition totals flow across the app. It defines the data model, client logic, API contracts, backend behavior, AI analysis integration, and a validation checklist. It reflects the current text-only persistence (images deferred) with active AI analysis providing nutrition data and calorie counting.

### Scope
- Frontend: day timeline generation, get-or-create behavior, text serialization, autosave, async task management, AI analysis integration
- Backend: `diary_entries` schema, triggers to derive `blocks` and totals from `content`, RLS, AI analysis endpoints
- Out of scope (for now): image upload & mapping

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
- **List range**: `GET /rest/v1/diary_entries?select=id,user_id,date,content,images,total_calories,updated_at&date=gte.{from}&date=lte.{to}&order=date.desc`
- **Get by date**: `GET /rest/v1/diary_entries?select=id,user_id,date,content,images,total_calories,updated_at&date=eq.{YYYY-MM-DD}&limit=1`
- **Get blocks**: `GET /rest/v1/diary_entries?select=blocks&id=eq.{id}&limit=1`
- **Insert**: `POST /rest/v1/diary_entries` body `[ { user_id, date, content, images: [] } ]`, header `Prefer: resolution=merge-duplicates, return=representation`
- **Update content**: `PATCH /rest/v1/diary_entries?id=eq.{id}` body `{ content }`, header `Prefer: return=representation`

AI Analysis Endpoints:
- **Full analysis**: `POST /functions/v1/ai/analyze` body `{ entryId, blocks: [...] }`
- **Incremental analysis**: `POST /functions/v1/ai/analyze-incremental` body `{ entryId, blocks: [...], existingBlocks: [...] }`
- **Clear nutrition**: `POST /functions/v1/ai/clear-nutrition` body `{ entryId }`

Client wrapper (`DiaryAPI`):
- `listEntries(dateFrom:dateTo:) -> [Row]`
- `getByDate(_:) -> Row?`
- `insert(date:content:userId:) -> Row`
- `updateContent(id:content:) -> Row`
- `upsertContent(date:userId:content:) -> Row` (get-or-create)
- `getBlocksById(_:) -> [DBBlock]` (load nutrition data)
- `analyze(entryId:blocksPayload:) -> AnalyzeResponse` (full AI analysis)
- `analyzeIncremental(entryId:blocksPayload:existingBlocks:) -> AnalyzeResponse` (incremental AI analysis)
- `getAnalyzedBlocksById(_:) -> [DBBlock]` (check existing nutrition data)

---

## Editor interactions

### Client Architecture

**MainTabView** manages the shared state:
- `@State private var presentedBlocks: [Block]` - shared binding passed to EditorOverlay
- `onRequestOpen` sets `presentedBlocks = entry.blocks` and opens EditorOverlay
- `onClose` posts `editorOverlayDidCommit` notification to update DiaryListView

**EditorOverlay** handles editing:
- Receives `@Binding var blocks: [Block]` from MainTabView
- Manages async tasks: `loadTask` (loading nutrition data), `autosaveTask` (saving + AI analysis)
- **Critical**: Cancels all async tasks on `onDisappear` to prevent cross-contamination

**DiaryListView** maintains the entry list:
- Listens to `editorOverlayDidCommit` to update `entries[index].blocks`
- Maintains local entry state with placeholder blocks for new days

### Get-or-create behavior:
- **New day**: Local `DiaryEntry` created with `id: UUID()` and placeholder blocks
- **First typing**: Autosave calls `upsertContent(date:userId:content:)` 
- **ID mismatch resolution**: Database creates entry with `gen_random_uuid()` (different from local UUID)
- **Block loading**: Uses `getBlocksById(entry.id)` to load nutrition data from database

### Autosave policy:
- **Trigger**: Paragraph commit notifications (not every keystroke)
- **Debounce**: 1s after notification, immediate flush on overlay close
- **AI analysis**: Triggered after successful database save
- **Polling**: 4-step backoff (0.8s, 1.2s, 2.0s, 2.8s) to load nutrition updates
- **Task cancellation**: All async tasks cancelled on overlay dismissal to prevent contamination

### Totals display:
- **Initial**: Shows cached `entry.totalCalories` or "..." if unknown
- **After save**: Updates from `row.total_calories` in upsert response
- **After AI**: Updates via polling loop calling `getById(row.id)`
- **Live updates**: `liveTotalCalories` state provides immediate UI feedback

### Notification System:

**Core Notifications**:
- `editorOverlayDidCommit` — overlay closed; payload: `{ entryId: UUID, blocks: [Block] }`
  - Posted by MainTabView.onClose with `presentedBlocks`
  - Received by DiaryListView to update `entries[index].blocks`
  - Updates correct entry by matching `entryId` with `entries[index].id`

- `diaryEntryTotalsUpdated` — totals changed; payload: `{ entryId: UUID, totalCalories: Int? }`
  - Posted during AI analysis polling when totals are updated
  - Updates `entries[index].totalCalories` in DiaryListView
  - Updates `liveTotalCalories` in EditorOverlay for live UI feedback

**Autosave Trigger Notifications**:
- `editorParagraphCommitted` — user pressed Enter; triggers autosave scheduling
- `editorSavedParagraphEdited` — editing previously saved content; triggers autosave

---

## Validation checklist (with AI analysis)

### Environment
- Ensure Supabase is reachable from target (Simulator can use `127.0.0.1`; physical device requires LAN IP)
- Sign in so `current_user_id` is stored (UserDefaults key used by insert)
- AI analysis endpoints must be deployed and accessible

### Initial load
- Open diary → last 30 days load via `listEntries`
- If the account is new, placeholders show and no network rows exist
- Existing entries load with nutrition data via `getBlocksById`

### Get-or-create with AI analysis
- Tap today placeholder, type food description (e.g., "pizza slice")
- Console shows: scheduled → firing → upserting → success → AI analysis triggered
- DB row inserted for today with `content` set; `blocks` derived initially with zero nutrition
- AI analysis runs and updates `blocks` with nutrition data
- Polling loop retrieves nutrition updates (0.8s, 1.2s, 2.0s, 2.8s intervals)
- UI shows live calorie updates as nutrition data arrives

### Update with incremental analysis
- Edit existing text → incremental analysis compares with existing blocks
- Only changed/new blocks sent for AI analysis (optimization)
- Existing nutrition data preserved for unchanged blocks

### Totals flow
- **Initial**: Editor footer shows cached `entry.totalCalories` or "..."
- **After save**: Shows `row.total_calories` from upsert response (usually 0 initially)
- **After AI**: Updates to actual calculated calories via polling
- **Live updates**: `liveTotalCalories` provides immediate feedback

### Cross-contamination prevention
- **Task cancellation**: All async tasks cancelled on overlay dismissal
- **Safe dismissal**: `flushSave()` uses `saveWithoutAIAnalysis()` to prevent new AI tasks
- **Cancellation checks**: AI polling loops check `Task.isCancelled` before database calls

### Edge cases
- Empty/placeholder text is ignored (no insert/update)
- Missing `current_user_id` delays insert until auth is restored
- Network errors during AI analysis are logged but don't break save functionality
- Timezone: `LocalDayMath` ensures `YYYY-MM-DD` key matches user-local midnight
- Multiple overlays: Async task cancellation prevents content cross-contamination

---

## Known Issues & Fixes

### Content Cross-Contamination Bug (FIXED)

**Issue**: Opening diary entries would sometimes show content from other days instead of the correct content.

**Root Cause**: Multiple EditorOverlay instances created overlapping async tasks (AI analysis polling) that would complete after overlay dismissal, contaminating new overlays via shared `@Binding var blocks` state.

**Symptoms**:
- Content appeared correct initially but switched after 1-2 seconds  
- Only happened after creating new content (triggered AI analysis)
- Debug logs showed `getBlocksById` calls with wrong entry IDs

**Solution Implemented**:
1. **Task tracking**: Added `loadTask` and `autosaveTask` state variables
2. **Comprehensive cancellation**: Cancel all async tasks on `onDisappear`  
3. **Safe dismissal**: `flushSave()` uses `saveWithoutAIAnalysis()` to prevent new AI tasks
4. **Cancellation checks**: Added `Task.isCancelled` guards throughout AI analysis flow

**Prevention**: All future async operations in EditorOverlay must be cancellable and tracked.

---

### Backend Database Schema

**Database Constraints**:
- `unique(user_id, date)` ensures one entry per user per day
- `gen_random_uuid()` generates database IDs (different from client UUIDs)
- RLS policies restrict access to authenticated user's data

**ID Management**:
- **Client**: Creates entries with `UUID()` for immediate UI responsiveness
- **Database**: Uses `gen_random_uuid()` for persistence (returned in upsert response)
- **Resolution**: Client uses database ID for all subsequent API calls
- **Block loading**: Always uses database ID via `getBlocksById(databaseId)`

**Upsert Behavior** (`upsertContent`):
- Uses `date` and `user_id` to find existing entry (not client UUID)
- Creates new entry if none exists for that date
- Updates content if entry already exists for that date
- Returns database entry with server-generated ID and totals

---

## Notes on images (deferred)
- Upload binary to Supabase Storage bucket `images` via signed URL
- Persist only storage paths/URLs in `diary_entries.images`
- Maintain `imageUUID -> { localPath, storageURL? }` mapping; background upload and update entry after URL is available


