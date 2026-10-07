import { assertEquals } from "@std/assert";
import { canRemind, hoursUntilNextReminder, reminderText, takaText, whatsappLink } from "./core.ts";

const now = new Date("2026-10-07T12:00:00Z");

Deno.test("one reminder per tab per 24 hours", () => {
  assertEquals(canRemind(null, now), true);
  assertEquals(canRemind("2026-10-06T11:59:00Z", now), true);
  assertEquals(canRemind("2026-10-06T12:01:00Z", now), false);
  assertEquals(canRemind("2026-10-07T11:00:00Z", now), false);
  assertEquals(hoursUntilNextReminder("2026-10-07T11:00:00Z", now), 23);
});

Deno.test("reminder text and money format match the app", () => {
  assertEquals(takaText(20000), "৳200");
  assertEquals(takaText(74067), "৳740.67");
  assertEquals(takaText(223600), "৳2,236");
  assertEquals(reminderText("Salman", "Chillox", 20000).body, "You still owe Salman ৳200 for Chillox.");
});

Deno.test("whatsapp links use the Bangladesh country code for local numbers", () => {
  assertEquals(whatsappLink("01711-111111", "hi")?.startsWith("https://wa.me/8801711111111?text="), true);
  assertEquals(whatsappLink("+8801911222333", "hi")?.startsWith("https://wa.me/8801911222333?text="), true);
  assertEquals(whatsappLink("12", "hi"), null);
});
