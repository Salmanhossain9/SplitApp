// Runs the same golden fixtures as packages/split_core/test. Run with:
//   deno test --allow-read supabase/functions/_shared/split_test.ts
import { assertEquals, assertThrows } from "@std/assert";
import {
  assertSharesSum,
  computeShares,
  parsePoisha,
  splitByWeight,
  splitEqually,
  type ChargeInput,
  type ExtrasMode,
  type SplitItem,
  type SplitMode,
} from "./split.ts";

const fx = JSON.parse(
  Deno.readTextFileSync(new URL("../../../fixtures/split_golden.json", import.meta.url)),
);

Deno.test("splitEqually golden", () => {
  for (const c of fx.splitEqually) assertEquals(splitEqually(c.total, c.n), c.expected);
  assertThrows(() => splitEqually(100, 0));
});

Deno.test("splitByWeight golden", () => {
  for (const c of fx.splitByWeight) assertEquals(splitByWeight(c.total, c.weights), c.expected);
});

// Small seeded PRNG so the loops are reproducible.
function rng(seed: number) {
  let s = seed >>> 0;
  return () => ((s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 2 ** 32);
}

Deno.test("random: shares always sum to the total", () => {
  const r = rng(42);
  const int = (n: number) => Math.floor(r() * n);
  for (let run = 0; run < 2000; run++) {
    const n = 1 + int(12);
    const total = int(5_000_000);
    assertEquals(splitEqually(total, n).reduce((a, b) => a + b, 0), total);
    const weights = Array.from({ length: n }, () => (r() < 0.5 ? 0 : int(300_000)));
    assertEquals(splitByWeight(total, weights).reduce((a, b) => a + b, 0), total);
  }
  for (let run = 0; run < 500; run++) {
    const n = 1 + int(12);
    const people = Array.from({ length: n }, (_, i) => `p${i}`);
    const items: SplitItem[] = Array.from({ length: 1 + int(8) }, (_, i) => ({
      id: `i${i}`, qty: 1 + int(4), unitPrice: int(200_000),
    }));
    const claims: Record<string, string[]> = {};
    for (const it of items) {
      const who = people.filter(() => int(3) === 0);
      claims[it.id] = who.length ? who : [people[0]!];
    }
    const vat: ChargeInput = { rateBp: int(1500) };
    const service: ChargeInput = { rateBp: int(1500) };
    for (const em of ["equally", "by_items"] as ExtrasMode[]) {
      const res = computeShares({ participants: people, items, claims, vat, service, splitMode: "items", extrasMode: em });
      assertSharesSum(res);
    }
    const eq = computeShares({
      participants: people, items, claims, vat, service, splitMode: "equally", extrasMode: "equally",
      sharing: people.slice(0, 1 + int(n)),
    });
    assertSharesSum(eq);
    const custom = Object.fromEntries(
      splitByWeight(eq.total, Array.from({ length: n }, () => 1 + int(100))).map((v, i) => [people[i]!, v]),
    );
    assertSharesSum(computeShares({
      participants: people, items, claims, vat, service, splitMode: "custom", extrasMode: "equally", customAmounts: custom,
    }));
  }
});

Deno.test("Chillox golden", () => {
  const c = fx.chillox;
  const items: SplitItem[] = c.items.map((i: any) => ({ id: i.id, qty: i.qty, unitPrice: i.unitPrice }));
  const run = (splitMode: SplitMode, extrasMode: ExtrasMode = "equally") =>
    computeShares({
      participants: c.participants, items, claims: c.claims,
      vat: { rateBp: c.vat.rateBp }, service: { rateBp: c.service.rateBp }, splitMode, extrasMode,
    });
  const totals = (r: ReturnType<typeof run>) => Object.fromEntries(r.shares.map((s) => [s.participantId, s.total]));
  const e = c.expected;

  const r = run("items");
  assertEquals([r.subtotal, r.vat, r.service, r.total], [e.subtotal, e.vat, e.service, e.total]);
  assertEquals(Object.fromEntries(r.shares.map((s) => [s.participantId, s.itemsAmount])), e.items);
  assertEquals(totals(r), e.itemsEqualExtras);
  assertEquals(totals(run("items", "by_items")), e.itemsByWeightExtras);
  assertEquals(totals(run("equally")), e.equallySplit);
});

Deno.test("custom mode rejects a mismatch", () => {
  assertThrows(
    () => computeShares({
      participants: ["a", "b"], items: [{ id: "x", qty: 1, unitPrice: 1000 }], claims: {},
      splitMode: "custom", extrasMode: "equally", customAmounts: { a: 400, b: 500 },
    }),
  );
});

Deno.test("parsePoisha", () => {
  assertEquals(parsePoisha(""), 0);
  assertEquals(parsePoisha("412.5"), 41250);
  assertEquals(parsePoisha("1,200"), 120000);
  assertEquals(parsePoisha("১২৩.৫"), 12350);
  assertEquals(parsePoisha("৳ 90"), 9000);
  assertEquals(parsePoisha("."), null);
  assertEquals(parsePoisha("1.2.3"), null);
});
