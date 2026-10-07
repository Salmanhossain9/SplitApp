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

## Milestone 3 (core flow, local only)
- **Hand-written immutable models instead of freezed** for now (`Person`, `DraftBill`). Server models mirroring the tables get added with the backend in milestone 4; freezed + build_runner can replace the hand-written ones then if the boilerplate hurts.
- **Default VAT and service rate is 5.9% each** (the sample's rate), both editable on screen 9. Real Bangladeshi restaurants often charge 15% VAT and 10% service, but the spec calls 5.9 the default, so that stays until a design says otherwise.
- **Extras option tiles only show in "by items" mode.** In "equally" mode the whole total is split and in "custom" the typed amounts already contain extras (spec 10.2), so screen 9 shows a one-line note there instead of the tiles.
- **Changing a rate on screen 9 after typing custom amounts** can break the exact match. The bills banner turns coral and `send bills` stays disabled until the person goes back and fixes the amounts.
- **Settle model.** Per friend: a method (cash / bKash / bank / owes me) and an `owed` amount (the open tab). Cash, bKash or bank = paid in full. "owes me" starts with the whole share as a tab; the cover control (steps of ৳50, and the amount is also directly editable, because the sample's ৳200 of ৳269 is not reachable in steps of 50) lowers the tab and the remainder counts as paid. The host's own share is excluded from the collection target.
- `finish bill` needs every friend to have a method. Open tabs stay open after finishing.
- **Claim-by-items routing:** 5+ participants (host included) use the bottom sheet, which auto-opens on the first unclaimed item and advances to the next one after `done`.
- **Receipt scan buttons are a stub** (snackbar, switches to manual) until milestone 5. Home is a placeholder until milestone 6. `finish bill` goes home until the done screen lands in milestone 7.
- **Draft persistence:** `DraftBill` serialises to JSON in `shared_preferences` (debounced 300 ms) and is restored through `DraftBillNotifier.restore()`. Wiring `restore()` into the app start and the "resume draft" prompt happens with the home screen.
- Avatars that match the lime ring colour are drawn lavender inside avatar chips so the ring stays visible.

## Milestone 4 (backend)
- **Supabase integration code has not been run against a live project** from the cloud sandbox (no Docker, no Supabase). What *is* verified: every migration, RLS policy, trigger and server function against real Postgres 16 (`supabase/tests/run.sh`, about 90 checks), the edge function logic with Deno tests, and the row mapping the app uses (`bill_rows_test.dart`). The first `supabase start` + device run should be treated as the integration test.
- **`finalize_bill_apply` SQL function does the transaction.** Edge functions cannot open a multi-statement transaction through supabase-js, so `finalize-bill` computes the shares (shared TS split maths) and hands them to one service-role-only SQL function that stores shares and settlements, re-checks that shares add up, and opens the bill atomically. The `assert_shares_sum` trigger is a second guard (and refuses a zero-total bill).
- **Two extra `bill_participants` columns** (`in_split`, `custom_amount`) so the server can recompute "equally" (who shares) and "custom" (typed amounts) bills. The spec's tables had nowhere to keep them.
- **Settlements exist for friends only**, not for the host (the host paid at the restaurant). A trigger keeps each row consistent: a chosen method needs `paid + owed = share`, an open tab means status `tab`. `covered_amount` equals the open tab the host fronts.
- **After a bill is open it is frozen** (items, claims, charges and participants can't change; triggers enforce it). Voiding means deleting the bill and re-creating it.
- **Participants (app users on a bill) read** the bill, their own share and their own settlement. They cannot read other people's shares. Other users' names come through the `public_profiles` view; bKash numbers are only exposed by `share-view`.
- **`shares`, `settlements` inserts and `notifications` inserts are service-role only.** Authenticated users get no insert/delete privilege on them at all, in addition to RLS.
- **The public share page is a static HTML file** (`web/share/index.html`), not an Edge Function page: Supabase serves function HTML as `text/plain`. The page calls the `share-view` function, which returns JSON and never includes emails or phone numbers.
- **Receipt model:** `scan-receipt` calls the Anthropic Messages API with the key in a secret; default model `claude-sonnet-5-5`, override with `SCAN_MODEL`. It asks for line totals and derives unit prices only when they divide evenly in poisha, so the subtotal always matches the receipt.
- **Push uses FCM HTTP v1** signed with Web Crypto from a service account secret. Without `FCM_SERVICE_ACCOUNT` a reminder still creates the in-app notification row.
- **Guests have real `friends` rows.** A guest added during a bill gets a UUID immediately and is upserted as a friend when the draft syncs. `bill_participants.id` is a deterministic uuid v5 of (bill, person), so re-saving updates rows instead of duplicating them.
- **Draft sync** runs 1.2 s after the last edit, once there is a place, two people and an item, and always right before `finalize-bill`. Sync errors surface once as a snackbar on the settle screen.
- **Demo mode** (no `env.json`): a local auth stub that is always signed in, in-memory sample groups and a no-op bill repository, so the app and all widget tests run without a backend.
- Welcome (screen 1) and the three auth screens were built here because the router redirect needs them; the rest of milestone 6 (home, dashboard, notifications) is still to come.

## Milestone 5 (scan and share)
- **Scan flow:** the scan tab opens a live camera (`camera`, back lens, no audio) behind a `CameraGateway`, with `image_picker` for the gallery. If the camera or its permission is missing the tab says so and the gallery path still works. The photo is uploaded to `receipts/{user}/{bill}/{timestamp}.{ext}` (type taken from the file header) and `scan-receipt` reads it. The result fills the editable item list; the person must still tick "does this match your receipt?" before continuing.
- **Detected VAT and service become rates** on the items subtotal (`rateBpFromAmount`, integer maths, half up). No detected line means 0%. The scanned receipt total is kept and shown next to ours with a matches/differs pill.
- **No next button on the scan tab.** There is nothing to continue with until the list is confirmed.
- **Demo mode scans the Chillox sample** after a short delay, so the whole flow is demonstrable without a backend or an API key.
- **Sharing:** after `send bills` a sheet offers the link (system share sheet), WhatsApp (`whatsapp://send`, falling back to `wa.me`) and a PNG of everyone's share (a `RepaintBoundary` capture, shared through `share_plus`). One message for the group: the link shows each friend their own bill. `settle up` closes the sheet and continues.
- **Deep links:** `https://splitup.app/s/{token}` (verified app link) and `splitup://splitup.app/s/{token}` open the in-app share view. Flutter's built-in deep link handling plus go_router does the routing, so the `app_links` package from the spec was not needed. The domain is a placeholder (`SHARE_BASE_URL`); the `assetlinks.json` for app link verification has to be hosted on the real domain.
- **Narrow bill cards scale their numbers down** instead of overflowing (found by the share image test).
- `flutter_svg` was removed: icons are drawn in code.

## Milestone 6 (home, dashboard, reminders)
- **Home is one screen driven by data** (screens 2 and 12): greeting by time of day, `SummaryCard` for the current month, `BalanceCard` "you are owed" when something is outstanding, the newest five bills, and a lavender `TabCard` per open tab with a `remind` pill. A brand new user sees one big "split a bill" tile instead.
- **The "request" action tile is hidden** until the request flow exists (spec 16 allows this).
- **Dashboard maths:** "this month" is every non-draft bill billed in the current month. *Pending* is what friends still owe on those bills (unticked friends plus open tabs); *settled* is the rest of the total, so settled + pending always equals the month total. "You are owed" counts outstanding across all months.
- **Status pill on a bill row:** coral `tab` if anyone still owes a tab, lime `settled` when finished, coral `pending` otherwise. Drafts never show in the list; a half-finished draft shows as a "pick up where you left off" card that resumes at the right step (or at settle once the bills were sent).
- **Home only lists bills the user created.** Bills where they are only a participant (read-only access exists in RLS) are not shown yet; a "bills shared with me" view is later work.
- **Tabs:** bottom nav is a `StatefulShellRoute` with home, money, notifications and settings. Bill-flow screens sit outside the shell, full screen. Opening the bell marks notifications read after about a second so the person sees what was new.
- **Reminders:** `remind` calls `send-reminders`. App users get an in-app notification row plus a push when `FCM` is set up; guests with a phone number get a WhatsApp message (`wa.me`, Bangladesh country code added to local `01...` numbers, same rule in Dart and the edge function). One reminder per tab per 24 h; a second tap shows "you already nudged X".
- **Push (FCM)** is optional and fully guarded: it needs `android/app/google-services.json` and `--dart-define=FIREBASE_ENABLED=true`. Without both, nothing Firebase runs and the build is unchanged (the google-services Gradle plugin is only applied if the JSON exists). Only `push_firebase.dart` imports Firebase. `flutter_local_notifications` (foreground banners) is **not** included: while the app is open the reminder shows up in the notifications tab live instead. Not verifiable from the sandbox (no Android SDK, no Firebase project).
- **Money tab:** open tabs on top, filter chips (all / pending / tabs / settled), bills grouped by month.
- **Settings:** name, avatar colour, bKash number (shown to friends on the share page), log out (also clears the push token).
- Demo mode keeps the dashboard honest: the local bill repository records bills as they are sent and settled, and ships two sample bills.

## Milestone 7 (success screen and motion)
- **Screen 11** (`/bill/:id/done`): lavender, lime check on a 20% white halo that pops in with a real spring (`SpringValue`, `SpringSimulation`), confetti (flat lime/lavender/coral/white pieces from a seeded generator, so it is deterministic), three twinkling sparkles, `all settled.` in celebrate72, recap tiles (sky total, lime friends, white open tabs). "friends" counts everyone on the bill, host included (the sample says "4 friends" for a bill of four people).
- **The tab pill** reads "Tania's ৳200 is saved on your tab" for one tab and "N tabs worth ৳X are saved on your tab" for several; no tabs, no pill.
- **Leaving the screen clears the draft** (`back to home`, `split another bill`). A stale link to a bill that is not settled redirects home; a `_leaving` flag stops the clear from tripping that guard (a bug the tests caught: "split another bill" used to land on home).
- **Avatar chip uses a real spring** now (overshoots about 6 px and settles on the 96 px pill). The group card lift stays a curved animation (`easeOutBack`, 420 ms), which reads the same as a spring there.
- **Motion checks are automated:** spring overshoot and settle, chip colour halfway through its 150 ms, press scale 0.96, and the avatar pill height.
- **Figma:** the file could not be opened from the sandbox, so the pass against it was done from the spec's measurements (every size, radius, colour pairing and type token comes from `tokens.dart`). A side by side check against the Figma frames on a real device is still worth doing.
