// Pure part of send-reminders.
export const REMIND_COOLDOWN_HOURS = 24;

/** One reminder per tab per 24 h. */
export function canRemind(lastRemindedAt: string | null, now: Date, cooldownHours = REMIND_COOLDOWN_HOURS): boolean {
  if (!lastRemindedAt) return true;
  const last = new Date(lastRemindedAt).getTime();
  return Number.isNaN(last) || now.getTime() - last >= cooldownHours * 3600_000;
}

export function hoursUntilNextReminder(lastRemindedAt: string, now: Date, cooldownHours = REMIND_COOLDOWN_HOURS): number {
  const wait = new Date(lastRemindedAt).getTime() + cooldownHours * 3600_000 - now.getTime();
  return Math.max(0, Math.ceil(wait / 3600_000));
}

/** "৳200" or "৳740.67", same rule as the app (decimals only when poisha is non-zero). */
export function takaText(poisha: number): string {
  const whole = Math.floor(poisha / 100);
  const frac = poisha % 100;
  const grouped = String(whole).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return `৳${grouped}${frac ? "." + String(frac).padStart(2, "0") : ""}`;
}

export function reminderText(hostName: string, place: string, owedPoisha: number) {
  return {
    title: "a friendly nudge",
    body: `You still owe ${hostName} ${takaText(owedPoisha)} for ${place}.`,
  };
}

/** Pre-filled WhatsApp link for guests, who have no push. Digits only, Bangladesh default. */
export function whatsappLink(phone: string, text: string): string | null {
  let digits = phone.replace(/\D/g, "");
  if (digits.startsWith("00")) digits = digits.slice(2);
  if (digits.startsWith("0")) digits = "880" + digits.slice(1);
  if (digits.length < 10) return null;
  return `https://wa.me/${digits}?text=${encodeURIComponent(text)}`;
}
