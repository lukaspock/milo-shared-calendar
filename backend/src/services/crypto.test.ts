import { describe, test, expect } from "bun:test";
import { encrypt, decrypt } from "./crypto";

describe("encrypt / decrypt", () => {
  test("round-trips plaintext correctly", async () => {
    const original = "super-secret-refresh-token";
    const cipher = await encrypt(original);
    const plain = await decrypt(cipher);
    expect(plain).toBe(original);
  });

  test("produces different ciphertext each call (random IV)", async () => {
    const cipher1 = await encrypt("same-value");
    const cipher2 = await encrypt("same-value");
    expect(cipher1).not.toBe(cipher2);
  });

  test("ciphertext is not the plaintext", async () => {
    const cipher = await encrypt("my-token");
    expect(cipher).not.toBe("my-token");
    expect(cipher).toContain(":");
  });

  test("throws on invalid ciphertext format", async () => {
    await expect(decrypt("notvalid")).rejects.toThrow();
  });
});
