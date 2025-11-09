# Image attachment in calcalcal
This document defines how image attachments work in Calcal’s editor based on the latest decisions. We already have an `imageText` block in the editor (see `ARCHITECTURE.md`), and this doc pins down the UX, the minimal viable tech, and the step-by-step plan to ship.

## Basic flow
1. User taps a + button.
2. We open an Image Page (simple modal) with:
   - Camera tile at the top center.
   - Gallery grid (3 per row) below.
3. User either:
   - Takes a photo, or
   - Selects a photo from the gallery.
4. On selection we:
   - Locally insert an `imageText` block at the end of the editor (not at caret).
   - Display the actual image in the editor (no animation for v1).
   - Show a lightweight loader/ellipsis for calories/macros.
5. We compress the image on-device (JPEG, downscaled to max ~720px on the longest side; quality configurable).
6. We upload to storage:
   - Dev: directly to the backend via multipart `POST /api/storage/upload`.
   - Prod: via Cloudflare R2 presigned URL (`POST /api/storage/presign` → PUT to `uploadUrl`), then use returned `publicUrl`.
7. Backend endpoint `POST /api/ai/analyze-image` analyzes the image (single call), returning description + macros together.
8. UI updates the last `imageText` block’s text with the description and applies calories/macros to that block and totals.

Notes:
- For v1 we insert at the end of the text, not at the caret.
- We deprioritize animations for now; focus on a working pipeline.
- Keep autosave in mind: avoid duplicating “full analyze” if we already have macros from image analysis.

### Image page
Simple SwiftUI modal to minimize taps and decisions.
- Opens from the + button.
- Close by swipe-down or tapping an X in the top-right.
- Opaque dark background with some opacity to see content underneath (light blur optional).
- Center “camera tile” and a gallery grid below (3 per row).
- iOS minimum target: 18.

Permission states:
- Photos:
  - If authorized: show grid with latest photos.
  - If denied: show blurred placeholders with copy “Enable access to Photos in Settings”.
- Camera:
  - If authorized: show camera tile (simple capture).
  - If denied: show disabled state with copy “Enable access to Camera in Settings”.

#### Image component
Polaroid-like card:
- White rectangle with rounded corners (2:3-ish), square image area near the top (cropped + centered).
- Works in small (grid/editor) and large (fullscreen preview) modes.
- Large mode can show controls (… menu: delete/retake) later; minimal for v1.
- Same component is reused inside the editor.
- When tapped in the modal, it simply inserts the image at the end (no animation in v1).

Metadata:
- Each image maps to a UUID (`imageRef`) shared between UI and block model.
- Nutrition (calories/macros) attaches to the block metadata after analysis.

### gallery view
Grid of `ImageComponent`s (3 per row).
- Tap in modal → select image and close modal; insert block at the end.
- Long-press → fullscreen preview (optional later).
- On first open: request Photos permission; handle denied state with placeholders + guidance.

### camera block
An enlarged `ImageComponent` slot backed by camera capture (system camera for v1).
- On first open: request Camera permission; handle denied state with guidance.
- After capture: insert block at the end (no animation for v1).

## Process
### Decisions (locked for v1)
- Storage: Presigned S3 upload (not base64). Client compresses to JPEG and downsizes before upload.
- Note: For production we use Cloudflare R2 (S3-compatible) presigned uploads; for dev we keep local disk uploads.
- Backend analysis: Single endpoint returns both description and macros.
- Insertion: Always append to the end of the editor.
- Animations: Defer; focus on working pipeline.
- iOS min target: 18.
- Image compression: Downscale to max ~720px (longest side), JPEG quality adjustable.
- Autosave: Avoid redundant full analyze if the image analysis already set nutrition.

### Technical architecture (v1)
- iOS (SwiftUI + UIKit editor)
  - `EditorOverlay` owns `blocks` and an `imageMap: [UUID: UIImage]`.
  - `UnifiedTextEditor` renders `imageText` blocks; it shows the real image if `imageMap[imageRef]` is present.
  - On selection, we:
    - Create `imageRef = UUID()`.
    - Insert `Block.type = .imageText(Data, imageRef, "")` at the end.
    - Set `imageMap[imageRef] = UIImage` to render immediately.
    - Show loader/ellipsis in calorie area; keep keyboard focus.
  - Compress image → JPEG → downscale to 720px → data ready to upload.
  - Upload to S3 via presigned URL.
  - Call `POST /api/ai/analyze-image` with the resulting public URL (and optional entry/block identifiers).
  - Update that block’s text with returned description and apply nutrition.
  - Autosave logic: when nutrition is applied from image analysis, avoid triggering a redundant full analyze.

- Backend (Node)
  - Endpoint: `POST /api/storage/presign` → Cloudflare R2 presigned PUT URL (+ object key, public URL).
  - Endpoint: `POST /api/ai/analyze-image` → validates user, accepts `{ imageUrl, entryId?, blockId? }`, uses a multimodal provider (e.g., GPT‑4o‑mini) to produce `{ description, calories, macros, confidence }`.
  - Writes updated blocks/totals like text analysis does today (or returns data for client-side merge in v1).
  - Rate limiting & auth as per existing stack.

- AI Provider
  - One pass over the image to produce description + macros (JSON).
  - Confidence score for UI display (optional).

