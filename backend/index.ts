import { Router } from "./src/router";
import { authMiddleware } from "./src/middleware/auth.middleware";
import { authRateLimit, rateLimit } from "./src/middleware/rate_limit.middleware";
import { register, login, deleteUser, verifyEmail, resendVerification, getMe, updateNotificationType, googleAuth, connectGoogleCalendar, googleCalendarCallback, forgotPassword, showResetPasswordForm, submitResetPassword } from "./src/routes/auth";
import { runMigrations } from "./src/db/migrate";
import { listCalendars, createCalendar, joinCalendar, getCalendarEvents, listMembers, removeMember, deleteCalendar, leaveCalendar } from "./src/routes/calendars";
import { createEvent, updateEvent, deleteEvent, notifyMembers } from "./src/routes/events";
import { createPoll, listPolls, getPoll, votePoll, confirmPoll, deletePoll } from "./src/routes/polls";
import { websocketHandler, startNotifyListener } from "./src/ws/websocket";
import { startReminderScheduler } from "./src/services/reminder.service";

const router = new Router();

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
router.post("/auth/google-calendar/connect", connectGoogleCalendar, [authMiddleware]);
router.get("/auth/google-calendar/callback", googleCalendarCallback);
router.delete("/users/me", deleteUser, [authMiddleware]);

// --- Calendars (protected) ---
router.get("/calendars", listCalendars, [authMiddleware]);
router.post("/calendars", createCalendar, [authMiddleware]);
router.post("/calendars/join", joinCalendar, [authMiddleware]);
router.delete("/calendars/:id", deleteCalendar, [authMiddleware]);
router.post("/calendars/:id/leave", leaveCalendar, [authMiddleware]);
router.get("/calendars/:id/events", getCalendarEvents, [authMiddleware]);
router.get("/calendars/:id/members", listMembers, [authMiddleware]);
router.delete("/calendars/:id/members/:userId", removeMember, [authMiddleware]);

// --- Events (protected) ---
router.post("/events", createEvent, [authMiddleware]);
router.put("/events/:id", updateEvent, [authMiddleware]);
router.delete("/events/:id", deleteEvent, [authMiddleware]);
router.post("/events/:id/notify", notifyMembers, [authMiddleware]);

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

console.log(`🚀 SharedCal backend running on http://localhost:${server.port}`);
console.log(`🔌 WebSocket available at ws://localhost:${server.port}/ws`);
