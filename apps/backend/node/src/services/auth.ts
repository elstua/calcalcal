import jwt from 'jsonwebtoken';
import * as jose from 'jose';

const APPLE_PUBLIC_KEYS_URL = 'https://appleid.apple.com/auth/keys';

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

  static verifySessionToken(token: string): { userId: string } | null {
    try {
      const secret = process.env.JWT_SECRET;
      if (!secret) return null;
      const decoded = jwt.verify(token, secret) as any;
      return { userId: decoded.userId };
    } catch (_e) {
      return null;
    }
  }
}


