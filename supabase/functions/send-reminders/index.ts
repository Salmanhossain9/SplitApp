// POST { bill_id, participant_id } from the app (the `remind` pill), or a daily cron call with
// the x-cron-secret header for open tabs older than REMIND_AFTER_DAYS.
//   app user friend -> notifications row + FCM push
//   guest           -> returns a WhatsApp link for the app to open (guests have no push)
// Rate limit: one reminder per tab per 24 hours.
import { corsHeaders, fail, json, readJson, requireUser, serviceClient } from "../_shared/http.ts";
import { sendPush } from "../_shared/fcm.ts";
import { canRemind, hoursUntilNextReminder, reminderText, whatsappLink } from "./core.ts";

type Delivery = "push" | "notification_only" | "whatsapp" | "none";

async function remind(billId: string, participantId: string, hostId: string | null) {
  const db = serviceClient();
  const { data: bill } = await db.from("bills").select("id, place, created_by, share_token").eq("id", billId).maybeSingle();
  if (!bill || (hostId && bill.created_by !== hostId)) return { status: 404, error: "not_found" } as const;
  const { data: tab } = await db.from("settlements").select("owed_amount, last_reminded_at")
    .eq("bill_id", billId).eq("participant_id", participantId).maybeSingle();
  if (!tab || tab.owed_amount <= 0) return { status: 409, error: "no_open_tab" } as const;

  const now = new Date();
  if (!canRemind(tab.last_reminded_at, now)) {
    return { status: 429, error: "too_soon", retry_in_hours: hoursUntilNextReminder(tab.last_reminded_at, now) } as const;
  }
  const [{ data: person }, { data: host }] = await Promise.all([
    db.from("bill_participants").select("user_id, friend_id, name").eq("id", participantId).maybeSingle(),
    db.from("profiles").select("name").eq("id", bill.created_by).maybeSingle(),
  ]);
  if (!person) return { status: 404, error: "not_found" } as const;
  const text = reminderText(host?.name ?? "your friend", bill.place, Number(tab.owed_amount));

  let delivery: Delivery = "none";
  let whatsapp: string | null = null;
  if (person.user_id) {
    await db.from("notifications").insert({
      user_id: person.user_id,
      kind: "remind",
      payload: { bill_id: billId, place: bill.place, owed_amount: Number(tab.owed_amount), host_name: host?.name },
    });
    delivery = "notification_only";
    const { data: profile } = await db.from("profiles").select("push_token").eq("id", person.user_id).maybeSingle();
    if (profile?.push_token) {
      const r = await sendPush(profile.push_token, text.title, text.body, { kind: "remind", bill_id: billId });
      if (r === "sent") delivery = "push";
      if (r === "invalid_token") await db.from("profiles").update({ push_token: null }).eq("id", person.user_id);
    }
  } else if (person.friend_id) {
    const { data: friend } = await db.from("friends").select("phone").eq("id", person.friend_id).maybeSingle();
    if (friend?.phone) {
      const base = (Deno.env.get("SHARE_BASE_URL") ?? "https://splitbit.app").replace(/\/$/, "");
      const link = bill.share_token ? ` ${base}/s/${bill.share_token}` : "";
      whatsapp = whatsappLink(friend.phone, `${text.body}${link}`);
      if (whatsapp) delivery = "whatsapp";
    }
  }

  await db.from("settlements").update({ last_reminded_at: now.toISOString() })
    .eq("bill_id", billId).eq("participant_id", participantId);
  return { status: 200, delivery, whatsapp } as const;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "method_not_allowed", "use POST");

  const cronSecret = Deno.env.get("CRON_SECRET");
  if (cronSecret && req.headers.get("x-cron-secret") === cronSecret) {
    const days = Number(Deno.env.get("REMIND_AFTER_DAYS") ?? "3");
    const cutoff = new Date(Date.now() - days * 86400_000).toISOString();
    const { data: tabs, error } = await serviceClient().from("settlements")
      .select("bill_id, participant_id, bills!inner(created_at)")
      .gt("owed_amount", 0).lt("bills.created_at", cutoff).limit(200);
    if (error) return fail(500, "db_error", error.message);
    let sent = 0;
    for (const t of tabs ?? []) {
      const r = await remind(t.bill_id, t.participant_id, null);
      if (r.status === 200 && r.delivery !== "none") sent++;
    }
    return json({ checked: tabs?.length ?? 0, reminded: sent });
  }

  const auth = await requireUser(req);
  if (auth instanceof Response) return auth;
  const body = await readJson<{ bill_id?: string; participant_id?: string }>(req);
  if (!body?.bill_id || !body.participant_id) return fail(400, "bad_request", "bill_id and participant_id are required");
  const r = await remind(body.bill_id, body.participant_id, auth.id);
  if (r.status !== 200) return json(r, r.status);
  return json({ delivery: r.delivery, whatsapp: r.whatsapp });
});
