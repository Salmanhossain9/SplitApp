// POST { path } -> reads a receipt photo from the private `receipts` bucket, asks a vision
// model to read it, returns { place?, items, vat?, service?, total? } in poisha.
// The API key stays here (supabase secrets set ANTHROPIC_API_KEY=...). Nothing is saved.
import { encodeBase64 } from "@std/encoding/base64";
import { corsHeaders, fail, json, readJson, requireUser, serviceClient } from "../_shared/http.ts";
import { isOwnReceiptPath, mediaTypeFor, parseScanOutput, SCAN_PROMPT } from "./core.ts";

const MAX_BYTES = 6 * 1024 * 1024;
const SCANS_PER_HOUR = 20;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "method_not_allowed", "use POST");

  const auth = await requireUser(req);
  if (auth instanceof Response) return auth;
  const body = await readJson<{ path?: string }>(req);
  const path = body?.path ?? "";
  if (!isOwnReceiptPath(auth.id, path)) return fail(403, "forbidden", "that is not your receipt");
  const mediaType = mediaTypeFor(path);
  if (!mediaType) return fail(415, "unsupported_type", "use a jpg, png or webp photo");

  const service = serviceClient();
  const { data: allowed, error: limitError } = await service.rpc("take_rate_limit", {
    p_user: auth.id, p_bucket: "scan-receipt", p_max: SCANS_PER_HOUR, p_window_seconds: 3600,
  });
  if (limitError) return fail(500, "db_error", limitError.message);
  if (!allowed) return fail(429, "rate_limited", "too many scans, try again in a bit");

  const file = await service.storage.from("receipts").download(path);
  if (file.error || !file.data) return fail(404, "not_found", "receipt not found");
  const bytes = new Uint8Array(await file.data.arrayBuffer());
  if (bytes.length === 0 || bytes.length > MAX_BYTES) return fail(413, "too_large", "photo must be under 6 MB");

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return fail(503, "not_configured", "receipt scanning is not set up yet");

  const model = Deno.env.get("SCAN_MODEL") ?? "claude-sonnet-5-5";
  let reply: Response;
  try {
    reply = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": apiKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model,
        max_tokens: 2048,
        messages: [{
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: mediaType, data: encodeBase64(bytes) } },
            { type: "text", text: SCAN_PROMPT },
          ],
        }],
      }),
    });
  } catch (e) {
    console.error("vision request failed", e);
    return fail(502, "upstream_unreachable", "could not reach the scanner, add items by hand");
  }
  if (!reply.ok) {
    console.error("vision error", reply.status, await reply.text());
    return fail(502, "upstream_error", "the scanner could not read this photo");
  }

  const data = await reply.json();
  const text: string = (data.content ?? []).filter((b: { type: string }) => b.type === "text")
    .map((b: { text: string }) => b.text).join("\n");
  try {
    return json(parseScanOutput(text));
  } catch (e) {
    console.error("could not parse model output", e, text.slice(0, 500));
    return fail(422, "unreadable", "could not read this receipt, add items by hand");
  }
});
