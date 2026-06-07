import { Router } from "./src/router";
import { authMiddleware } from "./src/middleware/auth.middleware";
import { authRateLimit, rateLimit } from "./src/middleware/rate_limit.middleware";
import { register, login, deleteUser, verifyEmail, resendVerification, getMe, updateNotificationType, updateProfile, googleAuth, connectGoogleCalendar, disconnectGoogleCalendar, googleCalendarCallback, forgotPassword, showResetPasswordForm, submitResetPassword } from "./src/routes/auth";
import { runMigrations } from "./src/db/migrate";
import { listCalendars, createCalendar, joinCalendar, getCalendarEvents, listMembers, removeMember, deleteCalendar, leaveCalendar, patchCalendar, syncDeviceEvents } from "./src/routes/calendars";
import { createEvent, updateEvent, deleteEvent, notifyMembers } from "./src/routes/events";
import { getReactions, addReaction, removeReaction } from "./src/routes/reactions";
import { addEventPhoto, listCalendarPhotos, deleteEventPhoto } from "./src/routes/photos";
import { createPoll, listPolls, getPoll, votePoll, confirmPoll, deletePoll } from "./src/routes/polls";
import { privacyPolicy, termsOfService } from "./src/routes/legal";
import { deleteAsset } from "./src/routes/assets";
import { websocketHandler, startNotifyListener } from "./src/ws/websocket";
import { startReminderScheduler } from "./src/services/reminder.service";

const router = new Router();

// --- Health check (keeps Render free tier awake) ---
router.get("/healthz", async () => new Response("OK", { status: 200 }));

// --- Google Search Console verification ---
router.get("/googleab6029f8803fe017.html", async () => new Response("google-site-verification: googleab6029f8803fe017.html", { headers: { "Content-Type": "text/html" } }));

// --- Landing page + Legal (public) ---
router.get("/", async () => new Response(`<!DOCTYPE html><html><head>
<meta charset="utf-8"><title>Milo - Shared Calendar</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>*{box-sizing:border-box}body{margin:0;background:#FFF8F0;font-family:'Helvetica Neue',Arial,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px;text-align:center}h1{font-size:32px;font-weight:800;color:#1F1B16;margin:0 0 8px}p{color:#6B6357;font-size:16px;margin:0 0 24px}a{color:#6C63FF;text-decoration:none;font-size:14px;margin:0 8px}</style>
</head><body>
<div>
  <div style="font-size:64px;margin-bottom:16px">📅</div>
  <h1>Milo - Shared Calendar</h1>
  <p>A shared calendar app for you and your people.</p>
  <a href="/privacy">Privacy Policy</a>
  <a href="/terms">Terms of Service</a>
</div>
</body></html>`, { headers: { "Content-Type": "text/html" } }));
router.get("/privacy", async () => privacyPolicy());
router.get("/terms", async () => termsOfService());

// --- Auth ---
// Rate-limited: 10 requests/min per IP on unauthenticated credential endpoints
router.post("/auth/register", register, [authRateLimit]);
router.post("/auth/login", login, [authRateLimit]);
router.post("/auth/google", googleAuth, [authRateLimit]);
router.get("/auth/verify/:token", verifyEmail);
router.post("/auth/forgot-password", forgotPassword);
router.get("/auth/reset-password/:token", showResetPasswordForm);
router.post("/auth/reset-password/:token", submitResetPassword);
router.post("/auth/resend-verification", resendVerification, [authMiddleware, rateLimit(3, 60 * 60_000, "resend-verification")]);
router.get("/auth/me", getMe, [authMiddleware]);
router.put("/auth/notification-type", updateNotificationType, [authMiddleware]);
router.patch("/auth/me", updateProfile, [authMiddleware]);
router.post("/auth/google-calendar/connect", connectGoogleCalendar, [authMiddleware]);
router.delete("/auth/google-calendar/disconnect", disconnectGoogleCalendar, [authMiddleware]);
router.get("/auth/google-calendar/callback", googleCalendarCallback);
router.delete("/users/me", deleteUser, [authMiddleware]);
router.post("/assets/delete", deleteAsset, [authMiddleware]);

// --- Calendars (protected) ---
router.get("/calendars", listCalendars, [authMiddleware]);
router.post("/calendars", createCalendar, [authMiddleware]);
router.post("/calendars/join", joinCalendar, [authMiddleware]);
router.patch("/calendars/:id", patchCalendar, [authMiddleware]);
router.delete("/calendars/:id", deleteCalendar, [authMiddleware]);
router.post("/calendars/:id/leave", leaveCalendar, [authMiddleware]);
router.get("/calendars/:id/events", getCalendarEvents, [authMiddleware]);
router.post("/calendars/:id/device-events", syncDeviceEvents, [authMiddleware]);
router.get("/calendars/:id/members", listMembers, [authMiddleware]);
router.delete("/calendars/:id/members/:userId", removeMember, [authMiddleware]);

// --- Events (protected) ---
router.post("/events", createEvent, [authMiddleware]);
router.put("/events/:id", updateEvent, [authMiddleware]);
router.delete("/events/:id", deleteEvent, [authMiddleware]);
router.post("/events/:id/notify", notifyMembers, [authMiddleware]);
router.get("/events/:id/reactions", getReactions, [authMiddleware]);
router.post("/events/:id/reactions", addReaction, [authMiddleware]);
router.delete("/events/:id/reactions/:emoji", removeReaction, [authMiddleware]);

// --- Photo memories (protected) ---
router.post("/events/:eventId/photos", addEventPhoto, [authMiddleware]);
router.get("/calendars/:calendarId/photos", listCalendarPhotos, [authMiddleware]);
router.delete("/events/:eventId/photos/:photoId", deleteEventPhoto, [authMiddleware]);

// --- Polls (protected) ---
router.post("/calendars/:calendarId/polls", createPoll, [authMiddleware]);
router.get("/calendars/:calendarId/polls", listPolls, [authMiddleware]);
router.get("/polls/:id", getPoll, [authMiddleware]);
router.post("/polls/:id/vote", votePoll, [authMiddleware]);
router.post("/polls/:id/confirm", confirmPoll, [authMiddleware]);
router.delete("/polls/:id", deletePoll, [authMiddleware]);

const PORT = Number(process.env.PORT ?? 3000);

// Run DB migrations (idempotent)
await runMigrations();

// Start the NOTIFY listener for real-time sync
await startNotifyListener();

// Start the event reminder scheduler (checks every 60 s, sends 30 min before events)
startReminderScheduler();

const server = Bun.serve({
  port: PORT,

  async fetch(req, server) {
    const url = new URL(req.url);

    // WebSocket upgrade
    if (url.pathname === "/ws") {
      const upgraded = server.upgrade(req, { data: { calendarIds: [] as string[] } });
      if (upgraded) return undefined;
      return new Response("WebSocket upgrade failed", { status: 500 });
    }

    return router.handle(req);
  },

  websocket: websocketHandler,
});

console.log(`🚀 Milo backend running on http://localhost:${server.port}`);
console.log(`🔌 WebSocket available at ws://localhost:${server.port}/ws`);
