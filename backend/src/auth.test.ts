import { describe, test, expect } from "bun:test";
import { signToken, verifyToken } from "./middleware/auth.middleware";

describe("JWT auth", () => {
  const payload = { sub: "user-uuid-123", email: "test@example.com", name: "Test User" };

  test("signToken produces a non-empty string", async () => {
    const token = await signToken(payload);
    expect(typeof token).toBe("string");
    expect(token.length).toBeGreaterThan(20);
  });

  test("verifyToken round-trips the payload", async () => {
    const token = await signToken(payload);
    const decoded = await verifyToken(token);
    expect(decoded.sub).toBe(payload.sub);
    expect(decoded.email).toBe(payload.email);
    expect(decoded.name).toBe(payload.name);
  });

  test("verifyToken rejects a tampered token", async () => {
    const token = await signToken(payload);
    const [h, p, sig] = token.split(".");
    const tampered = `${h}.${p}.${sig}INVALID`;
    await expect(verifyToken(tampered)).rejects.toThrow();
  });

  test("verifyToken rejects a random string", async () => {
    await expect(verifyToken("not.a.jwt")).rejects.toThrow();
  });

  test("password hashing: hash differs from plaintext", async () => {
    const hash = await Bun.password.hash("secret123");
    expect(hash).not.toBe("secret123");
  });

  test("password hashing: verify returns true for correct password", async () => {
    const hash = await Bun.password.hash("mypassword");
    const ok = await Bun.password.verify("mypassword", hash);
    expect(ok).toBe(true);
  });

  test("password hashing: verify returns false for wrong password", async () => {
    const hash = await Bun.password.hash("mypassword");
    const ok = await Bun.password.verify("wrongpassword", hash);
    expect(ok).toBe(false);
  });
});
