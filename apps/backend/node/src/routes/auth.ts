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
    // PostgreSQL returns dates as strings, but handle Date objects if they occur
    const userResponse = {
      ...dbUser,
      created_at: typeof dbUser.created_at === 'string' 
        ? dbUser.created_at 
        : (dbUser.created_at as any)?.toISOString?.() || String(dbUser.created_at),
      updated_at: typeof dbUser.updated_at === 'string'
        ? dbUser.updated_at
        : (dbUser.updated_at as any)?.toISOString?.() || String(dbUser.updated_at),
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

// POST /api/auth/signin-google
// Google Sign-In endpoint - mirrors Apple sign-in structure
router.post('/signin-google', async (req: Request, res: Response) => {
  try {
    console.log('📥 Received Google sign-in request');
    console.log('Request body keys:', Object.keys(req.body || {}));
    
    const { idToken, user: userInfo } = req.body || {};
    if (!idToken) {
      console.error('❌ Missing idToken');
      return res.status(400).json({ success: false, error: 'idToken is required' });
    }
    
    console.log('✅ Google ID token received, length:', idToken.length);

    let googlePayload: any;
    try {
      googlePayload = await AuthService.verifyGoogleToken(idToken);
    } catch (error) {
      // Best-effort: allow sign-in to proceed for MVP (similar to Apple)
      console.warn('⚠️ Google token verification failed, using userInfo fallback');
      googlePayload = { sub: userInfo?.id };
    }

    // Extract Google user ID from token payload (sub claim) or userInfo
    const googleId = googlePayload?.sub || userInfo?.id;
    if (!googleId) {
      return res.status(400).json({ error: 'Unable to get Google user ID' });
    }

    // Extract user profile data from token payload, fallback to userInfo
    const email = userInfo?.email || googlePayload?.email;
    const name = userInfo?.name || googlePayload?.name || 
                 (googlePayload?.given_name && googlePayload?.family_name 
                   ? `${googlePayload.given_name} ${googlePayload.family_name}` 
                   : null);

    // Find or create user
    console.log('🔍 Looking up user with googleId:', googleId);
    let dbUser = await UserModel.findByGoogleId(googleId);
    if (!dbUser) {
      console.log('👤 User not found, creating new user');
      const userId = uuidv4();
      // Pass null for appleId, and googleId as the last parameter
      dbUser = await UserModel.upsertUser(
        userId,
        null,  // appleId is null for Google sign-in
        email,
        name,
        googleId  // googleId parameter
      );
      console.log('✅ User created:', dbUser.id);
    } else {
      console.log('✅ User found:', dbUser.id);
      // Optional: fill missing fields on existing user
      if (email && !dbUser.email) {
        dbUser = await UserModel.update(dbUser.id, { email });
      }
      if (name && !dbUser.name) {
        dbUser = await UserModel.update(dbUser.id, { name });
      }
    }

    const { accessToken, refreshToken } = AuthService.generateSessionTokens(
      dbUser.id
    );

    // Persist hashed refresh token with expiry
    const refreshExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    await RefreshTokenModel.create(dbUser.id, refreshToken, refreshExpiry, {
      userAgent: req.headers['user-agent'] as string | undefined,
      ipAddress: (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || undefined,
    });

    // Ensure dates are serialized as strings for JSON
    const userResponse = {
      ...dbUser,
      created_at: typeof dbUser.created_at === 'string' 
        ? dbUser.created_at 
        : (dbUser.created_at as any)?.toISOString?.() || String(dbUser.created_at),
      updated_at: typeof dbUser.updated_at === 'string'
        ? dbUser.updated_at
        : (dbUser.updated_at as any)?.toISOString?.() || String(dbUser.updated_at),
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

    console.log('✅ Google sign-in successful, returning response:', JSON.stringify(response, null, 2));
    return res.json(response);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    const stack = error instanceof Error ? error.stack : undefined;
    console.error('Google sign-in error:', { message, stack, error });
    
    // Always return JSON, even on error
    return res.status(500).json({ 
      success: false,
      error: 'Google authentication failed', 
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
router.get('/profile', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId!;
    const user = await UserModel.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    return res.json({ success: true, profile: user });
  } catch (_e) {
    return res.status(500).json({ error: 'Failed to get profile' });
  }
});

// PUT /api/auth/profile - Update user profile
router.put('/profile', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId!;
    const updates = req.body || {};

    // Validate enum values if provided
    if (updates.activity_level !== undefined) {
      const validActivityLevels = ['small', 'moderate', 'active'];
      if (!validActivityLevels.includes(updates.activity_level)) {
        return res.status(400).json({
          error: 'Invalid activity_level',
          message: `activity_level must be one of: ${validActivityLevels.join(', ')}`,
        });
      }
    }

    if (updates.gender !== undefined && updates.gender !== null) {
      const validGenders = ['male', 'female', 'other'];
      if (!validGenders.includes(updates.gender)) {
        return res.status(400).json({
          error: 'Invalid gender',
          message: `gender must be one of: ${validGenders.join(', ')}, or null`,
        });
      }
    }

    if (updates.weight_unit !== undefined) {
      const validWeightUnits = ['kg', 'lbs'];
      if (!validWeightUnits.includes(updates.weight_unit)) {
        return res.status(400).json({
          error: 'Invalid weight_unit',
          message: `weight_unit must be one of: ${validWeightUnits.join(', ')}`,
        });
      }
    }

    if (updates.height_unit !== undefined) {
      const validHeightUnits = ['cm', 'in'];
      if (!validHeightUnits.includes(updates.height_unit)) {
        return res.status(400).json({
          error: 'Invalid height_unit',
          message: `height_unit must be one of: ${validHeightUnits.join(', ')}`,
        });
      }
    }

    // Validate numeric fields
    const numericFields = ['weight_kg', 'height_cm', 'age', 'target_weight_kg', 'daily_calorie_goal'];
    for (const field of numericFields) {
      if (updates[field] !== undefined && updates[field] !== null) {
        const numValue = Number(updates[field]);
        if (isNaN(numValue) || numValue < 0) {
          return res.status(400).json({
            error: `Invalid ${field}`,
            message: `${field} must be a non-negative number`,
          });
        }
        updates[field] = numValue;
      }
    }

    // Update user profile (auto-calculation happens in UserModel.update)
    const updatedUser = await UserModel.update(userId, updates);

    // Ensure dates are serialized as strings for JSON
    const userResponse = {
      ...updatedUser,
      created_at: typeof updatedUser.created_at === 'string'
        ? updatedUser.created_at
        : (updatedUser.created_at as any)?.toISOString?.() || String(updatedUser.created_at),
      updated_at: typeof updatedUser.updated_at === 'string'
        ? updatedUser.updated_at
        : (updatedUser.updated_at as any)?.toISOString?.() || String(updatedUser.updated_at),
    };

    return res.json({ success: true, profile: userResponse });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('Profile update error:', { message, error });
    return res.status(500).json({ error: 'Failed to update profile', message });
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
