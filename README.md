# splitup

Bill splitting for friend groups in Bangladesh. Scan the receipt, tap who had what, split VAT and
service fairly, and track who has paid (cash, bKash, bank). Friends without the app see their share
through a link. All money is integer poisha; the currency is BDT (৳).

```
apps/mobile/            Flutter app (Android first)
packages/split_core/    Pure Dart split maths, shared golden fixtures
fixtures/               split_golden.json, used by Dart and Deno tests
supabase/
  migrations/           schema, RLS, storage, server functions
  functions/            finalize-bill, scan-receipt, share-view, send-reminders (Deno)
  tests/                SQL tests for RLS and finalize (run on plain Postgres)
  seed.sql              demo user and the Chillox sample
web/share/              static public share page (host anywhere, rewrite /s/* to index.html)
tool/lint_design.sh     fails on hardcoded colours, shadows, gradients, thin outlines
tool/web_e2e/           real-browser smoke test of the whole demo flow (builds Flutter web in a temp copy)
DECISIONS.md            every call the spec left open
```

## Run the app

Without a backend the app runs in **local demo mode**: no login, sample groups, nothing leaves the
device.

```bash
cd apps/mobile
flutter pub get
flutter run                                    # demo mode
```

With Supabase, copy `env.example.json` to `env.json`, fill it in, then:

```bash
flutter run --dart-define-from-file=env.json
```

## Backend

```bash
supabase start                 # Postgres, Auth, Storage, Inbucket (codes arrive at :54324)
supabase db reset              # runs migrations and seed.sql (demo@splitup.app)
supabase functions serve       # edge functions locally
```

Secrets for the functions (`supabase secrets set ...`):

| Secret | Used by |
|---|---|
| `ANTHROPIC_API_KEY` (and optionally `SCAN_MODEL`) | `scan-receipt` |
| `SHARE_BASE_URL` | `finalize-bill`, `send-reminders` (link base, default `https://splitup.app`) |
| `FCM_SERVICE_ACCOUNT` (service account JSON) | `send-reminders` push |
| `CRON_SECRET`, `REMIND_AFTER_DAYS` | daily reminder cron |

Production login emails need a custom SMTP provider (Resend, Brevo, ...) in the Supabase dashboard,
and the email template in `supabase/templates/code.html` (it shows `{{ .Token }}`).

Phone and SMS login are not part of v1 and must stay disabled.

## Checks (what CI runs)

```bash
(cd packages/split_core && dart test)                 # golden + randomized sum-equals-total tests
(cd apps/mobile && flutter analyze && flutter test)   # widgets, goldens, flow tests
tool/lint_design.sh
deno test --allow-read --config supabase/functions/deno.json supabase/functions/
supabase/tests/run.sh                                 # migrations + RLS tests on throwaway Postgres
tool/web_e2e/run.sh                                   # optional: whole flow in Chromium (needs flutter, node)
```
