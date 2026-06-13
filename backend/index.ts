import { Router } from "./src/router";
import { authMiddleware } from "./src/middleware/auth.middleware";
import { authRateLimit, rateLimit } from "./src/middleware/rate_limit.middleware";
import { register, login, deleteUser, verifyEmail, resendVerification, getMe, updateNotificationType, updateProfile, googleAuth, connectGoogleCalendar, disconnectGoogleCalendar, googleCalendarCallback, forgotPassword, showResetPasswordForm, submitResetPassword } from "./src/routes/auth";
import { runMigrations } from "./src/db/migrate";
import { listCalendars, createCalendar, joinCalendar, getCalendarEvents, listMembers, removeMember, deleteCalendar, leaveCalendar, patchCalendar, syncDeviceEvents } from "./src/routes/calendars";
import { createEvent, updateEvent, deleteEvent, notifyMembers } from "./src/routes/events";
import { getReactions, addReaction, removeReaction } from "./src/routes/reactions";
import { addEventPhoto, listCalendarPhotos, deleteEventPhoto } from "./src/routes/photos";
import { createPoll, listPolls, getPoll, votePoll, confirmPoll, deletePoll, addPollOption } from "./src/routes/polls";
import { setRsvp, deleteRsvp, getRsvpDetail, getCalendarRsvps } from "./src/routes/rsvps";
import { getMessages, postMessage, deleteMessage } from "./src/routes/chat";
import { privacyPolicy, termsOfService } from "./src/routes/legal";
import { deleteAsset } from "./src/routes/assets";
import { websocketHandler, startNotifyListener } from "./src/ws/websocket";
import { startReminderScheduler } from "./src/services/reminder.service";
import { startGoogleCalendarSyncScheduler } from "./src/services/google_calendar";

const router = new Router();

// --- Health check (keeps Render free tier awake) ---
router.get("/healthz", async () => new Response("OK", { status: 200 }));

// --- Google Search Console verification ---
router.get("/googleab6029f8803fe017.html", async () => new Response("google-site-verification: googleab6029f8803fe017.html", { headers: { "Content-Type": "text/html" } }));

