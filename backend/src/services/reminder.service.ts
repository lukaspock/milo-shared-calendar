import db from "../db/client";
import { broadcastToCalendar } from "../ws/websocket";
import { sendReminderEmail, sendEventStartingEmail, sendEventEndedEmail } from "./email";

// In-memory set of event IDs we've already sent reminders for.
// Resets on server restart (acceptable — worst case is a duplicate reminder).
const remindedEventIds = new Set<string>();

/** Clears the in-memory dedup set. Only call from tests. */
export function _resetRemindedEvents(): void { remindedEventIds.clear(); }

type ReminderEmailFn = typeof sendReminderEmail;

export async function checkAndSendReminders(
  emailFn: ReminderEmailFn = sendReminderEmail
): Promise<void> {
  // Find events starting 25–35 minutes from now (10 min window for timer drift)
  const events = await db`
    SELECT
      e.id,
      e.title,
      e.start_time,
      e.calendar_id,
      c.name AS calendar_name
    FROM events e
    INNER JOIN calendars c ON c.id = e.calendar_id
    WHERE e.start_time BETWEEN now() + interval '25 minutes'
                            AND now() + interval '35 minutes'
  `;

  for (const event of events) {
    const eventId = event.id as string;
    if (remindedEventIds.has(eventId)) continue;
    remindedEventIds.add(eventId);

    const calendarId = event.calendar_id as string;

    // Broadcast WS reminder so on-device notification apps can display it immediately
    broadcastToCalendar(calendarId, {
      type: "event_reminder",
      event_id: eventId,
      event_title: event.title,
      calendar_id: calendarId,
      start_time: (event.start_time as Date).toISOString(),
    });

    // Send email to verified members who have email notifications enabled
    const members = await db`
      SELECT u.email FROM users u
      INNER JOIN calendar_members cm ON cm.user_id = u.id
      WHERE cm.calendar_id = ${calendarId}
        AND u.email_verified = true
        AND u.notification_type = 'email'
    `;

    if (members.length > 0) {
      emailFn({
        memberEmails: members.map((m: Record<string, unknown>) => m.email as string),
        eventTitle: event.title as string,
        calendarName: event.calendar_name as string,
        startTime: new Date(event.start_time as string),
      }).catch(console.error);
    }

    console.log(`[reminders] sent reminder for event ${eventId} "${event.title}"`);
  }
}

// Separate dedup sets for photo notifications
const sentPhotoStartingIds = new Set<string>();
const sentPhotoEndedIds = new Set<string>();

export async function checkAndSendPhotoNotifications(): Promise<void> {
  // Events starting NOW (±30s window) in photo-mode calendars
  const startingEvents = await db`
    SELECT e.id, e.title, e.calendar_id, c.name AS calendar_name
    FROM events e
    INNER JOIN calendars c ON c.id = e.calendar_id
    WHERE c.photo_mode = true
      AND e.start_time BETWEEN now() - interval '30 seconds'
                           AND now() + interval '30 seconds'
  `;

  for (const event of startingEvents) {
    const key = `starting:${event.id as string}`;
    if (sentPhotoStartingIds.has(key)) continue;
    sentPhotoStartingIds.add(key);

    const calendarId = event.calendar_id as string;

    broadcastToCalendar(calendarId, {
      type: "event_starting",
      event_id: event.id,
      event_title: event.title,
      calendar_id: calendarId,
    });

    const members = await db`
      SELECT u.email FROM users u
      INNER JOIN calendar_members cm ON cm.user_id = u.id
      WHERE cm.calendar_id = ${calendarId}
        AND u.email_verified = true
        AND u.notification_type = 'email'
    `;

    if (members.length > 0) {
      sendEventStartingEmail({
        memberEmails: members.map((m: Record<string, unknown>) => m.email as string),
        eventTitle: event.title as string,
        calendarName: event.calendar_name as string,
      }).catch(console.error);
    }

    console.log(`[photos] sent starting notification for event ${event.id as string} "${event.title as string}"`);
  }

  // Events ending NOW (±30s window) in photo-mode calendars
  const endedEvents = await db`
    SELECT e.id, e.title, e.calendar_id, c.name AS calendar_name
    FROM events e
    INNER JOIN calendars c ON c.id = e.calendar_id
    WHERE c.photo_mode = true
      AND e.end_time BETWEEN now() - interval '30 seconds'
                         AND now() + interval '30 seconds'
  `;

  for (const event of endedEvents) {
    const key = `ended:${event.id as string}`;
    if (sentPhotoEndedIds.has(key)) continue;
    sentPhotoEndedIds.add(key);

    const calendarId = event.calendar_id as string;

    broadcastToCalendar(calendarId, {
      type: "event_ended",
      event_id: event.id,
      event_title: event.title,
      calendar_id: calendarId,
    });

    const members = await db`
      SELECT u.email FROM users u
      INNER JOIN calendar_members cm ON cm.user_id = u.id
      WHERE cm.calendar_id = ${calendarId}
        AND u.email_verified = true
        AND u.notification_type = 'email'
    `;

    if (members.length > 0) {
      sendEventEndedEmail({
        memberEmails: members.map((m: Record<string, unknown>) => m.email as string),
        eventTitle: event.title as string,
        calendarName: event.calendar_name as string,
      }).catch(console.error);
    }

    console.log(`[photos] sent ended notification for event ${event.id as string} "${event.title as string}"`);
  }
}

/** Starts the reminder scheduler. Runs every 60 seconds. */
export function startReminderScheduler(): void {
  // Run once on startup in case we missed the window during a cold restart
  checkAndSendReminders().catch(console.error);
  checkAndSendPhotoNotifications().catch(console.error);
  setInterval(() => {
    checkAndSendReminders().catch(console.error);
    checkAndSendPhotoNotifications().catch(console.error);
  }, 60_000);
  console.log("[reminders] scheduler started — checking every 60 s");
}
