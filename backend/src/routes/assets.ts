import { json, error } from "../router";
import type { RequestContext } from "../types";
import { isCloudinaryUrl, extractPublicId, deleteCloudinaryAsset } from "../services/cloudinary";

/**
 * DELETE /assets
 * Body: { url: string }
 *
 * Lets the frontend clean up Cloudinary assets it uploaded (e.g. calendar photo
 * icons stored locally in SharedPreferences rather than in the database).
 * Only deletes assets that belong to our own Cloudinary account.
 */
export async function deleteAsset(ctx: RequestContext): Promise<Response> {
  let body: { url?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { url } = body;
  if (!url || !isCloudinaryUrl(url)) {
    return error("url must be a valid Cloudinary URL for this account", 400);
  }

  const publicId = extractPublicId(url);
  if (!publicId) return error("Could not extract public_id from URL", 400);

  await deleteCloudinaryAsset(publicId);
  return json({ message: "Asset deleted" });
}
