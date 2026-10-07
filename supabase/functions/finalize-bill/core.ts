// Pure part of finalize-bill: turn the stored rows into the arguments for
// finalize_bill_apply, using the shared split maths. No I/O so it is unit tested.
import {
  assertSharesSum,
  computeShares,
  type ChargeInput,
  type ExtrasMode,
  type SplitItem,
  type SplitMode,
} from "../_shared/split.ts";

export interface BillRow { id: string; created_by: string; status: string; split_mode: SplitMode; extras_mode: ExtrasMode }
export interface ParticipantRow {
  id: string; is_host: boolean; position: number; in_split: boolean; custom_amount: number | null;
}
export interface ItemRow { id: string; qty: number; unit_price: number }
export interface ClaimRow { item_id: string; participant_id: string }
export interface ChargeRow { type: "vat" | "service"; rate_bp: number | null; amount: number }

export interface FinalizePlan {
  total: number;
  subtotal: number;
  charges: { type: "vat" | "service"; rate_bp: number | null; amount: number }[];
  shares: { participant_id: string; items_amount: number; extras_amount: number; total: number }[];
}

export class FinalizeError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

export function buildFinalizePlan(input: {
  userId: string;
  bill: BillRow;
  participants: ParticipantRow[];
  items: ItemRow[];
  claims: ClaimRow[];
  charges: ChargeRow[];
}): FinalizePlan {
  const { userId, bill } = input;
  if (bill.created_by !== userId) throw new FinalizeError(403, "forbidden", "only the host can finalize a bill");
  if (bill.status !== "draft") throw new FinalizeError(409, "already_finalized", `bill is already ${bill.status}`);
  if (input.items.length === 0) throw new FinalizeError(422, "no_items", "add at least one item");
  if (input.participants.length < 2) throw new FinalizeError(422, "too_few_people", "a bill needs at least two people");

  const participants = [...input.participants].sort((a, b) => a.position - b.position);
  const ids = participants.map((p) => p.id);
  const items: SplitItem[] = input.items.map((i) => ({ id: i.id, qty: i.qty, unitPrice: Number(i.unit_price) }));

  const claims: Record<string, string[]> = {};
  for (const c of input.claims) (claims[c.item_id] ??= []).push(c.participant_id);

  const charge = (type: "vat" | "service"): ChargeInput | undefined => {
    const row = input.charges.find((c) => c.type === type);
    if (!row) return undefined;
    return row.rate_bp != null ? { rateBp: row.rate_bp } : { amount: Number(row.amount) };
  };
  const vat = charge("vat");
  const service = charge("service");

  const customAmounts: Record<string, number> = {};
  for (const p of participants) if (p.custom_amount != null) customAmounts[p.id] = Number(p.custom_amount);

  let result;
  try {
    result = computeShares({
      participants: ids,
      items,
      claims,
      vat,
      service,
      splitMode: bill.split_mode,
      extrasMode: bill.extras_mode,
      customAmounts,
      sharing: participants.filter((p) => p.in_split).map((p) => p.id),
    });
    assertSharesSum(result);
  } catch (e) {
    const code = (e as { code?: string }).code ?? "split_failed";
    throw new FinalizeError(422, code.toLowerCase(), (e as Error).message);
  }

  return {
    total: result.total,
    subtotal: result.subtotal,
    charges: [
      ...(vat ? [{ type: "vat" as const, rate_bp: vat.rateBp ?? null, amount: result.vat }] : []),
      ...(service ? [{ type: "service" as const, rate_bp: service.rateBp ?? null, amount: result.service }] : []),
    ],
    shares: result.shares.map((s) => ({
      participant_id: s.participantId,
      items_amount: s.itemsAmount,
      extras_amount: s.extrasAmount,
      total: s.total,
    })),
  };
}

/** 22 url-safe characters (128 bits). */
export function newShareToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}
