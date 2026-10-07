import { assertEquals, assertThrows } from "@std/assert";
import { type BillRow, buildFinalizePlan, type ParticipantRow, FinalizeError, newShareToken } from "./core.ts";

const fx = JSON.parse(Deno.readTextFileSync(new URL("../../../fixtures/split_golden.json", import.meta.url)));

// Chillox as database rows: participant ids are the fixture names for readability.
function chilloxRows(overrides: Record<string, unknown> = {}) {
  const c = fx.chillox;
  const claims = Object.entries(c.claims as Record<string, string[]>).flatMap(([item, who]) =>
    who.map((p) => ({ item_id: item, participant_id: p }))
  );
  return {
    userId: "host",
    bill: { id: "b", created_by: "host", status: "draft", split_mode: "items", extras_mode: "equally", ...overrides } as BillRow,
    participants: (c.participants as string[]).map((id, position): ParticipantRow => ({
      id, is_host: position === 0, position, in_split: true, custom_amount: null,
    })),
    items: c.items.map((i: any) => ({ id: i.id, qty: i.qty, unit_price: i.unitPrice })),
    claims,
    charges: [
      { type: "vat" as const, rate_bp: 590, amount: 0 },
      { type: "service" as const, rate_bp: 590, amount: 0 },
    ],
  };
}

Deno.test("plan reproduces the Chillox golden table (extras equally)", () => {
  const plan = buildFinalizePlan(chilloxRows());
  assertEquals(plan.total, fx.chillox.expected.total);
  assertEquals(Object.fromEntries(plan.shares.map((s) => [s.participant_id, s.total])), fx.chillox.expected.itemsEqualExtras);
  assertEquals(plan.charges, [
    { type: "vat", rate_bp: 590, amount: 11800 },
    { type: "service", rate_bp: 590, amount: 11800 },
  ]);
});

Deno.test("plan reproduces the golden table (extras by what they ate)", () => {
  const plan = buildFinalizePlan(chilloxRows({ extras_mode: "by_items" }));
  assertEquals(Object.fromEntries(plan.shares.map((s) => [s.participant_id, s.total])), fx.chillox.expected.itemsByWeightExtras);
});

Deno.test("shares always add up to the total", () => {
  for (const extras of ["equally", "by_items"]) {
    const plan = buildFinalizePlan(chilloxRows({ extras_mode: extras }));
    assertEquals(plan.shares.reduce((a, s) => a + s.total, 0), plan.total);
  }
});

Deno.test("equally mode honours who is sharing", () => {
  const rows = chilloxRows({ split_mode: "equally" });
  rows.participants[3]!.in_split = false; // Tania is out
  const plan = buildFinalizePlan(rows);
  const byId = Object.fromEntries(plan.shares.map((s) => [s.participant_id, s.total]));
  assertEquals(byId["tania"], 0);
  assertEquals(plan.shares.reduce((a, s) => a + s.total, 0), plan.total);
});

Deno.test("custom mode uses the typed amounts and rejects a mismatch", () => {
  const rows = chilloxRows({ split_mode: "custom" });
  const amounts = [60000, 70000, 50000, 43600];
  rows.participants.forEach((p, i) => (p.custom_amount = amounts[i]!));
  assertEquals(buildFinalizePlan(rows).shares.map((s) => s.total), amounts);
  rows.participants[0]!.custom_amount = 60001;
  assertThrows(() => buildFinalizePlan(rows), FinalizeError, "differ from total");
});

Deno.test("guards: not the host, already finalized, unclaimed items, no items", () => {
  assertThrows(() => buildFinalizePlan({ ...chilloxRows(), userId: "stranger" }), FinalizeError, "only the host");
  assertThrows(() => buildFinalizePlan(chilloxRows({ status: "open" })), FinalizeError, "already open");
  const rows = chilloxRows();
  rows.claims = rows.claims.filter((c) => c.item_id !== "fries");
  assertThrows(() => buildFinalizePlan(rows), FinalizeError, "unclaimed");
  assertThrows(() => buildFinalizePlan({ ...chilloxRows(), items: [], claims: [] }), FinalizeError, "at least one item");
});

Deno.test("share token is 22 url-safe characters and unique", () => {
  const seen = new Set<string>();
  for (let i = 0; i < 200; i++) {
    const t = newShareToken();
    assertEquals(t.length, 22);
    assertEquals(/^[A-Za-z0-9_-]{22}$/.test(t), true);
    seen.add(t);
  }
  assertEquals(seen.size, 200);
});
