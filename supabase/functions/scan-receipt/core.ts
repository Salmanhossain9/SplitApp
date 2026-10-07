// Pure part of scan-receipt: the prompt, and turning the model's JSON into poisha.
// The result is never saved directly: the app shows it for editing first.
import { z } from "zod";
import { parsePoisha } from "../_shared/split.ts";

export const SCAN_PROMPT = `You read photos of restaurant receipts from Bangladesh and return JSON only.

Rules:
- Amounts are in Bangladeshi taka (৳ or Tk). Numerals may be Bangla (০১২৩৪৫৬৭৮৯): convert them to ASCII digits.
- Return plain numbers or numeric strings in taka, without currency signs or thousands separators. Keep decimals if the receipt shows them.
- "items": every ordered line. "qty" is the quantity ordered (integer, default 1). "line_total" is the amount charged for that whole line (qty times unit price), exactly as printed.
- "vat": the VAT / value added tax amount in taka if there is a line for it, otherwise null.
- "service": the service charge amount in taka if there is a line for it, otherwise null.
- "total": the final payable total printed on the receipt, otherwise null.
- "place": the restaurant name if it is clear, otherwise null.
- Do NOT include VAT, service charge, subtotal, total, discount, rounding or payment lines as items.
- If a value is unreadable, use null instead of guessing.

Return exactly this shape and nothing else:
{"place": string|null, "items": [{"name": string, "qty": number, "line_total": number|string}], "vat": number|string|null, "service": number|string|null, "total": number|string|null}`;

const money = z.union([z.number(), z.string()]).nullable().optional();

export const ModelOutput = z.object({
  place: z.string().nullable().optional(),
  items: z.array(z.object({
    name: z.string(),
    qty: z.number().nullable().optional(),
    line_total: z.union([z.number(), z.string()]),
  })).max(150),
  vat: money,
  service: money,
  total: money,
});

export interface ScanResult {
  place?: string;
  items: { name: string; qty: number; unit_price: number }[];
  vat?: number;
  service?: number;
  total?: number;
}

function toPoisha(v: number | string | null | undefined): number | undefined {
  if (v == null) return undefined;
  const text = typeof v === "number" ? (Number.isFinite(v) ? String(v) : "") : v;
  const p = parsePoisha(text);
  return p == null || p < 0 ? undefined : p;
}

/** Pull the JSON object out of whatever text the model returned (it may wrap it in fences). */
export function extractJson(text: string): unknown {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end <= start) throw new Error("no JSON object in model output");
  return JSON.parse(text.slice(start, end + 1));
}

export function parseScanOutput(text: string): ScanResult {
  const parsed = ModelOutput.parse(extractJson(text));
  const items: ScanResult["items"] = [];
  for (const raw of parsed.items) {
    const name = raw.name.trim().slice(0, 80);
    const line = toPoisha(raw.line_total);
    if (!name || line === undefined) continue;
    const qty = Math.max(1, Math.round(raw.qty ?? 1));
    // Unit price only when it divides evenly; otherwise keep the exact line total as one unit
    // so the subtotal still matches the receipt.
    if (qty > 1 && line % qty === 0) {
      items.push({ name, qty, unit_price: line / qty });
    } else if (qty > 1) {
      items.push({ name: `${name} x${qty}`.slice(0, 80), qty: 1, unit_price: line });
    } else {
      items.push({ name, qty: 1, unit_price: line });
    }
  }
  const out: ScanResult = { items };
  const place = parsed.place?.trim();
  if (place) out.place = place.slice(0, 80);
  const vat = toPoisha(parsed.vat);
  const service = toPoisha(parsed.service);
  const total = toPoisha(parsed.total);
  if (vat !== undefined) out.vat = vat;
  if (service !== undefined) out.service = service;
  if (total !== undefined) out.total = total;
  return out;
}

export function mediaTypeFor(path: string): "image/jpeg" | "image/png" | "image/webp" | null {
  const ext = path.toLowerCase().split(".").pop();
  if (ext === "jpg" || ext === "jpeg") return "image/jpeg";
  if (ext === "png") return "image/png";
  if (ext === "webp") return "image/webp";
  return null;
}

/** A user may only scan files in their own folder: {user_id}/{bill_id}/... */
export function isOwnReceiptPath(userId: string, path: string): boolean {
  return path.startsWith(`${userId}/`) && !path.includes("..") && !path.includes("//") && path.length < 300;
}
