import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import authRoutes from './routes/auth';
import diaryRoutes from './routes/diary';
import aiRoutes from './routes/ai';
import storageRoutes from './routes/storage';

// Load env in this order: .env.local, then fallback to ENV.example if exists
if (fs.existsSync('.env.local')) {
  dotenv.config({ path: '.env.local' });
} else if (fs.existsSync('ENV.example')) {
  dotenv.config({ path: 'ENV.example' });
}

const app: Express = express();

app.use(cors());
app.use(express.json({ limit: '8mb' }));
app.use(express.urlencoded({ extended: true, limit: '8mb' }));

// Request logging middleware
app.use((req: Request, res: Response, next) => {
  if (req.path.startsWith('/api/')) {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  }
  next();
});

// Static uploads serving
const uploadsDir = path.resolve(process.cwd(), 'apps', 'backend', 'node', 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}
app.use('/uploads', express.static(uploadsDir));

app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/diary', diaryRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/storage', storageRoutes);

// Error handling middleware - must be last
app.use((err: any, req: Request, res: Response, next: any) => {
  console.error('Unhandled error:', err);
  // Always return JSON, never HTML
  res.status(err.status || 500).json({
    success: false,
    error: err.message || 'Internal server error',
  });
});

// 404 handler - must be after all routes
app.use((req: Request, res: Response) => {
  res.status(404).json({
    success: false,
    error: 'Not found',
  });
});

export default app;
