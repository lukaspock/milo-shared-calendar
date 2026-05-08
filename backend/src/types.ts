// Shared TypeScript types for the SharedCal backend

export interface User {
  id: string;
  email: string;
  name: string;
  color: string;
  created_at: Date;
}

export interface Calendar {
  id: string;
  name: string;
  owner_id: string;
  invite_code: string;
  created_at: Date;
}

export interface CalendarMember {
  user_id: string;
  calendar_id: string;
  role: "owner" | "member";
}

export interface CalendarEvent {
  id: string;
  calendar_id: string;
  created_by: string;
  title: string;
  description?: string;
  start_time: Date;
  end_time: Date;
  color: string;
  created_at: Date;
  updated_at: Date;
}

export interface JwtPayload {
  sub: string;      // user id
  email: string;
  name: string;
}

// HTTP context passed to route handlers
export interface RequestContext {
  req: Request;
  params: Record<string, string>;
  query: Record<string, string>;
  user?: JwtPayload;
}

export type Handler = (ctx: RequestContext) => Promise<Response>;
