// POST { bill_id } -> recomputes the shares on the server with the shared split maths, stores
// shares and settlements in ONE transaction (finalize_bill_apply), opens the bill and returns
// the share link. The client never writes shares.
import { fail, json, corsHeaders, readJson, requireUser, serviceClient } from "../_shared/http.ts";
import { buildFinalizePlan, FinalizeError, newShareToken } from "./core.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "method_not_allowed", "use POST");

  const auth = await requireUser(req);
  if (auth instanceof Response) return auth;
  const body = await readJson<{ bill_id?: string }>(req);
  if (!body?.bill_id) return fail(400, "bad_request", "bill_id is required");

  // Read as the user: RLS guarantees they can only load their own bill.
  const db = auth.client;
  const [bill, participants, items, charges] = await Promise.all([
    db.from("bills").select("id, created_by, status, split_mode, extras_mode").eq("id", body.bill_id).maybeSingle(),
    db.from("bill_participants").select("id, is_host, position, in_split, custom_amount").eq("bill_id", body.bill_id),
    db.from("items").select("id, qty, unit_price").eq("bill_id", body.bill_id),
    db.from("charges").select("type, rate_bp, amount").eq("bill_id", body.bill_id),
  ]);
  if (bill.error || !bill.data) return fail(404, "not_found", "bill not found");
  for (const r of [participants, items, charges]) {
    if (r.error) return fail(500, "db_error", r.error.message);
  }
  const itemIds = (items.data ?? []).map((i) => i.id);
  const claims = itemIds.length
    ? await db.from("claims").select("item_id, participant_id").in("item_id", itemIds)
    : { data: [], error: null };
  if (claims.error) return fail(500, "db_error", claims.error.message);

  try {
    const plan = buildFinalizePlan({
      userId: auth.id,
      bill: bill.data,
      participants: participants.data ?? [],
      items: items.data ?? [],
      claims: claims.data ?? [],
      charges: charges.data ?? [],
    });
    const token = newShareToken();
    // One transaction on the database side; it re-checks that the shares add up.
    const { error } = await serviceClient().rpc("finalize_bill_apply", {
      p_bill_id: body.bill_id,
      p_user_id: auth.id,
      p_split_mode: bill.data.split_mode,
      p_extras_mode: bill.data.extras_mode,
      p_charges: plan.charges,
      p_shares: plan.shares,
      p_token: token,
    });
    if (error) return fail(409, "finalize_failed", error.message);

    const base = (Deno.env.get("SHARE_BASE_URL") ?? "https://splitup.app").replace(/\/$/, "");
    return json({
      bill_id: body.bill_id,
      total: plan.total,
      subtotal: plan.subtotal,
      share_token: token,
      share_url: `${base}/s/${token}`,
      shares: plan.shares,
    });
  } catch (e) {
    if (e instanceof FinalizeError) return fail(e.status, e.code, e.message);
    console.error(e);
    return fail(500, "internal", "something went wrong");
  }
});