### API contracts (v1)
- `POST /api/storage/presign` (production, Cloudflare R2)
  - Request: `{ filename: string, contentType: string }`
  - Response: `{ uploadUrl: string, objectKey: string, publicUrl: string, headers: { "Content-Type": string } }`
  - Client PUTs the JPEG bytes to `uploadUrl` with the returned headers, then uses `publicUrl` as `imageUrl`.

- `POST /api/storage/upload` (development, local disk)
  - Multipart form-data: field `file=@...;type=image/jpeg`
  - Response: `{ publicUrl, relativeUrl, objectKey, size, contentType }`

- `POST /api/ai/analyze-image`
  - Request: `{ imageUrl: string, entryId?: string, blockId?: string }`
  - Response:
    ```json
    {
      "description": "salmon poke bowl with rice and avocado",
      "calories": 620,
      "macros": {
        "protein": 36.5,
        "fat": 25.0,
        "carbs": 62.0,
        "fiber": 6.0,
        "sugar": 8.0,
        "sodium": 780
      },
      "confidence": 0.84
    }
    ```
  - Errors: Standard JSON with `error`, `message`.

### Step‑by‑step implementation plan
1) Editor quick fix (restore image rendering)
   - `EditorOverlay` maintains `imageMap` state, passes it into `UnifiedTextEditor`.
   - On image pick, append `imageText` block at the end and set `imageMap[imageRef] = image`.
   - Show loader/ellipsis for calories.

2) iOS image compression utility
   - Downscale to max 720px (longest side), configurable JPEG quality (e.g., default 0.7).
   - Produce `Data` ready for upload and local display.

3) Backend: presign S3 upload
   - `POST /api/storage/presign` to return presigned URL + public URL.
   - Configure S3 bucket policy for public-read or signed-access as desired.

4) Backend: analyze-image endpoint
   - `POST /api/ai/analyze-image` emits description + macros in one call.
   - Option A (server updates): merges into entry blocks and totals and returns success.
   - Option B (client merges): returns description/macros; client updates block and triggers totals refresh.
   - Start with Option B for simplest client integration.

5) iOS client: upload + analyze pipeline
   - After local insert, compress → presign → upload → call analyze-image with `imageUrl`.
   - Update that last block with description + nutrition on success.
   - Post totals update notification.

6) Autosave guard
   - When nutrition already set from `analyze-image`, skip immediate full text analyze for that change.
   - Keep current autosave cadence for normal typing.

7) Image Page MLP (modal)
   - SwiftUI modal with camera tile + gallery grid, permissions.
   - Tap inserts at end; long‑press fullscreen optional later.

8) (Later) Animations and design polish
   - Matched geometry flight into editor.
   - Refined styles, transitions, streaming text.

## Implemented (backend)
- Uploads:
  - `POST /api/storage/upload` (multipart/form-data) field `file` (preferred). Saves under `/uploads/<userId>/<YYYY-MM-DD>/<uuid>.<ext>` and returns `{ publicUrl, relativeUrl, objectKey, size, contentType }`. Static served at `/uploads/*`.
  - `POST /api/storage/upload-base64` (fallback) body `{ contentType, base64Data, filename? }` with optional data URL format.
  - Requires Authorization `Bearer <access_token>`.
- Image analysis:
  - `POST /api/ai/analyze-image` body `{ imageUrl, entryId?, blockId? }`. If `imageUrl` points to localhost `/uploads`, the server inlines the image as a data URL so OpenAI can access it.
  - Returns `{ description, calories, macros { protein, fat, carbs, fiber, sugar, sodium }, confidence }`.
- Server hardening:
  - Increased JSON body limits for large payloads.
  - Added timeout and logging around OpenAI calls; logs include model, elapsed time, and parse outcomes.

### Quick test (CLI)
1) Upload (dev):
```
curl -X POST http://localhost:3000/api/storage/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/img.jpg;type=image/jpeg"
```
1b) Presign + upload (prod):
```
curl -X POST http://localhost:3000/api/storage/presign \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"contentType":"image/jpeg","filename":"example.jpg"}'
# -> get uploadUrl, publicUrl
curl -X PUT "<uploadUrl>" \
  -H "Content-Type: image/jpeg" \
  --data-binary "@/path/to/img.jpg"
```
2) Analyze:
```
curl -X POST http://localhost:3000/api/ai/analyze-image \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"imageUrl":"http://localhost:3000/uploads/<userId>/<date>/<uuid>.jpg"}'
```

## Additional requirements
- On opening, components can have a subtle entrance (optional later).
- All logic lives under an “Image Page” module/folder; editor-related bits remain in the editor.

## Implementation notes
- JPEG vs PNG: Always convert to JPEG for uploads (smaller, cheaper, faster).
- Compression settings: expose a single place for defaults (e.g., 0.7 quality), adjustable later.
- Networking: retries/backoff for upload + analysis; surface minimal error states (keep the image, show “…” if analysis fails).
- iOS 18 APIs: prefer modern Photos/Camera APIs where it simplifies permission and picking; UIKit fallback is acceptable for now.

## Implementation description
Detailed code-level notes to be added during implementation commits (editor insertion, compression helper, backend endpoints, and client wiring).
