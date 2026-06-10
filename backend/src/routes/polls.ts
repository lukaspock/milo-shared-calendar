import db from "../db/client";
import { json, error } from "../router";
import type { RequestContext } from "../types";
import { broadcastToCalendar } from "../ws/websocket";
import { sendPollConfirmedNotification } from "../services/email";
import { syncEventCreated } from "../services/google_calendar";

async function assemblePoll(poll: Record<string, unknown>) {
  const options = await db`
    SELECT id, poll_id, start_time, end_time
    FROM poll_options
    WHERE poll_id = ${poll.id as string}
    ORDER BY start_time
  `;

  const votes =
    options.length > 0
      ? await db`
          SELECT pv.option_id, pv.user_id, pv.vote, u.name AS user_name
          FROM poll_votes pv
          JOIN users u ON u.id = pv.user_id
          JOIN poll_options po ON po.id = pv.option_id
          WHERE po.poll_id = ${poll.id as string}
        `
      : [];

  const voteOptions = await db`
    SELECT id, label, color, position
    FROM poll_vote_options
    WHERE poll_id = ${poll.id as string}
    ORDER BY position
  `;

  const creators = await db`SELECT name FROM users WHERE id = ${poll.created_by as string}`;

  return {
    ...poll,
    creator_name: creators[0]?.name ?? "Unknown",
    vote_options: voteOptions,
    options: options.map((opt: Record<string, unknown>) => ({
      ...opt,
      votes: votes
        .filter((v: Record<string, unknown>) => v.option_id === opt.id)
        .map((v: Record<string, unknown>) => ({
          user_id: v.user_id,
          user_name: v.user_name,
          vote: v.vote,
        })),
    })),
  };
}

export async function createPoll(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { calendarId } = ctx.params;

  let body: {
    title?: string;
    description?: string;
    options?: { start_time: string; end_time: string }[];
    vote_options?: { label: string; color: string }[];
    icon?: string | null;
    color?: string | null;
  };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { title, description, options, vote_options, icon, color } = body;
  if (!title) return error("title is required");
  if (!options || options.length === 0)
    return error("At least one option is required");

  const membership = await db`
    SELECT 1 FROM calendar_members
    WHERE user_id = ${userId} AND calendar_id = ${calendarId}
  `;
  if (membership.length === 0)
    return error("Not a member of this calendar", 403);

  const polls = await db`
    INSERT INTO event_polls (calendar_id, created_by, title, description, icon, color)
    VALUES (${calendarId}, ${userId}, ${title}, ${description ?? null}, ${icon ?? null}, ${color ?? null})
    RETURNING *
  `;
  const poll = polls[0];

  for (const opt of options) {
    await db`
      INSERT INTO poll_options (poll_id, start_time, end_time)
      VALUES (${poll.id}, ${opt.start_time}, ${opt.end_time})
    `;
  }

  if (vote_options && vote_options.length >= 2) {
    for (let i = 0; i < vote_options.length; i++) {
      const vo = vote_options[i];
      await db`
        INSERT INTO poll_vote_options (poll_id, label, color, position)
        VALUES (${poll.id}, ${vo.label}, ${vo.color ?? "#6C63FF"}, ${i})
      `;
    }
  }

  const full = await assemblePoll(poll);

  broadcastToCalendar(calendarId, {
    type: "poll_update",
    poll_id: poll.id,
    calendar_id: calendarId,
  });

  return json(full, 201);
}

export async function listPolls(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { calendarId } = ctx.params;

  const membership = await db`
    SELECT 1 FROM calendar_members
    WHERE user_id = ${userId} AND calendar_id = ${calendarId}
  `;
  if (membership.length === 0)
    return error("Not a member of this calendar", 403);

  const polls = await db`
    SELECT * FROM event_polls
    WHERE calendar_id = ${calendarId}
    ORDER BY closed, created_at DESC
  `;

  const full = await Promise.all(polls.map(assemblePoll));
  return json(full);
}

export async function getPoll(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  const polls = await db`SELECT * FROM event_polls WHERE id = ${id}`;
  if (polls.length === 0) return error("Poll not found", 404);
  const poll = polls[0];

  const membership = await db`
    SELECT 1 FROM calendar_members
    WHERE user_id = ${userId} AND calendar_id = ${poll.calendar_id}
  `;
  if (membership.length === 0)
    return error("Not a member of this calendar", 403);

  return json(await assemblePoll(poll));
}

