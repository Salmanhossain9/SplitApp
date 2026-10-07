import { assertEquals, assertThrows } from "@std/assert";
import { isOwnReceiptPath, mediaTypeFor, parseScanOutput } from "./core.ts";

Deno.test("parses a clean model answer into poisha", () => {
  const r = parseScanOutput(JSON.stringify({
    place: "Chillox",
    items: [
      { name: "Chicken burger", qty: 1, line_total: 345 },
      { name: "Beef kala bhuna", qty: 1, line_total: "1,145" },
      { name: "Fries", qty: 1, line_total: 240 },
      { name: "Coke", qty: 3, line_total: 270 },
    ],
    vat: 118, service: "118", total: 2236,
  }));
  assertEquals(r.place, "Chillox");
  assertEquals(r.items.map((i) => [i.name, i.qty, i.unit_price]), [
    ["Chicken burger", 1, 34500], ["Beef kala bhuna", 1, 114500], ["Fries", 1, 24000], ["Coke", 3, 9000],
  ]);
  assertEquals([r.vat, r.service, r.total], [11800, 11800, 223600]);
  assertEquals(r.items.reduce((a, i) => a + i.qty * i.unit_price, 0), 200000);
});

Deno.test("Bangla numerals and fenced JSON", () => {
  const r = parseScanOutput('```json\n{"place":null,"items":[{"name":"চা","qty":2,"line_total":"১০০.৫০"}],"vat":null,"service":null,"total":"১০০.৫০"}\n```');
  assertEquals(r.place, undefined);
  // 100.50 does not divide by 2 evenly in poisha? 10050 / 2 = 5025, it does.
  assertEquals(r.items, [{ name: "চা", qty: 2, unit_price: 5025 }]);
  assertEquals(r.total, 10050);
  assertEquals(r.vat, undefined);
});

Deno.test("an uneven line total keeps the exact amount as one unit", () => {
  const r = parseScanOutput('{"items":[{"name":"Mix platter","qty":3,"line_total":100.01}]}');
  assertEquals(r.items, [{ name: "Mix platter x3", qty: 1, unit_price: 10001 }]);
});

Deno.test("drops unreadable lines and junk, never throws on a bad amount", () => {
  const r = parseScanOutput('{"items":[{"name":"","qty":1,"line_total":5},{"name":"Tea","qty":1,"line_total":"abc"},{"name":"Water","line_total":20}],"total":"n/a"}');
  assertEquals(r.items, [{ name: "Water", qty: 1, unit_price: 2000 }]);
  assertEquals(r.total, undefined);
});

Deno.test("rejects output without JSON or with the wrong shape", () => {
  assertThrows(() => parseScanOutput("sorry, I cannot read this"));
  assertThrows(() => parseScanOutput('{"items":"nope"}'));
});

Deno.test("receipt paths stay inside the user's folder", () => {
  assertEquals(isOwnReceiptPath("u1", "u1/b1/r.jpg"), true);
  assertEquals(isOwnReceiptPath("u1", "u2/b1/r.jpg"), false);
  assertEquals(isOwnReceiptPath("u1", "u1/../u2/r.jpg"), false);
  assertEquals(isOwnReceiptPath("u1", "u1//r.jpg"), false);
  assertEquals(mediaTypeFor("a/b.JPG"), "image/jpeg");
  assertEquals(mediaTypeFor("a/b.gif"), null);
});
