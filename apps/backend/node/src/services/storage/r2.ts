import { Client } from 'minio';
import { randomUUID } from 'crypto';

export interface R2PresignParams {
  userId: string;
  contentType: string;
  filename?: string;
}

export interface R2PresignResult {
  uploadUrl: string;
  objectKey: string;
  publicUrl: string;
  headers: Record<string, string>;
}

function env(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env ${name}`);
  return v;
}

function getClient(): Client {
  const accountId = env('R2_ACCOUNT_ID');
  const accessKey = env('R2_ACCESS_KEY_ID');
  const secretKey = env('R2_SECRET_ACCESS_KEY');
  const endPoint = `${accountId}.r2.cloudflarestorage.com`;
  // Port is omitted for HTTPS default
  return new Client({
    endPoint,
    useSSL: true,
    accessKey,
    secretKey,
  } as any);
}

function guessExt(contentType: string): string {
  const ct = contentType.toLowerCase();
  if (ct.includes('jpeg') || ct.includes('jpg')) return 'jpg';
  if (ct.includes('png')) return 'png';
  if (ct.includes('webp')) return 'webp';
  return 'jpg';
}

export async function r2PresignPutObject(params: R2PresignParams): Promise<R2PresignResult> {
  const bucket = env('R2_BUCKET');
  const publicBase = process.env.R2_PUBLIC_BASE_URL || '';
  const client = getClient();

  const ext = guessExt(params.contentType);
  const objectKey = [
    'uploads',
    params.userId,
    new Date().toISOString().slice(0, 10),
    `${randomUUID()}.${ext}`,
  ].join('/');

  // expiry in seconds (max varies; 10 minutes is typical)
  const expiry = 10 * 60;
  const uploadUrl = await new Promise<string>((resolve, reject) => {
    (client as any).presignedPutObject(
      bucket,
      objectKey,
      expiry,
      { 'Content-Type': params.contentType },
      (err: any, url: string) => {
        if (err) return reject(err);
        resolve(url);
      }
    );
  });

  const publicUrl = publicBase
    ? `${publicBase.replace(/\/+$/, '')}/${objectKey}`
    : objectKey; // caller should prepend domain if needed

  return {
    uploadUrl,
    objectKey,
    publicUrl,
    headers: {
      'Content-Type': params.contentType,
    },
  };
}

/**
 * Delete all images for a user from Cloudflare R2
 * @param userId User ID whose images should be deleted
 * @returns Number of images deleted
 */
export async function deleteAllUserImages(userId: string): Promise<number> {
  const bucket = env('R2_BUCKET');
  const client = getClient();
  
  try {
    // List all objects for this user under uploads/{userId}/
    const objectsStream = client.listObjects(bucket, `uploads/${userId}/`, true);
    const objects: string[] = [];
    
    // Collect all object keys
    for await (const obj of objectsStream) {
      if (obj.name) {
        objects.push(obj.name);
      }
    }
    
    // Delete all objects in batches (R2 supports up to 1000 objects per delete call)
    const batchSize = 1000;
    let deletedCount = 0;
    
    for (let i = 0; i < objects.length; i += batchSize) {
      const batch = objects.slice(i, i + batchSize);
      if (batch.length > 0) {
        await client.removeObjects(bucket, batch);
        deletedCount += batch.length;
        console.log(`🗑️ Deleted batch of ${batch.length} images for user ${userId}`);
      }
    }
    
    console.log(`✅ Successfully deleted ${deletedCount} images for user ${userId}`);
    return deletedCount;
  } catch (error) {
    console.error(`❌ Failed to delete images for user ${userId}:`, error);
    throw error;
  }
}

/**
 * Extract object key from image URL
 * @param imageUrl Full image URL or object key
 * @returns Object key for R2
 */
export function extractObjectKeyFromUrl(imageUrl: string): string {
  // If it's already an object key (starts with 'uploads/'), return as-is
  if (imageUrl.startsWith('uploads/')) {
    return imageUrl;
  }
  
  // Extract object key from full URL
  try {
    const url = new URL(imageUrl);
    const pathname = url.pathname;
    // Remove leading slash if present
    return pathname.startsWith('/') ? pathname.substring(1) : pathname;
  } catch {
    // Fallback: assume it's already an object key
    return imageUrl;
  }
}