// --- Landing page + Legal (public) ---
router.get("/", async () => new Response(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Milo — Shared Calendar App</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  *{box-sizing:border-box}
  body{margin:0;background:#FFF8F0;font-family:'Helvetica Neue',Arial,sans-serif;color:#1F1B16;padding:0 24px 60px}
  .hero{max-width:680px;margin:0 auto;text-align:center;padding:60px 0 40px}
  .icon{font-size:72px;line-height:1;margin-bottom:20px}
  h1{font-size:36px;font-weight:800;margin:0 0 12px;letter-spacing:-.5px}
  .tagline{font-size:18px;color:#6B6357;margin:0 0 32px;line-height:1.5}
  .wrap{max-width:720px;margin:0 auto}
  .section{background:#fff;border:2px solid #EFE4D2;border-radius:20px;padding:36px;margin-bottom:20px;box-shadow:0 4px 0 #EFE4D2}
  h2{font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:.8px;color:#A39A8C;margin:0 0 16px}
  h3{font-size:17px;font-weight:700;color:#1F1B16;margin:0 0 6px}
  p{font-size:14px;color:#4A4035;line-height:1.75;margin:0 0 12px}
  p:last-child{margin:0}
  .features{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:4px}
  .feature{background:#FBF1E4;border-radius:12px;padding:16px 18px}
  .feature-icon{font-size:24px;margin-bottom:8px}
  ul{margin:0;padding-left:20px}
  li{font-size:14px;color:#4A4035;line-height:1.75;margin-bottom:4px}
  .highlight{background:#FBF1E4;border-radius:12px;padding:16px 18px;margin:12px 0}
  .highlight p{margin:0}
  strong{color:#1F1B16}
  a{color:#6C63FF}
  .footer{text-align:center;padding-top:32px;font-size:13px;color:#A39A8C}
  .footer a{color:#6C63FF;margin:0 10px;text-decoration:none}
  .policy-link{display:inline-block;background:#6C63FF;color:#fff;font-size:14px;font-weight:700;padding:12px 28px;border-radius:100px;text-decoration:none;margin-top:8px}
  @media(max-width:540px){.features{grid-template-columns:1fr}.section{padding:24px 20px}h1{font-size:28px}}
</style>
</head>
<body>
<div class="hero">
  <div class="icon">📅</div>
  <h1>Milo</h1>
  <p class="tagline">A shared calendar app that keeps you and your people in sync —<br>plan events together, react, vote on times, and share memories.</p>
  <a class="policy-link" href="/privacy">Privacy Policy</a>
</div>

<div class="wrap">

  <div class="section">
    <h2>What is Milo?</h2>
    <p>Milo is a mobile and desktop application (iOS, Android, macOS) that lets small groups — families, friend groups, flat-mates, teams — manage a shared calendar together. Members see each other's events in real time, react to them with emoji, vote on scheduling options, and attach photo memories to events they've shared.</p>
    <p>Milo connects to Google Calendar and Google Sign-In so users can optionally keep their existing Google Calendar in sync with their Milo shared calendar, and sign in without creating a separate password.</p>
  </div>

  <div class="section">
    <h2>Features</h2>
    <div class="features">
      <div class="feature">
        <div class="feature-icon">🗓️</div>
        <h3>Shared Calendars</h3>
        <p>Create a calendar, invite members via a code, and see all events in one place. Real-time updates via WebSocket.</p>
      </div>
      <div class="feature">
        <div class="feature-icon">✏️</div>
        <h3>Event Management</h3>
        <p>Create, edit, and delete events with titles, dates, colors, icons, and support for recurring events (daily, weekly, monthly).</p>
      </div>
      <div class="feature">
        <div class="feature-icon">🗳️</div>
        <h3>Scheduling Polls</h3>
        <p>Propose an event with multiple time options. Members vote yes / no / maybe, then the creator confirms the winning slot — which automatically creates the event.</p>
      </div>
      <div class="feature">
        <div class="feature-icon">📸</div>
        <h3>Photo Memories</h3>
        <p>Attach photos to events. All calendar members can view a shared photo gallery for each event.</p>
      </div>
      <div class="feature">
        <div class="feature-icon">😄</div>
        <h3>Emoji Reactions</h3>
        <p>React to any event with any emoji. Reactions update in real time for all members.</p>
      </div>
      <div class="feature">
        <div class="feature-icon">🔔</div>
        <h3>Email Notifications</h3>
        <p>Members receive email notifications when new events are created or a scheduling poll is confirmed — sent via the Gmail API.</p>
      </div>
    </div>
  </div>

  <div class="section">
    <h2>Google API Usage</h2>
    <p>Milo uses Google APIs for two distinct purposes. Both integrations are optional and require explicit user consent:</p>

    <div class="highlight">
      <h3>Gmail API — Transactional Email</h3>
      <p>Milo uses the <strong>Gmail API</strong> to send transactional emails on behalf of the Milo service account. This includes:</p>
      <ul>
        <li>Email address verification when a user registers</li>
        <li>Password reset links</li>
        <li>Event notifications to calendar members when a new event is created</li>
        <li>Confirmation emails when a scheduling poll is finalised</li>
        <li>Event reminders 30 minutes before an event starts</li>
      </ul>
      <p style="margin-top:10px">These emails are sent <em>from</em> the Milo service account to users — Milo does <strong>not</strong> read, modify, or access any user's personal Gmail inbox or email data.</p>
    </div>

    <div class="highlight">
      <h3>Google Calendar API — Bidirectional Sync</h3>
      <p>Users can optionally connect their personal Google Calendar to Milo via a standard OAuth 2.0 consent flow. Once connected:</p>
      <ul>
        <li><strong>Milo → Google:</strong> Events created, updated, or deleted in a Milo shared calendar are mirrored to the user's personal Google Calendar automatically.</li>
        <li><strong>Google → Milo:</strong> Events from the user's Google Calendar are imported into the shared Milo calendar as read-only entries, so other members can see when the user is busy.</li>
      </ul>
      <p style="margin-top:10px">The integration only accesses Google Calendar event data. It does not access contacts, email, files, or any other Google data. Tokens are stored encrypted (AES-256) in Milo's database and are used solely for calendar sync. Users can disconnect at any time from within the app, which immediately revokes and deletes the stored tokens.</p>
    </div>
  </div>

  <div class="section">
    <h2>Data &amp; Privacy</h2>
    <p>Milo stores only the data necessary to operate the service: your name, email address, profile photo (optional), and the events and calendars you create. We do not sell your data or use it for advertising.</p>
    <p>You can delete your account at any time from within the app, which permanently removes all your data including any stored Google OAuth tokens.</p>
    <p>For full details, please read our <a href="/privacy">Privacy Policy</a> and <a href="/terms">Terms of Service</a>.</p>
  </div>

  <div class="section">
    <h2>Contact</h2>
    <p>For questions, data requests, or support, contact us at <a href="mailto:lukaspock.dev@gmail.com">lukaspock.dev@gmail.com</a>.</p>
  </div>

</div>

<div class="footer">
  <a href="/privacy">Privacy Policy</a>
  <a href="/terms">Terms of Service</a>
  <a href="mailto:lukaspock.dev@gmail.com">Contact</a>
  <p style="margin-top:12px">© 2026 Milo. All rights reserved.</p>
</div>

</body></html>`, { headers: { "Content-Type": "text/html; charset=utf-8" } }));
router.get("/privacy", async () => privacyPolicy());
router.get("/terms", async () => termsOfService());

// --- Auth ---
// Rate-limited: 10 requests/min per IP on unauthenticated credential endpoints
router.post("/auth/register", register, [authRateLimit]);
router.post("/auth/login", login, [authRateLimit]);
router.post("/auth/google", googleAuth, [authRateLimit]);
router.get("/auth/verify/:token", verifyEmail);
router.post("/auth/forgot-password", forgotPassword, [authRateLimit]);
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
router.get("/calendars/:id/rsvps", getCalendarRsvps, [authMiddleware]);

// --- Events (protected) ---
router.post("/events", createEvent, [authMiddleware]);
router.put("/events/:id", updateEvent, [authMiddleware]);
router.delete("/events/:id", deleteEvent, [authMiddleware]);
router.post("/events/:id/notify", notifyMembers, [authMiddleware]);
router.get("/events/:id/reactions", getReactions, [authMiddleware]);
router.post("/events/:id/reactions", addReaction, [authMiddleware]);
router.delete("/events/:id/reactions/:emoji", removeReaction, [authMiddleware]);
router.post("/events/:id/rsvp", setRsvp, [authMiddleware]);
router.delete("/events/:id/rsvp", deleteRsvp, [authMiddleware]);
router.get("/events/:id/rsvps", getRsvpDetail, [authMiddleware]);

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
router.post("/polls/:id/options", addPollOption, [authMiddleware]);
router.delete("/polls/:id", deletePoll, [authMiddleware]);

// --- Chat (protected) ---
router.get("/calendars/:id/messages", getMessages, [authMiddleware]);
router.post("/calendars/:id/messages", postMessage, [authMiddleware]);
router.delete("/calendars/:id/messages/:msgId", deleteMessage, [authMiddleware]);

const PORT = Number(process.env.PORT ?? 3000);

// Run DB migrations (idempotent)
await runMigrations();

// Start the NOTIFY listener for real-time sync
await startNotifyListener();

// Start the event reminder scheduler (checks every 60 s, sends 30 min before events)
startReminderScheduler();

// Proactively re-import Google Calendar events every 5 min for all connected users
startGoogleCalendarSyncScheduler();

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
