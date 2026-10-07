# Decisions

Source of truth is the SplitUp build spec (Flutter + Supabase). Anything the spec leaves open is recorded here.

## Stack
- **Flutter, not Expo.** An earlier spec asked for React Native + Expo. The final spec is Flutter + Supabase, so any Expo/TypeScript scaffolding was dropped.
- **Old root-level Flutter prototype removed.** The repo started with a small Flutter prototype at the root (dashboard + new bill). It is replaced by `apps/mobile` per the spec's layout. It stays in git history (`c89346b`).
- Dart SDK constraint `^3.9.0` (built and tested with Flutter 3.47 / Dart 3.13).

## Split math
- **Tie-break in `splitByWeight` goes to the higher index.** The spec text says lower index, but its own golden table needs the opposite. For Chillox "by what they ate", Rafi (78.175) and Nabil (67.555) tie exactly on the remainder. Lower index gives Rafi ৳740.68 and Nabil ৳640.05; the golden table says Rafi ৳740.67 and Nabil ৳640.06. Golden table wins ("reproduces exactly"). The TS port in `supabase/functions/_shared/split.ts` must use the same rule.
- The only claim assignment of the four sample items that reproduces the golden per-person item totals: Burger -> You; Beef -> Rafi + Nabil; Fries -> You + Tania; Coke x3 -> You + Rafi + Tania. It is encoded in `fixtures/split_golden.json`.
- In equally and custom modes, `items_amount`/`extras_amount` on shares are derived (equal split of subtotal / proportional split of extras) so `total = items + extras` always holds. Only `total` is authoritative.

## Money display
- 3-digit grouping (`৳2,236`, `৳13,800`) as in the designs. Switching to lakh/crore grouping (`৳1,00,000`) is a later, one-function change in `split_core/lib/src/money.dart`.

## Fonts
- Plus Jakarta Sans (bundled) has **no ৳ glyph** (checked with fontTools). Noto Sans Bengali (Regular/Medium/Bold, OFL) is bundled and set as `fontFamilyFallback` on every text style via `AppFonts.bengaliFallback`.

## Tooling
- No Android SDK in the cloud sandbox: `flutter analyze` and `flutter test` run here, but device checks (camera, ৳ on a real phone, full flow) have to be done on a real Android device.
- Bill editing after finalize: v1 allows only voiding and re-creating a bill.
