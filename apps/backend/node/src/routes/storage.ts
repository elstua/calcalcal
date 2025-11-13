import { Router } from 'express';
import { authenticateToken, AuthRequest } from '../middleware/auth';
import fs from 'fs';
import path from 'path';
import { randomUUID } from 'crypto';
import multer, { type StorageEngine } from 'multer';
import { r2PresignPutObject } from '../services/storage/r2';

const router = Router();

router.use(authenticateToken);

// Multer storage for multipart
const storage: StorageEngine = multer.diskStorage({
  destination: (req: AuthRequest, file: Express.Multer.File, cb: (error: any, destination: string) => void) => {
    const userId = (req as AuthRequest).userId!;
    const today = new Date().toISOString().slice(0, 10);
    const dest = path.resolve(process.cwd(), 'apps', 'backend', 'node', 'uploads', userId, today);
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
    const uploadsRoot = path.resolve(process.cwd(), 'apps', 'backend', 'node', 'uploads');
    const objectKey = path
      .relative(uploadsRoot, req.file.path)
      .replace(/\\/g, '/'); // normalize windows slashes
    const relativeUrl = `/uploads/${objectKey}`;
    const base = process.env.PUBLIC_BASE_URL?.trim();
    const publicUrl = base && base.length > 0 ? `${base.replace(/\/+$/, '')}${relativeUrl}` : relativeUrl;
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
    const objectKey = path.join('uploads', userId, today, `${randomUUID()}.${ext}`).replace(/\\/g, '/');
    const uploadsRoot = path.resolve(process.cwd(), 'apps', 'backend', 'node', 'uploads');
    const fullPath = path.resolve(uploadsRoot, path.relative('uploads', objectKey));

    // Ensure directory exists
    fs.mkdirSync(path.dirname(fullPath), { recursive: true });

    // Strip data URL prefix if present
    const commaIdx = base64Data.indexOf(',');
    const raw = base64Data.startsWith('data:') && commaIdx !== -1 ? base64Data.slice(commaIdx + 1) : base64Data;
    const buffer = Buffer.from(raw, 'base64');

    fs.writeFileSync(fullPath, buffer);

    // Build public URL (relative under /uploads, optionally absolute if PUBLIC_BASE_URL set)
    const relativeUrl = `/${objectKey}`;
    const base = process.env.PUBLIC_BASE_URL?.trim();
    const publicUrl = base && base.length > 0 ? `${base.replace(/\/+$/, '')}${relativeUrl}` : relativeUrl;

    res.json({
      objectKey,
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


