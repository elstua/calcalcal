import { AuthService } from '../services/auth';

describe('AuthService session tokens', () => {
  const originalJwtSecret = process.env.JWT_SECRET;

  beforeEach(() => {
    process.env.JWT_SECRET = 'test-secret';
  });

  afterAll(() => {
    process.env.JWT_SECRET = originalJwtSecret;
  });

  it('accepts only access tokens for access verification', () => {
    const { accessToken, refreshToken } = AuthService.generateSessionTokens('user-1');

    expect(AuthService.verifyAccessToken(accessToken)).toEqual({ userId: 'user-1' });
    expect(AuthService.verifyAccessToken(refreshToken)).toBeNull();
  });

  it('accepts only refresh tokens for refresh verification', () => {
    const { accessToken, refreshToken } = AuthService.generateSessionTokens('user-1');

    expect(AuthService.verifyRefreshToken(refreshToken)).toEqual({ userId: 'user-1' });
    expect(AuthService.verifyRefreshToken(accessToken)).toBeNull();
  });
});
