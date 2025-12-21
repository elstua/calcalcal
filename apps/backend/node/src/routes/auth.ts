import { Router, Request, Response } from 'express';
import { AuthService } from '../services/auth';
import { UserModel } from '../models/User';
import { v4 as uuidv4 } from 'uuid';
import { RefreshTokenModel } from '../models/RefreshToken';
import { authenticateToken, AuthRequest } from '../middleware/auth';
import Database from '../services/database';

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
      console.log('📋 Apple JWT payload keys:', Object.keys(applePayload || {}));
      console.log('📋 Apple JWT payload email:', applePayload?.email || 'not present');
      console.log('📋 Apple JWT payload name:', applePayload?.name || 'not present');
    } catch (error) {
      // Best-effort: allow sign-in to proceed for MVP
      console.warn('⚠️ Apple token verification failed, using userInfo fallback');
      applePayload = { sub: userInfo?.id };
    }

    const appleId = applePayload?.sub || userInfo?.id;
    if (!appleId) {
      return res.status(400).json({ error: 'Unable to get Apple user ID' });
    }

    // Extract user info: prioritize userInfo (from iOS credential) over JWT payload
    // Apple only provides name/email in userInfo on FIRST sign-in, not in JWT after that
    const email = userInfo?.email || applePayload?.email;
    const name = userInfo?.name || applePayload?.name;
    
    console.log('👤 Extracted user info:');
    console.log('   - Email from userInfo:', userInfo?.email || 'not provided');
    console.log('   - Email from JWT:', applePayload?.email || 'not provided');
    console.log('   - Email final:', email || 'not available');
    console.log('   - Name from userInfo:', userInfo?.name || 'not provided');
    console.log('   - Name from JWT:', applePayload?.name || 'not provided');
    console.log('   - Name final:', name || 'not available');

    // Find or create user
    console.log('🔍 Looking up user with appleId:', appleId);
    let dbUser = await UserModel.findByAppleId(appleId);
    if (!dbUser) {
      console.log('👤 User not found, creating new user');
      const userId = uuidv4();
      dbUser = await UserModel.upsertUser(
        userId,
        appleId,
        email,
        name
      );
      console.log('✅ User created:', dbUser.id);
      console.log('   - Stored email:', dbUser.email || 'none');
      console.log('   - Stored name:', dbUser.name || 'none');
    } else {
      console.log('✅ User found:', dbUser.id);
      console.log('   - Current email:', dbUser.email || 'none');
      console.log('   - Current name:', dbUser.name || 'none');
      // Fill missing fields on existing user (only if we have new data)
      // Prioritize userInfo over JWT payload, but use either if field is missing
      if (email && !dbUser.email) {
        console.log('   - Updating missing email');
        dbUser = await UserModel.update(dbUser.id, { email });
      }
      if (name && !dbUser.name) {
        console.log('   - Updating missing name');
        dbUser = await UserModel.update(dbUser.id, { name });
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

    // Validate boolean fields
    if (updates.onboarding_completed !== undefined && updates.onboarding_completed !== null) {
      if (typeof updates.onboarding_completed !== 'boolean') {
        return res.status(400).json({
          error: 'Invalid onboarding_completed',
          message: 'onboarding_completed must be a boolean value',
        });
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

// POST /api/auth/create-temporary
// Create a temporary account for users who want to skip OAuth
router.post('/create-temporary', async (req: Request, res: Response) => {
  try {
    console.log('📥 Received create-temporary request');
    
    const { deviceId } = req.body || {};
    if (!deviceId) {
      console.error('❌ Missing deviceId');
      return res.status(400).json({ success: false, error: 'deviceId is required' });
    }
    
    console.log('🔍 Checking for existing temporary account with deviceId:', deviceId);
    
    // Check if this device already has a temporary account
    let dbUser = await UserModel.findByDeviceId(deviceId);
    
    if (dbUser) {
      console.log('✅ Found existing temporary account:', dbUser.id);
    } else {
      console.log('👤 Creating new temporary account');
      dbUser = await UserModel.createTemporaryUser(deviceId);
      console.log('✅ Temporary account created:', dbUser.id);
    }
    
    // Generate session tokens
    const { accessToken, refreshToken } = AuthService.generateSessionTokens(dbUser.id);
    
    // Persist refresh token
    const refreshExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    await RefreshTokenModel.create(dbUser.id, refreshToken, refreshExpiry, {
      userAgent: req.headers['user-agent'] as string | undefined,
      ipAddress: (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || undefined,
    });
    
    // Serialize dates for JSON response
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
    
    console.log('✅ Temporary account creation successful');
    return res.json(response);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('Create temporary account error:', { message, error });
    return res.status(500).json({ 
      success: false,
      error: 'Failed to create temporary account', 
      message 
    });
  }
});

// POST /api/auth/upgrade-temporary
// Upgrade a temporary account to a permanent account with OAuth
router.post('/upgrade-temporary', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId!;
    console.log('📥 Received upgrade-temporary request for user:', userId);
    
    // Get the current user to verify it's a temporary account
    const currentUser = await UserModel.findById(userId);
    if (!currentUser) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    
    if (!currentUser.is_temporary) {
      return res.status(400).json({ 
        success: false, 
        error: 'Account is not temporary - already upgraded' 
      });
    }
    
    const { appleId, googleId, email, name } = req.body || {};
    
    if (!appleId && !googleId) {
      return res.status(400).json({ 
        success: false, 
        error: 'Either appleId or googleId is required for upgrade' 
      });
    }
    
    console.log('🔄 Upgrading temporary account with:', { appleId: !!appleId, googleId: !!googleId });
    
    // Check if the OAuth ID is already linked to another account
    if (appleId) {
      const existingApple = await UserModel.findByAppleId(appleId);
      if (existingApple && existingApple.id !== userId) {
        return res.status(409).json({ 
          success: false, 
          error: 'This Apple ID is already linked to another account' 
        });
      }
    }
    
    if (googleId) {
      const existingGoogle = await UserModel.findByGoogleId(googleId);
      if (existingGoogle && existingGoogle.id !== userId) {
        return res.status(409).json({ 
          success: false, 
          error: 'This Google account is already linked to another account' 
        });
      }
    }
    
    // Upgrade the account
    const upgradedUser = await UserModel.upgradeTemporaryAccount(
      userId,
      appleId || null,
      googleId || null,
      email,
      name
    );
    
    // Serialize dates for JSON response
    const userResponse = {
      ...upgradedUser,
      created_at: typeof upgradedUser.created_at === 'string' 
        ? upgradedUser.created_at 
        : (upgradedUser.created_at as any)?.toISOString?.() || String(upgradedUser.created_at),
      updated_at: typeof upgradedUser.updated_at === 'string'
        ? upgradedUser.updated_at
        : (upgradedUser.updated_at as any)?.toISOString?.() || String(upgradedUser.updated_at),
    };
    
    console.log('✅ Account upgraded successfully');
    return res.json({ 
      success: true, 
      user: userResponse,
      message: 'Account upgraded successfully' 
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('Upgrade temporary account error:', { message, error });
    return res.status(500).json({ 
      success: false,
      error: 'Failed to upgrade account', 
      message 
    });
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

// DELETE /api/auth/account - Delete user account and all associated data
router.delete('/account', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId!;
    const { confirmed } = req.body || {};

    // Require explicit confirmation to prevent accidental deletion
    if (!confirmed || confirmed !== 'DELETE_MY_ACCOUNT') {
      return res.status(400).json({ 
        error: 'Confirmation required',
        message: 'You must provide confirmed: "DELETE_MY_ACCOUNT" to delete your account'
      });
    }

    console.log('🗑️ Account deletion request for user:', userId);

    // Verify user exists before deletion
    const user = await UserModel.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Perform account deletion with transaction safety
    const deleted = await UserModel.deleteAccount(userId);

    if (!deleted) {
      return res.status(500).json({ 
        error: 'Failed to delete account',
        message: 'Unable to process account deletion'
      });
    }

    console.log('✅ Account deleted successfully:', {
      userId,
      email: user.email,
      accountType: user.is_temporary ? 'temporary' : 'permanent'
    });

    return res.json({
      success: true,
      message: 'Account deleted successfully',
      data: {
        deletedAt: new Date().toISOString(),
        accountType: user.is_temporary ? 'temporary' : 'permanent'
      }
    });

  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('Account deletion error:', { message, error });
    return res.status(500).json({ 
      error: 'Failed to delete account', 
      message 
    });
  }
});

// DEBUG ENDPOINTS - Only available in development
if (process.env.NODE_ENV !== 'production') {
  // DELETE /api/auth/debug/delete-user
  // Completely delete a user account and all associated data (no confirmation required)
  router.delete('/debug/delete-user', authenticateToken, async (req: AuthRequest, res: Response) => {
    try {
      const userId = req.userId!;
      console.log(`🔧 DEBUG: Force deleting user ${userId} and all associated data`);
      
      // Verify user exists before deletion
      const user = await UserModel.findById(userId);
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      
      // Delete refresh tokens first
      await RefreshTokenModel.revokeAllForUser(userId);
      
      // Delete the user record
      const result = await Database.query(
        'DELETE FROM user_profiles WHERE id = $1',
        [userId]
      );
      
      console.log(`🔧 DEBUG: User ${userId} (${user.is_temporary ? 'temporary' : 'permanent'}) deleted successfully`);
      return res.json({ 
        success: true, 
        message: 'User and all associated data deleted',
        data: {
          deletedUserId: userId,
          accountType: user.is_temporary ? 'temporary' : 'permanent',
          deviceId: user.device_id
        }
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      console.error('🔧 DEBUG: Delete user error:', { message, error });
      return res.status(500).json({ 
        success: false,
        error: 'Failed to delete user', 
        message 
      });
    }
  });
  
  // POST /api/auth/debug/cleanup-temporary-by-device
  // Clean up temporary account by device ID (no auth required)
  router.post('/debug/cleanup-temporary-by-device', async (req: Request, res: Response) => {
    try {
      const { deviceId } = req.body || {};
      if (!deviceId) {
        return res.status(400).json({ 
          success: false, 
          error: 'deviceId is required' 
        });
      }
      
      console.log(`🔧 DEBUG: Cleaning up temporary account for device: ${deviceId}`);
      
      // Find user by device ID
      const user = await UserModel.findByDeviceId(deviceId);
      if (!user) {
        return res.json({ 
          success: true, 
          message: 'No temporary account found for this device' 
        });
      }
      
      if (!user.is_temporary) {
        return res.status(400).json({ 
          success: false, 
          error: 'This device is linked to a permanent account - cannot delete via debug endpoint' 
        });
      }
      
      // Delete refresh tokens first
      await RefreshTokenModel.revokeAllForUser(user.id);
      
      // Delete the user
      await Database.query(
        'DELETE FROM user_profiles WHERE device_id = $1',
        [deviceId]
      );
      
      console.log(`🔧 DEBUG: Temporary account for device ${deviceId} deleted successfully`);
      return res.json({ 
        success: true, 
        message: 'Temporary account and all associated data deleted',
        data: {
          deletedUserId: user.id,
          deviceId: deviceId
        }
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      console.error('🔧 DEBUG: Device cleanup error:', { message, error });
      return res.status(500).json({ 
        success: false,
        error: 'Failed to cleanup temporary account', 
        message 
      });
    }
  });
}

export default router;
