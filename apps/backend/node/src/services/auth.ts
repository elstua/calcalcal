import jwt from 'jsonwebtoken';
import * as jose from 'jose';

const APPLE_PUBLIC_KEYS_URL = 'https://appleid.apple.com/auth/keys';
const GOOGLE_PUBLIC_KEYS_URL = 'https://www.googleapis.com/oauth2/v3/certs';

type SessionTokenType = 'access' | 'refresh';

export class AuthService {
  static async verifyAppleToken(identityToken: string) {
    try {
      const JWKS = jose.createRemoteJWKSet(new URL(APPLE_PUBLIC_KEYS_URL));
      const audience = process.env.APPLE_AUDIENCE;
      const verifyOptions: jose.JWTVerifyOptions = {
        issuer: 'https://appleid.apple.com',
        ...(audience ? { audience } : {}),
      };
      const { payload } = await jose.jwtVerify(identityToken, JWKS, verifyOptions);
      return payload as any;
    } catch (_e) {
      throw new Error('Invalid Apple token');
    }
  }

  /**
   * Verify Google ID token using Google's public keys (JWKS)
   * Returns the token payload containing user data:
   * - sub: Google user ID (unique identifier)
   * - email: User's email address
   * - email_verified: Boolean indicating if email is verified
   * - name: Full name
   * - given_name: First name
   * - family_name: Last name
   * - picture: Profile picture URL
   */
  static async verifyGoogleToken(idToken: string) {
    try {
      const JWKS = jose.createRemoteJWKSet(new URL(GOOGLE_PUBLIC_KEYS_URL));
      const googleClientId = process.env.GOOGLE_CLIENT_ID;
      
      // Google tokens can have two possible issuers
      const verifyOptions: jose.JWTVerifyOptions = {
        issuer: ['accounts.google.com', 'https://accounts.google.com'],
        ...(googleClientId ? { audience: googleClientId } : {}),
      };
      
      const { payload } = await jose.jwtVerify(idToken, JWKS, verifyOptions);
      return payload as any;
    } catch (_e) {
      throw new Error('Invalid Google token');
    }
  }

  static generateSessionTokens(userId: string) {
    const secret = process.env.JWT_SECRET;
    if (!secret) throw new Error('Missing JWT_SECRET');

    const accessToken = jwt.sign({ userId, type: 'access' }, secret, {
      expiresIn: '7d',
    });
    const refreshToken = jwt.sign({ userId, type: 'refresh' }, secret, {
      expiresIn: '30d',
    });
    return { accessToken, refreshToken };
  }

  private static verifySessionToken(
    token: string,
    expectedType: SessionTokenType
  ): { userId: string } | null {
    try {
      const secret = process.env.JWT_SECRET;
      if (!secret) return null;
      const decoded = jwt.verify(token, secret) as any;
      if (decoded.type !== expectedType || typeof decoded.userId !== 'string') {
        return null;
      }
      return { userId: decoded.userId };
    } catch (_e) {
      return null;
    }
  }

  static verifyAccessToken(token: string): { userId: string } | null {
    return this.verifySessionToken(token, 'access');
  }

  static verifyRefreshToken(token: string): { userId: string } | null {
    return this.verifySessionToken(token, 'refresh');
  }
}