export async function votePoll(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  let body: { option_id?: string; vote?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { option_id, vote } = body;
  if (!option_id || !vote) return error("option_id and vote are required");

  const polls = await db`SELECT * FROM event_polls WHERE id = ${id}`;
  if (polls.length === 0) return error("Poll not found", 404);
  const poll = polls[0];

  if (poll.closed) return error("Poll is closed", 400);

  // Validate vote value: against custom options if defined, else legacy yes/no/maybe
  const customOpts = await db`SELECT label FROM poll_vote_options WHERE poll_id = ${id}`;
  if (customOpts.length > 0) {
    const valid = customOpts.map((o: Record<string, unknown>) => o.label as string);
    if (!valid.includes(vote)) return error("Invalid vote option");
  } else {
    if (!["yes", "no", "maybe"].includes(vote))
      return error("vote must be yes, no, or maybe");
  }

  const membership = await db`
    SELECT 1 FROM calendar_members
    WHERE user_id = ${userId} AND calendar_id = ${poll.calendar_id}
  `;
  if (membership.length === 0)
    return error("Not a member of this calendar", 403);

  const opts = await db`
    SELECT 1 FROM poll_options WHERE id = ${option_id} AND poll_id = ${id}
  `;
  if (opts.length === 0) return error("Option not found in this poll", 404);

  await db`
    INSERT INTO poll_votes (option_id, user_id, vote)
    VALUES (${option_id}, ${userId}, ${vote})
    ON CONFLICT (option_id, user_id) DO UPDATE SET vote = ${vote}, voted_at = now()
  `;

  broadcastToCalendar(poll.calendar_id, {
    type: "poll_update",
    poll_id: id,
    calendar_id: poll.calendar_id,
  });

  return json(await assemblePoll(poll));
}

export async function confirmPoll(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  let body: { option_id?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { option_id } = body;
  if (!option_id) return error("option_id is required");

  const polls = await db`SELECT * FROM event_polls WHERE id = ${id}`;
  if (polls.length === 0) return error("Poll not found", 404);
  const poll = polls[0];

  if (poll.created_by !== userId)
    return error("Only the poll creator can confirm", 403);
  if (poll.closed) return error("Poll is already closed", 400);

  const options = await db`
    SELECT * FROM poll_options WHERE id = ${option_id} AND poll_id = ${id}
  `;
  if (options.length === 0) return error("Option not found in this poll", 404);
  const option = options[0];

  const users = await db`SELECT color FROM users WHERE id = ${userId}`;
  // Poll color overrides user color; fall back to user color then default
  const eventColor = (poll.color as string | null) ?? users[0]?.color ?? "#6C63FF";
  const eventIcon = poll.icon as string | null ?? null;

  const events = await db`
    INSERT INTO events (calendar_id, created_by, title, description, start_time, end_time, color, icon)
    VALUES (
      ${poll.calendar_id}, ${userId}, ${poll.title}, ${poll.description ?? null},
      ${option.start_time}, ${option.end_time}, ${eventColor}, ${eventIcon}
    )
    RETURNING *
  `;
  const event = events[0];

  const updated = await db`
    UPDATE event_polls
    SET closed = true, confirmed_option_id = ${option_id}
    WHERE id = ${id}
    RETURNING *
  `;

  const full = await assemblePoll(updated[0]);

  // Fetch event with creator info for the broadcast payload
  const eventWithCreator = await db`
    SELECT e.*, u.name AS creator_name, u.color AS creator_color
    FROM events e LEFT JOIN users u ON u.id = e.created_by
    WHERE e.id = ${event.id as string}
  `;

  broadcastToCalendar(poll.calendar_id, {
    type: "poll_update",
    poll_id: id,
    calendar_id: poll.calendar_id,
  });

  // Broadcast event_created directly — the NOTIFY/DB-trigger path also fires,
  // but can be delayed or dropped on free-tier Postgres; this ensures immediate delivery.
  broadcastToCalendar(poll.calendar_id, {
    type: "event_created",
    event: eventWithCreator[0],
  });

  // Fire-and-forget Google Calendar sync + email
  syncEventCreated({
    calendarId: poll.calendar_id as string,
    eventId: event.id as string,
    title: event.title as string,
    description: event.description as string | null,
    startTime: new Date(event.start_time as string),
    endTime: new Date(event.end_time as string),
  }).catch(console.error);

  (async () => {
    const members = await db`
      SELECT u.email FROM users u
      INNER JOIN calendar_members cm ON cm.user_id = u.id
      WHERE cm.calendar_id = ${poll.calendar_id}
        AND u.email_verified = true AND u.notification_type = 'email'
    `;
    const cal = await db`SELECT name FROM calendars WHERE id = ${poll.calendar_id}`;
    if (members.length > 0 && cal.length > 0) {
      await sendPollConfirmedNotification({
        memberEmails: members.map((m: Record<string, unknown>) => m.email as string),
        eventTitle: event.title as string,
        calendarName: cal[0].name as string,
        startTime: new Date(event.start_time as string),
      });
    }
  })().catch(console.error);

  return json({ poll: full, event });
}

export async function addPollOption(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  let body: { start_time?: string; end_time?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { start_time, end_time } = body;
  if (!start_time || !end_time) return error("start_time and end_time are required");

  const polls = await db`SELECT * FROM event_polls WHERE id = ${id}`;
  if (polls.length === 0) return error("Poll not found", 404);
  const poll = polls[0];

  if (poll.closed) return error("Poll is closed", 400);

  const membership = await db`
    SELECT 1 FROM calendar_members
    WHERE user_id = ${userId} AND calendar_id = ${poll.calendar_id}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  await db`
    INSERT INTO poll_options (poll_id, start_time, end_time)
    VALUES (${id}, ${start_time}, ${end_time})
  `;

  broadcastToCalendar(poll.calendar_id, {
    type: "poll_update",
    poll_id: id,
    calendar_id: poll.calendar_id,
  });

  return json(await assemblePoll(poll));
}

export async function deletePoll(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  const polls = await db`SELECT * FROM event_polls WHERE id = ${id}`;
  if (polls.length === 0) return error("Poll not found", 404);
  const poll = polls[0];

  const membership = await db`
    SELECT role FROM calendar_members
    WHERE user_id = ${userId} AND calendar_id = ${poll.calendar_id}
  `;
  if (membership.length === 0)
    return error("Not a member of this calendar", 403);

  const isCreator = poll.created_by === userId;
  const isOwner = membership[0].role === "owner";
  if (!isCreator && !isOwner)
    return error("Only the poll creator or calendar owner can delete", 403);

  await db`DELETE FROM event_polls WHERE id = ${id}`;

  broadcastToCalendar(poll.calendar_id, {
    type: "poll_update",
    poll_id: id,
    calendar_id: poll.calendar_id,
  });

  return json({ message: "Poll deleted" });
}
