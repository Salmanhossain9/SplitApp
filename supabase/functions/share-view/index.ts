// GET ?token=... or POST { token } -> the read-only bill summary for the public share page.
// No auth: the unguessable token is the credential. Returns no emails or phone numbers.
import { corsHeaders, fail, json, readJson, serviceClient } from "../_shared/http.ts";

const TOKEN = /^[A-Za-z0-9_-]{16,64}$/;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  let token: string | null = null;
  if (req.method === "GET") token = new URL(req.url).searchParams.get("token");
  else if (req.method === "POST") token = (await readJson<{ token?: string }>(req))?.token ?? null;
  else return fail(405, "method_not_allowed", "use GET or POST");

  // Same answer for "malformed" and "unknown" so tokens cannot be probed.
  if (!token || !TOKEN.test(token)) return fail(404, "not_found", "this link does not exist");
  const { data, error } = await serviceClient().rpc("share_view", { p_token: token });
  if (error) {
    console.error(error);
    return fail(500, "db_error", "something went wrong");
  }
  if (!data) return fail(404, "not_found", "this link does not exist");
  return json(data, 200, { "Cache-Control": "public, max-age=15" });
});
