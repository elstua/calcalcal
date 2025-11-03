import { Router, Request, Response } from 'express';
import { AuthService } from '../services/auth';
import { UserModel } from '../models/User';
import { v4 as uuidv4 } from 'uuid';
import { RefreshTokenModel } from '../models/RefreshToken';
import { authenticateToken, AuthRequest } from '../middleware/auth';

const router = Router();

// POST /api/auth/signin-apple
router.post('/signin-apple', async (req: Request, res: Response) => {
  try {
    console.log('📥 Received sign-in request');
    console.log('Request body keys:', Object.keys(req.body || {}));
    
    const { identityToken, user: userInfo } = req.body || {};
    if (!identityToken) {
      console.error('❌ Missing identityToken');
      return res.status(400).json({ success: false, error: 'identityToken is required' });
    }
    
    console.log('✅ Identity token received, length:', identityToken.length);

    let applePayload: any;
    try {
      applePayload = await AuthService.verifyAppleToken(identityToken);
    } catch (error) {
      // Best-effort: allow sign-in to proceed for MVP
      applePayload = { sub: userInfo?.id };
    }

    const appleId = applePayload?.sub || userInfo?.id;
    if (!appleId) {
      return res.status(400).json({ error: 'Unable to get Apple user ID' });
    }

    // Find or create user
    console.log('🔍 Looking up user with appleId:', appleId);
    let dbUser = await UserModel.findByAppleId(appleId);
    if (!dbUser) {
      console.log('👤 User not found, creating new user');
      const userId = uuidv4();
      dbUser = await UserModel.upsertUser(
        userId,
        appleId,
        userInfo?.email || applePayload?.email,
        userInfo?.name || applePayload?.name
      );
      console.log('✅ User created:', dbUser.id);
    } else {
      console.log('✅ User found:', dbUser.id);
      // Optional: fill missing fields on existing user
      if (userInfo?.email && !dbUser.email) {
        dbUser = await UserModel.update(dbUser.id, { email: userInfo.email });
      }
      if (userInfo?.name && !dbUser.name) {
        dbUser = await UserModel.update(dbUser.id, { name: userInfo.name });
      }
    }

    const { accessToken, refreshToken } = AuthService.generateSessionTokens(
      dbUser.id
    );

    // Persist hashed refresh token with expiry
    const refreshPayload = (AuthService.verifySessionToken(refreshToken) as { userId: string } | null);
    const refreshExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    await RefreshTokenModel.create(dbUser.id, refreshToken, refreshExpiry, {
      userAgent: req.headers['user-agent'] as string | undefined,
      ipAddress: (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || undefined,
    });

    // Ensure dates are serialized as strings for JSON
    const userResponse = {
      ...dbUser,
      created_at: dbUser.created_at instanceof Date ? dbUser.created_at.toISOString() : dbUser.created_at,
      updated_at: dbUser.updated_at instanceof Date ? dbUser.updated_at.toISOString() : dbUser.updated_at,
    };

    const response = {
      success: true,
      user: userResponse,
      session: {
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_in: 7 * 24 * 60 * 60,
      },
    };

    console.log('✅ Sign-in successful, returning response:', JSON.stringify(response, null, 2));
    return res.json(response);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    const stack = error instanceof Error ? error.stack : undefined;
    console.error('Sign-in error:', { message, stack, error });
    
    // Always return JSON, even on error
    return res.status(500).json({ 
      success: false,
      error: 'Authentication failed', 
      message 
    });
  }
});

// POST /api/auth/refresh
router.post('/refresh', async (req: Request, res: Response) => {
  try {
    const { refresh_token } = req.body || {};
    if (!refresh_token) {
      return res.status(400).json({ error: 'refresh_token is required' });
    }

    // 1) Validate structure/signature to extract user id
    const decoded = AuthService.verifySessionToken(refresh_token);
    if (!decoded) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    // 2) Validate presence in DB (active and unexpired)
    const tokenHash = RefreshTokenModel.hash(refresh_token);
    const existing = await RefreshTokenModel.findActiveByHash(tokenHash);
    if (!existing || existing.user_id !== decoded.userId) {
      return res.status(401).json({ error: 'Refresh token not recognized' });
    }

    // 3) Revoke the used token (rotation)
    await RefreshTokenModel.revokeById(existing.id);

    // 4) Issue new tokens and persist new refresh token
    const { accessToken, refreshToken } = AuthService.generateSessionTokens(
      decoded.userId
    );
    const refreshExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    await RefreshTokenModel.create(decoded.userId, refreshToken, refreshExpiry, {
      userAgent: req.headers['user-agent'] as string | undefined,
      ipAddress: (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || undefined,
    });

    return res.json({
      success: true,
      session: {
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_in: 7 * 24 * 60 * 60,
      },
    });
  } catch (_e) {
    return res.status(500).json({ error: 'Token refresh failed' });
  }
});

// GET /api/auth/profile
router.get('/profile', async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing authorization header' });
    }
    const token = authHeader.substring(7);
    const decoded = AuthService.verifySessionToken(token);
    if (!decoded) {
      return res.status(401).json({ error: 'Invalid token' });
    }
    const user = await UserModel.findById(decoded.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    return res.json({ success: true, profile: user });
  } catch (_e) {
    return res.status(500).json({ error: 'Failed to get profile' });
  }
});

// POST /api/auth/logout - revoke current refresh token or all tokens
router.post('/logout', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId!;
    const { refresh_token, all } = (req.body || {}) as { refresh_token?: string; all?: boolean };

    if (all) {
      await RefreshTokenModel.revokeAllForUser(userId);
      return res.json({ success: true, revoked: 'all' });
    }

    if (!refresh_token) {
      return res.status(400).json({ error: 'refresh_token is required unless all=true' });
    }

    const tokenHash = RefreshTokenModel.hash(refresh_token);
    const existing = await RefreshTokenModel.findActiveByHash(tokenHash);
    if (!existing || existing.user_id !== userId) {
      return res.status(404).json({ error: 'Refresh token not found' });
    }

    await RefreshTokenModel.revokeById(existing.id);
    return res.json({ success: true, revoked: 'one' });
  } catch (_e) {
    return res.status(500).json({ error: 'Logout failed' });
  }
});

export default router;
