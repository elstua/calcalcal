import { Router } from 'express';
import { authenticateToken, AuthRequest } from '../middleware/auth';
import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';
import multer, { type StorageEngine } from 'multer';
import { r2PresignPutObject } from '../services/storage/r2';

const router = Router();

router.use(authenticateToken);

// Uploads directory: must match the path used by express.static in app.ts
// In Docker: /app/uploads (compiled files are in /app/dist, so we go up two levels: dist/routes -> dist -> app)
// Locally: same relative path from compiled output works
const uploadsRoot = path.join(__dirname, '..', '..', 'uploads');

// Multer storage for multipart
const storage: StorageEngine = multer.diskStorage({
  destination: (req: AuthRequest, file: Express.Multer.File, cb: (error: any, destination: string) => void) => {
    const userId = (req as AuthRequest).userId!;
    const today = new Date().toISOString().slice(0, 10);
    const dest = path.join(uploadsRoot, userId, today);
    fs.mkdirSync(dest, { recursive: true });
    cb(null, dest);
  },
  filename: (_req: AuthRequest, file: Express.Multer.File, cb: (error: any, filename: string) => void) => {
    const ext = (path.extname(file.originalname) || '').toLowerCase() || (() => {
      const mt = (file.mimetype || '').toLowerCase();
      if (mt.includes('jpeg') || mt.includes('jpg')) return '.jpg';
      if (mt.includes('png')) return '.png';
      if (mt.includes('webp')) return '.webp';
      return '.jpg';
    })();
    cb(null, `${randomUUID()}${ext}`);
  },
});
const upload = multer({ storage });

// POST /api/storage/upload (multipart/form-data)
router.post('/upload', upload.single('file'), async (req: AuthRequest, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'file field is required' });
    }
    const userId = req.userId!;
    // req.file.path is absolute path
    // Build objectKey relative to /uploads
    const objectKey = path
      .relative(uploadsRoot, req.file.path)
      .replace(/\\/g, '/'); // normalize windows slashes
    const relativeUrl = `/uploads/${objectKey}`;
    // Use PUBLIC_BASE_URL for image URLs (e.g. https://media.calcalcal.app); fall back to R2_PUBLIC_BASE_URL so one env can drive both
    const base = (process.env.PUBLIC_BASE_URL || process.env.R2_PUBLIC_BASE_URL || '').trim();
    const publicUrl = base.length > 0 ? `${base.replace(/\/+$/, '')}${relativeUrl}` : relativeUrl;
    
    // Debug: Log URL components to detect trailing characters
    console.log(`[upload] objectKey="${objectKey}", length=${objectKey.length}`);
    console.log(`[upload] relativeUrl="${relativeUrl}", length=${relativeUrl.length}`);
    console.log(`[upload] public base URL="${base || '(not set)'}"`);
    console.log(`[upload] publicUrl="${publicUrl}", length=${publicUrl.length}, last10="${publicUrl.slice(-10)}"`);
    if (publicUrl.endsWith('.')) {
      console.warn('[upload] ⚠️ WARNING: publicUrl ends with a trailing dot!');
    }
    
    res.json({
      objectKey: `uploads/${objectKey}`,
      publicUrl,
      relativeUrl,
      contentType: req.file.mimetype,
      size: req.file.size,
    });
  } catch (err: any) {
    console.error('multipart upload error', err);
    res.status(500).json({ error: 'Failed to store upload', message: err?.message });
  }
});

// POST /api/storage/upload-base64
// Body: { contentType: string, base64Data: string, filename?: string }
// base64Data can be raw base64 or data URL like "data:image/jpeg;base64,..."
router.post('/upload-base64', async (req: AuthRequest, res) => {
  try {
    const userId = req.userId!;
    const { contentType, base64Data, filename } = req.body || {};
    if (!contentType || typeof contentType !== 'string') {
      return res.status(400).json({ error: 'contentType is required' });
    }
    if (!base64Data || typeof base64Data !== 'string') {
      return res.status(400).json({ error: 'base64Data is required' });
    }

    const ext = (() => {
      const ct = contentType.toLowerCase();
      if (ct.includes('jpeg') || ct.includes('jpg')) return 'jpg';
      if (ct.includes('png')) return 'png';
      if (ct.includes('webp')) return 'webp';
      return 'jpg';
    })();

    const today = new Date().toISOString().slice(0, 10);
    const generatedFilename = `${randomUUID()}.${ext}`;
    const objectKey = path.join(userId, today, generatedFilename).replace(/\\/g, '/');
    const fullPath = path.join(uploadsRoot, objectKey);

    // Ensure directory exists
    fs.mkdirSync(path.dirname(fullPath), { recursive: true });

    // Strip data URL prefix if present
    const commaIdx = base64Data.indexOf(',');
    const raw = base64Data.startsWith('data:') && commaIdx !== -1 ? base64Data.slice(commaIdx + 1) : base64Data;
    const buffer = Buffer.from(raw, 'base64');

    fs.writeFileSync(fullPath, buffer);

    // Build public URL (relative under /uploads, or absolute if PUBLIC_BASE_URL / R2_PUBLIC_BASE_URL set)
    const relativeUrl = `/uploads/${objectKey}`;
    const base = (process.env.PUBLIC_BASE_URL || process.env.R2_PUBLIC_BASE_URL || '').trim();
    const publicUrl = base.length > 0 ? `${base.replace(/\/+$/, '')}${relativeUrl}` : relativeUrl;

    res.json({
      objectKey: `uploads/${objectKey}`,
      publicUrl,
      relativeUrl,
      contentType,
      size: buffer.length,
    });
  } catch (err: any) {
    console.error('upload error', err);
    res.status(500).json({ error: 'Failed to store upload', message: err?.message });
  }
});

// POST /api/storage/presign (Cloudflare R2)
router.post('/presign', async (req: AuthRequest, res) => {
  try {
    const userId = req.userId!;
    const { filename, contentType } = req.body || {};
    if (!contentType || typeof contentType !== 'string') {
      return res.status(400).json({ error: 'contentType is required' });
    }
    // Require R2 env to be set
    const required = ['R2_ACCOUNT_ID', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_BUCKET'];
    for (const k of required) {
      if (!process.env[k]) {
        return res.status(500).json({ error: `Storage not configured (${k} missing)` });
      }
    }
    const presigned = await r2PresignPutObject({ userId, contentType, filename });
    res.json(presigned);
  } catch (err: any) {
    console.error('presign (R2) error', err);
    res.status(500).json({ error: 'Failed to create presigned URL', message: err?.message });
  }
});

export default router;

