import { Request, Response, NextFunction } from 'express';
import { AuthService } from '../services/auth';

export interface AuthRequest extends Request {
  userId?: string;
  file?: Express.Multer.File;
}

export function authenticateToken(
  req: AuthRequest,
  res: Response,
  next: NextFunction
) {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ')
    ? authHeader.substring(7)
    : null;

  if (!token) {
    return res.status(401).json({ error: 'Missing authorization header' });
  }

  const decoded = AuthService.verifySessionToken(token);
  if (!decoded) {
    return res.status(401).json({ error: 'Invalid token' });
  }

  req.userId = decoded.userId;
  next();
}


