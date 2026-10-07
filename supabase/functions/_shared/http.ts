import { createClient, type SupabaseClient } from "@supabase/supabase-js";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export function json(body: unknown, status = 200, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", ...extra },
  });
}

export const fail = (status: number, code: string, message: string): Response =>
  json({ error: { code, message } }, status);

/** Client acting as the signed-in user (RLS applies). */
export function userClient(req: Request): SupabaseClient {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    auth: { persistSession: false },
  });
}

/** Service role client. Server only, never returned to a caller. */
export function serviceClient(): SupabaseClient {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
}

export async function requireUser(req: Request): Promise<{ id: string; client: SupabaseClient } | Response> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return fail(401, "unauthorized", "missing token");
  const client = userClient(req);
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) return fail(401, "unauthorized", "invalid token");
  return { id: data.user.id, client };
}

export async function readJson<T>(req: Request): Promise<T | null> {
  try {
    return await req.json() as T;
  } catch {
    return null;
  }
}
