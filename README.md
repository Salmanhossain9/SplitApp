# splitup

Bill splitting for friend groups in Bangladesh. Scan the receipt, tap who had what, split VAT and
service fairly, and track who has paid (cash, bKash, bank). Friends without the app see their share
through a link. All money is integer poisha; the currency is BDT (৳).

```
apps/mobile/            Flutter app (Android first)
packages/split_core/    Pure Dart split maths, shared golden fixtures
fixtures/               split_golden.json, used by Dart and Deno tests
supabase/
  migrations/           schema, RLS, realtime, server functions
  functions/            finalize-bill, share-view, send-reminders (Deno)
  tests/                SQL tests for RLS and finalize (run on plain Postgres)
  setup_all.sql         all migrations in one file, paste it into the Supabase SQL editor
  seed.sql              local dev only: a demo user and the Chillox sample
web/share/              static public share page (host anywhere, rewrite /s/* to index.html)
tool/lint_design.sh     fails on hardcoded colours, shadows, gradients, thin outlines
tool/ocr_fixtures/      renders receipts and runs Tesseract to make parser test data
docs/SUPABASE_SETUP.md  step by step: connect the app to Supabase
DECISIONS.md            every call the spec left open
```

## Run the app

Without a backend the app runs in **offline mode**: no login, data stays on the phone. Receipt
scanning (Google ML Kit, on the phone) works either way.

```bash
cd apps/mobile
flutter pub get
flutter run                                    # offline mode
```

To connect Supabase follow **[docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md)** (about 30 minutes,
all free). In short: copy `env.example.json` to `env.json`, fill it in, run
`flutter run --dart-define-from-file=env.json`.

## Checks (what CI runs)

```bash
(cd packages/split_core && dart test)                 # golden + randomized sum-equals-total tests
(cd apps/mobile && flutter analyze && flutter test)   # widgets, goldens, flow tests
tool/lint_design.sh
deno test --allow-read --config supabase/functions/deno.json supabase/functions/
supabase/tests/run.sh                                 # migrations + RLS tests on throwaway Postgres
```
