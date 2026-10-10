// POST { confirm: "delete" } -> deletes the signed-in person's data and their login.
// Used by the app (Settings > delete account) and by the web page Google Play asks for.
// The person can only delete themselves: the id comes from the verified token, never the body.
import { fail, json, corsHeaders, readJson, requireUser, serviceClient } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "method_not_allowed", "use POST");

  const auth = await requireUser(req);
  if (auth instanceof Response) return auth;
  const body = await readJson<{ confirm?: string }>(req);
  if (body?.confirm !== "delete") return fail(400, "bad_request", 'send { "confirm": "delete" }');

  const admin = serviceClient();
  // Data first, then the login. Both steps can be repeated safely, so a failure half way is fixed
  // by trying again.
  const { error: dataError } = await admin.rpc("delete_account_data", { p_user_id: auth.id });
  if (dataError) return fail(500, "db_error", dataError.message);
  const { error: userError } = await admin.auth.admin.deleteUser(auth.id);
  if (userError && !/not found/i.test(userError.message)) return fail(500, "auth_error", userError.message);
  return json({ deleted: true });
});
