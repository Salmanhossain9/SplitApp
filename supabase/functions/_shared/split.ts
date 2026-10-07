// TypeScript port of packages/split_core (Dart). Same integer algorithm, same tie-break
// (higher index wins a remainder tie), same golden fixtures: fixtures/split_golden.json.
// All amounts are integer poisha. Never floats.

export type SplitMode = "items" | "equally" | "custom";
export type ExtrasMode = "equally" | "by_items";

export class SplitError extends Error {
  constructor(public code: string, message: string) {
    super(message);
    this.name = "SplitError";
  }
}

/** Split `total` into n parts that add up exactly. The first parts get the extra poisha. */
export function splitEqually(total: number, n: number): number[] {
  if (!Number.isInteger(n) || n <= 0) throw new SplitError("NO_PARTICIPANTS", "n must be > 0");
  if (!Number.isSafeInteger(total) || total < 0) throw new SplitError("INVALID_AMOUNT", "bad total");
  const base = Math.floor(total / n);
  const remainder = total - base * n;
  return Array.from({ length: n }, (_, i) => base + (i < remainder ? 1 : 0));
}

/**
 * Largest remainder method, integer math (BigInt for total * weight).
 * Ties on the remainder go to the HIGHER index, matching the Dart port and the golden table.
 */
export function splitByWeight(total: number, weights: number[]): number[] {
  if (weights.length === 0) throw new SplitError("NO_PARTICIPANTS", "weights must not be empty");
  if (!Number.isSafeInteger(total) || total < 0 || weights.some((w) => !Number.isSafeInteger(w) || w < 0)) {
    throw new SplitError("INVALID_AMOUNT", "amounts must be non-negative integers");
  }
  const sum = weights.reduce((a, b) => a + b, 0);
  if (sum === 0) return splitEqually(total, weights.length);
  const bigSum = BigInt(sum);
  const floors: number[] = [];
  const rems: bigint[] = [];
  for (const w of weights) {
    const product = BigInt(total) * BigInt(w);
    floors.push(Number(product / bigSum));
    rems.push(product % bigSum);
  }
  let left = total - floors.reduce((a, b) => a + b, 0);
  const order = weights
    .map((_, i) => i)
    .sort((a, b) => {
      const ra = rems[a]!, rb = rems[b]!;
      if (ra !== rb) return rb > ra ? 1 : -1;
      return b - a;
    });
  for (const i of order) {
    if (left <= 0) break;
    floors[i] = floors[i]! + 1;
    left -= 1;
  }
  return floors;
}

/** Rate in basis points (5.9% = 590) of `base`, rounded half up. */
export function applyRateBp(base: number, rateBp: number): number {
  const product = BigInt(base) * BigInt(rateBp);
  return Number((product + 5000n) / 10000n);
}

const BANGLA = "০১২৩৪৫৬৭৮৯";

/** Parse typed taka into poisha with string math. "" -> 0, invalid -> null. */
export function parsePoisha(input: string): number | null {
  let s = input.trim().replace(/[,\s৳]/g, "");
  s = s.replace(/[০-৯]/g, (d) => String(BANGLA.indexOf(d)));
  if (s === "") return 0;
  if (!/^\d*\.?\d*$/.test(s) || s === ".") return null;
  const [whole = "", frac = ""] = s.split(".");
  const w = whole === "" ? 0 : Number(whole);
  const poisha = w * 100 + Number((frac + "00").slice(0, 2));
  return Number.isSafeInteger(poisha) ? poisha : null;
}

export interface SplitItem { id: string; qty: number; unitPrice: number }
export interface ChargeInput { rateBp?: number | null; amount?: number }
export interface Share { participantId: string; itemsAmount: number; extrasAmount: number; total: number }

export interface ComputeInput {
  participants: string[];
  items: SplitItem[];
  claims: Record<string, string[]>;
  vat?: ChargeInput;
  service?: ChargeInput;
  splitMode: SplitMode;
  extrasMode: ExtrasMode;
  customAmounts?: Record<string, number>;
  sharing?: string[];
}

export interface ComputeResult {
  subtotal: number;
  vat: number;
  service: number;
  extras: number;
  total: number;
  shares: Share[];
}

export const lineTotal = (i: SplitItem): number => i.qty * i.unitPrice;
export const itemsSubtotal = (items: SplitItem[]): number => items.reduce((a, i) => a + lineTotal(i), 0);

