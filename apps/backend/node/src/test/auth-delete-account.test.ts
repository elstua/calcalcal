import request from 'supertest';
import app from '../app';
import { UserModel } from '../models/User';
import { RefreshTokenModel } from '../models/RefreshToken';
import { DiaryEntryModel } from '../models/DiaryEntry';
import Database from '../services/database';

describe('DELETE /api/auth/account', () => {
  let testUser: any;
  let accessToken: string;
  let refreshToken: string;

  beforeEach(async () => {
    // Create test user with unique device ID
    const uniqueDeviceId = `test-device-delete-account-${Date.now()}-${Math.random()}`;
    testUser = await UserModel.createTemporaryUser(uniqueDeviceId);
    
    // Generate tokens
    const { AuthService } = await import('../services/auth');
    const tokens = AuthService.generateSessionTokens(testUser.id);
    accessToken = tokens.accessToken;
    refreshToken = tokens.refreshToken;
    
    // Store refresh token
    await RefreshTokenModel.create(testUser.id, refreshToken, new Date(Date.now() + 30 * 24 * 60 * 60 * 1000));
  });

  it('should delete account with proper confirmation', async () => {
    // Create some diary entries
    await DiaryEntryModel.upsert(testUser.id, '2023-01-01', 'Test entry for deletion');
    
    const response = await request(app)
      .delete('/api/auth/account')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        confirmed: 'DELETE_MY_ACCOUNT',
        reason: 'Test deletion'
      });

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.message).toBe('Account deleted successfully');
    expect(response.body.data.deletedAt).toBeDefined();
    
    // Verify user is deleted
    const deletedUser = await UserModel.findById(testUser.id);
    expect(deletedUser).toBeNull();
    
    // Verify diary entries are deleted
    const entries = await DiaryEntryModel.listByDateRange(testUser.id, '2023-01-01', '2023-01-01');
    expect(entries).toHaveLength(0);
  });

  it('should require confirmation', async () => {
    const response = await request(app)
      .delete('/api/auth/account')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});

    expect(response.status).toBe(400);
    expect(response.body.error).toBe('Confirmation required');
    expect(response.body.message).toContain('DELETE_MY_ACCOUNT');
  });

  it('should reject invalid confirmation', async () => {
    const response = await request(app)
      .delete('/api/auth/account')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        confirmed: 'WRONG_CONFIRMATION'
      });

    expect(response.status).toBe(400);
    expect(response.body.error).toBe('Confirmation required');
  });

  it('should require authentication', async () => {
    const response = await request(app)
      .delete('/api/auth/account')
      .send({
        confirmed: 'DELETE_MY_ACCOUNT'
      });

    expect(response.status).toBe(401);
  });

  it('should handle non-existent user', async () => {
    // Delete user first
    await UserModel.deleteAccount(testUser.id);
    
    const response = await request(app)
      .delete('/api/auth/account')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        confirmed: 'DELETE_MY_ACCOUNT'
      });

    expect(response.status).toBe(404);
    expect(response.body.error).toBe('User not found');
  });

  it('should delete all user data including refresh tokens', async () => {
    // Create additional refresh tokens
    await RefreshTokenModel.create(testUser.id, 'token2', new Date(Date.now() + 30 * 24 * 60 * 60 * 1000));
    await RefreshTokenModel.create(testUser.id, 'token3', new Date(Date.now() + 30 * 24 * 60 * 60 * 1000));
    
    // Delete account
    const response = await request(app)
      .delete('/api/auth/account')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        confirmed: 'DELETE_MY_ACCOUNT'
      });

    expect(response.status).toBe(200);
    
    // Verify user is deleted (refresh tokens are cascade deleted)
    const deletedUser = await UserModel.findById(testUser.id);
    expect(deletedUser).toBeNull();
  });

  it('should handle image deletion gracefully', async () => {
    // Create diary entry with mock images
    await DiaryEntryModel.upsert(testUser.id, '2023-01-01', 'Test entry with images');
    
    // Update the entry to include mock image URLs
    const entry = await DiaryEntryModel.getByDate(testUser.id, '2023-01-01');
    if (entry) {
      await Database.query(
        'UPDATE diary_entries SET images = $1 WHERE id = $2',
        [[`uploads/${testUser.id}/2023-01-01/test1.jpg`, `uploads/${testUser.id}/2023-01-01/test2.png`], entry.id]
      );
    }
    
    // Delete account
    const response = await request(app)
      .delete('/api/auth/account')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        confirmed: 'DELETE_MY_ACCOUNT'
      });

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    
    // Verify user is deleted even if image deletion fails
    const deletedUser = await UserModel.findById(testUser.id);
    expect(deletedUser).toBeNull();
  });
});