# Connect Splitbit to Supabase (step by step)

Takes about 30 minutes, all on free plans. You need: a Supabase account, a free Netlify account
(to host the share page), and this repo cloned on your computer.

Receipts are read **on the phone** with Google ML Kit, so there is no AI key to set up.

---

## 1. Create the project
1. Go to https://supabase.com, sign in, click **New project**.
2. Name it `splitup`. Choose a **database password** and save it somewhere (you rarely need it).
3. Region: the closest to you (for Bangladesh, **Singapore** or **Mumbai**). Plan: **Free**.
4. Wait about two minutes until the project is ready.

## 2. Copy your two keys
In the project open **Project Settings → API** (or press the green **Connect** button).
- **Project URL**, like `https://abcdxyz.supabase.co`
- **anon / publishable key**, a long text. This one is safe to put in the app.

Never put the **service_role** key in the app or in git.

Now create the file `apps/mobile/env.json` (it is git-ignored) by copying `env.example.json`:
```json
{
  "SUPABASE_URL": "https://abcdxyz.supabase.co",
  "SUPABASE_ANON_KEY": "paste-the-anon-key-here",
  "SHARE_BASE_URL": "https://your-site.netlify.app"
}
```
Leave `SHARE_BASE_URL` for now, you get it in step 6.

## 3. Create the database
1. In Supabase open **SQL Editor → New query**.
2. Open `supabase/setup_all.sql` from this repo, copy **everything**, paste it, click **Run**.
3. You should see "Success. No rows returned". Open **Table Editor**: you should see `profiles`,
   `friends`, `groups`, `bills`, `items`, `claims`, `charges`, `shares`, `settlements`,
   `notifications` and more. Run the file only once on a new project.

This also turns on the security rules (Row Level Security), so each person only sees their own bills.

## 4. Set up login by email code
1. **Authentication → Sign In / Providers → Email**: make sure it is **enabled**. Check
   **Email OTP Length = 6** (the app expects 6 digits).
2. **Set up your own email sender first.** Supabase locks the email templates until custom SMTP
   is on (the page says "Set up custom SMTP to edit templates"), and the default template sends a
   link, not a code. Quickest free option is your Gmail:
   - Google Account → Security: turn on 2-Step Verification, then open
     https://myaccount.google.com/apppasswords and create an app password (16 letters).
   - Supabase **Authentication → Emails → SMTP Settings** (or the "Set up SMTP" button): enable,
     sender email = your Gmail, sender name `Splitbit`, host `smtp.gmail.com`, port `465`,
     username = your Gmail, password = the app password.
   - Gmail is fine for testing and small groups. For many users use Brevo (free, 300/day) or
     Resend (free, needs your own domain) on the same screen.
3. **Authentication → Emails → Templates**. Edit **both** *Magic link* and *Confirm sign up*
   (use the **Source** tab):
   - Subject: `Your Splitbit code`
   - Body: paste the contents of `supabase/templates/code.html` (it shows `{{ .Token }}`, the 6 digit code).
   Save each one. A new email address gets *Confirm sign up*, a returning one gets *Magic link*.

## 5. Deploy the three functions
Open a terminal in the repo root (VS Code terminal is fine). You need Node.js installed.
```powershell
npx supabase@latest login
npx supabase@latest link --project-ref abcdxyz
```
(`abcdxyz` is the part of your Project URL before `.supabase.co`. If it asks for the database
password, enter the one from step 1.) Then:
```powershell
npx supabase@latest functions deploy finalize-bill --use-api
npx supabase@latest functions deploy share-view --use-api --no-verify-jwt
npx supabase@latest functions deploy send-reminders --use-api
```
`--use-api` means Docker is not needed. `--no-verify-jwt` is only for `share-view`, because
friends open it without an account.

> Google and phone login are set up separately: see `docs/LOGIN_SETUP.md`.

## 6. Host the share page (so friends can see their bill)
1. Open `web/share/config.js` and replace `YOUR-PROJECT` with your project reference:
   `https://abcdxyz.supabase.co/functions/v1/share-view`
2. Go to https://app.netlify.com/drop and drag the **`web/share`** folder onto the page.
   Netlify gives you an address like `https://something.netlify.app`.
3. Put that address in `apps/mobile/env.json` as `SHARE_BASE_URL`, and tell the functions:
   ```powershell
   npx supabase@latest secrets set SHARE_BASE_URL=https://something.netlify.app
   ```
Share links now look like `https://something.netlify.app/s/<token>`.

## 7. Run the app on your phone
```powershell
cd apps/mobile
flutter run --dart-define-from-file=env.json
```
In VS Code you can press **F5** and pick **Splitbit (connected to Supabase)**.
The Settings tab says "connected to your Supabase project" when it worked.

## 8. Check it end to end
1. Log in with your email, type the 6 digit code, finish the profile screen.
2. Add a bill: place, friends (add a friend with **+**), scan or add items, claim, send bills.
3. In Supabase **Table Editor**, `bills`, `items`, `shares` and `settlements` now have rows.
4. Open the share link in a browser on another phone: the bill and your bKash number show.
5. Settle with a tab, then tap **remind**. A friend with a phone number opens WhatsApp.

## If something fails
| Problem | Check |
|---|---|
| No email arrives | **Authentication → Logs**. Built-in sender limit? Use your own email, or set up SMTP (step 4.3). |
| Code is rejected | The email must show `{{ .Token }}` in **both** templates, OTP length 6. Request a new code. |
| "you cannot change this bill" | `setup_all.sql` did not finish. Re-create the project, run it again from the top. |
| "could not send the bills" | **Edge Functions → finalize-bill → Logs** shows the reason. Was it deployed? |
| Share page says "not set up yet" | `web/share/config.js` still has `YOUR-PROJECT`. Edit, upload to Netlify again. |
| "this link does not exist" on the share page | `share-view` was deployed without `--no-verify-jwt`, or the URL in `config.js` is wrong. |
| Windows build error "Could not close incremental caches" | Project and Flutter cache are on different drives. Add `kotlin.incremental=false` to `apps/mobile/android/gradle.properties`. |

## Optional: push notifications for reminders
Reminders already appear in the app's notifications tab. For phone push you need a Firebase
project: add `apps/mobile/android/app/google-services.json`, create a service account key and set
it with `npx supabase@latest secrets set FCM_SERVICE_ACCOUNT="$(cat key.json)"`, then run the app
with `--dart-define=FIREBASE_ENABLED=true` too.

## Running the checks yourself
`supabase/tests/run.sh` creates a throwaway Postgres, runs `setup_all.sql` and about 80 security
checks. If you ever change a migration, run `tool/build_setup_sql.sh` to refresh `setup_all.sql`.