export function chargeAmount(subtotal: number, c?: ChargeInput): number {
  if (!c) return 0;
  return c.rateBp != null ? applyRateBp(subtotal, c.rateBp) : (c.amount ?? 0);
}

export function unclaimedItemIds(items: SplitItem[], claims: Record<string, string[]>): string[] {
  return items.filter((i) => (claims[i.id] ?? []).length === 0).map((i) => i.id);
}

export function itemSubtotals(
  participants: string[],
  items: SplitItem[],
  claims: Record<string, string[]>,
): Record<string, number> {
  const totals: Record<string, number> = Object.fromEntries(participants.map((p) => [p, 0]));
  for (const item of items) {
    const claimants = participants.filter((p) => (claims[item.id] ?? []).includes(p));
    if (claimants.length === 0) continue;
    const parts = splitEqually(lineTotal(item), claimants.length);
    claimants.forEach((p, i) => (totals[p] = totals[p]! + parts[i]!));
  }
  return totals;
}

export function computeShares(input: ComputeInput): ComputeResult {
  const { participants, items, claims, splitMode, extrasMode } = input;
  if (participants.length === 0) throw new SplitError("NO_PARTICIPANTS", "a bill needs participants");
  for (const ids of Object.values(claims)) {
    for (const id of ids) {
      if (!participants.includes(id)) throw new SplitError("UNKNOWN_PARTICIPANT", `unknown participant ${id}`);
    }
  }
  const subtotal = itemsSubtotal(items);
  const vat = chargeAmount(subtotal, input.vat);
  const service = chargeAmount(subtotal, input.service);
  const extras = vat + service;
  const total = subtotal + extras;
  const done = (shares: Share[]): ComputeResult => ({ subtotal, vat, service, extras, total, shares });

  if (splitMode === "equally") {
    const who = participants.filter((p) => (input.sharing ?? participants).includes(p));
    if (who.length === 0) throw new SplitError("NO_PARTICIPANTS", "nobody is sharing");
    const totals = splitEqually(total, who.length);
    const itemParts = splitEqually(subtotal, who.length);
    return done(participants.map((participantId) => {
      const idx = who.indexOf(participantId);
      if (idx === -1) return { participantId, itemsAmount: 0, extrasAmount: 0, total: 0 };
      const t = totals[idx]!;
      const itemsAmount = Math.min(itemParts[idx]!, t);
      return { participantId, itemsAmount, extrasAmount: t - itemsAmount, total: t };
    }));
  }

  if (splitMode === "custom") {
    const amounts = participants.map((p) => input.customAmounts?.[p] ?? 0);
    if (amounts.some((a) => !Number.isSafeInteger(a) || a < 0)) throw new SplitError("INVALID_AMOUNT", "bad custom amount");
    const assigned = amounts.reduce((a, b) => a + b, 0);
    if (assigned !== total) {
      throw new SplitError("CUSTOM_MISMATCH", `custom amounts (${assigned}) differ from total (${total})`);
    }
    const extraParts = splitByWeight(extras, amounts);
    return done(participants.map((participantId, i) => ({
      participantId,
      itemsAmount: amounts[i]! - extraParts[i]!,
      extrasAmount: extraParts[i]!,
      total: amounts[i]!,
    })));
  }

  const unclaimed = unclaimedItemIds(items, claims);
  if (unclaimed.length > 0) throw new SplitError("UNCLAIMED_ITEMS", `unclaimed: ${unclaimed.join(",")}`);
  const per = itemSubtotals(participants, items, claims);
  const itemAmounts = participants.map((p) => per[p]!);
  const extraParts = extrasMode === "equally"
    ? splitEqually(extras, participants.length)
    : splitByWeight(extras, itemAmounts);
  return done(participants.map((participantId, i) => ({
    participantId,
    itemsAmount: itemAmounts[i]!,
    extrasAmount: extraParts[i]!,
    total: itemAmounts[i]! + extraParts[i]!,
  })));
}

export function assertSharesSum(r: ComputeResult): void {
  const sum = r.shares.reduce((a, s) => a + s.total, 0);
  if (sum !== r.total) throw new SplitError("INVALID_AMOUNT", `shares (${sum}) do not add up to bill total (${r.total})`);
}
