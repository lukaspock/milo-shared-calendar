import { createHash } from 'node:crypto';

const CLOUD_NAME = process.env.CLOUDINARY_CLOUD_NAME ?? 'dvlvgosxk';
const API_KEY    = process.env.CLOUDINARY_API_KEY ?? '';
const API_SECRET = process.env.CLOUDINARY_API_SECRET ?? '';

/** Returns true when the URL is a Cloudinary CDN URL for our account. */
export function isCloudinaryUrl(url: string | null | undefined): url is string {
  return typeof url === 'string' && url.includes(`res.cloudinary.com/${CLOUD_NAME}`);
}

/**
 * Extracts the Cloudinary public_id from a URL.
 *
 * e.g. https://res.cloudinary.com/dvlvgosxk/image/upload/v1234/avatars/abc.jpg
 *   → avatars/abc
 *
 * Handles optional version segment and optional transformation prefix.
 */
export function extractPublicId(url: string): string | null {
  try {
    // Strip query string
    const clean = url.split('?')[0];
    // Match everything after /upload/ (skip optional transformation + version segments)
    const match = clean.match(/\/upload\/(?:[^/]+\/)*v\d+\/(.+?)(?:\.[^./]+)?$/) ??
                  clean.match(/\/upload\/(.+?)(?:\.[^./]+)?$/);
    return match?.[1] ?? null;
  } catch {
    return null;
  }
}

/**
 * Deletes a single Cloudinary asset by public_id.
 * No-ops silently when API credentials are not configured.
 */
export async function deleteCloudinaryAsset(publicId: string): Promise<void> {
  if (!API_KEY || !API_SECRET) return;

  const timestamp = Math.floor(Date.now() / 1000).toString();
  const signature = createHash('sha1')
    .update(`public_id=${publicId}&timestamp=${timestamp}${API_SECRET}`)
    .digest('hex');

  await fetch(
    `https://api.cloudinary.com/v1_1/${CLOUD_NAME}/image/destroy`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ public_id: publicId, api_key: API_KEY, timestamp, signature }),
    },
  );
}

/**
 * Fire-and-forget: deletes all Cloudinary assets whose URLs are in the list.
 * Ignores null/undefined values and non-Cloudinary URLs silently.
 */
export function cleanupAssets(urls: (string | null | undefined)[]): void {
  for (const url of urls) {
    if (!isCloudinaryUrl(url)) continue;
    const id = extractPublicId(url);
    if (id) deleteCloudinaryAsset(id).catch(console.error);
  }
}
