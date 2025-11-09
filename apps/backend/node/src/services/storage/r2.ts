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


