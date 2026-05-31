// AES-256-GCM encrypt/decrypt for sensitive values stored in the DB.
// Requires ENCRYPTION_KEY env var — exactly 32 ASCII characters.

function getKey(): Uint8Array {
  const raw = process.env.ENCRYPTION_KEY;
  if (!raw || raw.length !== 32) {
    throw new Error("ENCRYPTION_KEY must be set to exactly 32 characters.");
  }
  return new TextEncoder().encode(raw);
}

/**
 * Encrypts a plaintext string.
 * Returns a base64 string in the format: <iv_b64>:<ciphertext_b64>
 */
export async function encrypt(plaintext: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", getKey(), { name: "AES-GCM" }, false, ["encrypt"]
  );
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(plaintext);
  const cipherBuf = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, encoded);
  const ivB64 = btoa(String.fromCharCode(...iv));
  const ctB64 = btoa(String.fromCharCode(...new Uint8Array(cipherBuf)));
  return `${ivB64}:${ctB64}`;
}

/**
 * Decrypts a value produced by encrypt().
 */
export async function decrypt(ciphertext: string): Promise<string> {
  const [ivB64, ctB64] = ciphertext.split(":");
  if (!ivB64 || !ctB64) throw new Error("Invalid ciphertext format");
  const key = await crypto.subtle.importKey(
    "raw", getKey(), { name: "AES-GCM" }, false, ["decrypt"]
  );
  const iv = Uint8Array.from(atob(ivB64), c => c.charCodeAt(0));
  const ct = Uint8Array.from(atob(ctB64), c => c.charCodeAt(0));
  const plainBuf = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, ct);
  return new TextDecoder().decode(plainBuf);
}
