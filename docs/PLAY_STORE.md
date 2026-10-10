# Publishing Splitbit on Google Play

The app id is **`app.splitbit.splitbit`**. It is permanent once you upload to Play, so this was the last
moment to change it. Phones that have the old `app.splitup.splitup` build installed must uninstall it:
Android treats the new id as a different app.

What the code now covers, and what only you can do in Play Console:

| Play requirement | Status |
|---|---|
| Final app id | Done: `app.splitbit.splitbit` |
| Account deletion inside the app | Done: Settings, **delete my account** (type `delete`) |
| Account deletion web link | Done: `delete-account.html` (host it, see below) |
| Privacy policy URL | Done: `privacy.html` (host it, fill in your contact email) |
| Terms | Done: `terms.html` |
| Data safety form | Answers below. **You must fill it in yourself in Play Console.** |
| Signed `.aab` | `tool\build_aab.ps1` |
| 12 testers for 14 days (new personal accounts) | You, see step 6 |

## 1. Host the pages
The `web/share` folder already holds the share page. It now also has `privacy.html`, `terms.html` and
`delete-account.html`. Re-upload the whole folder to Netlify (drag it onto the same site, as before).

Edit `web/share/config.js` first:
- `SPLITUP_SHARE_API`: your `https://<project>.supabase.co/functions/v1/share-view` (as before).
- `SPLITBIT_PUBLISHABLE_KEY`: the `sb_publishable_...` key. It is public by design. Needed by the delete page.
- `SPLITBIT_CONTACT_EMAIL`: a mailbox you read. The privacy policy and terms show it. Play rejects a
  policy with no way to reach you.

Your three URLs are then `https://<your-site>/privacy.html`, `https://<your-site>/terms.html` and
`https://<your-site>/delete-account.html`. The app opens these from Settings and the login screen using
`SHARE_BASE_URL` in `env.json`, so that must be this site (no trailing slash).

## 2. Turn on account deletion on the server
1. Supabase, SQL editor: paste and run `supabase/migrations/20260101000005_delete_account.sql`.
2. Deploy the function:
   ```
   npx supabase@latest functions deploy delete-account --use-api
   ```
3. Test with a throwaway account: log in, make a bill, Settings, **delete my account**. You land on the
   welcome screen, and logging in again with that email starts a brand new, empty account.

## 3. Data safety form (Play Console, App content, Data safety)
Answer the first screens like this:

- Does your app collect or share any of the required user data types? **Yes**
- Is all of the user data collected by your app encrypted in transit? **Yes** (HTTPS only)
- Do you provide a way for users to request that their data is deleted? **Yes**
  - Delete account URL: `https://<your-site>/delete-account.html`
  - Also say users can delete in the app under Settings.

Then declare these data types. For every one: **collected: yes, shared: no** (Supabase, Google and the
email provider only process data for you as service providers, which Google does not count as
"sharing"), **required** unless noted, **not processed ephemerally**.

| Category | Type | Why (purposes) | Notes |
|---|---|---|---|
| Personal info | Name | App functionality, Account management | The name the person types. |
| Personal info | Email address | App functionality, Account management | Login. |
| Personal info | Phone number | App functionality | **Optional.** A friend's number, and the user's bKash number. |
| Financial info | Other financial info | App functionality | Bill items and amounts, who owes whom. The app never touches money. |
| App info and performance | none | | No crash reporter or analytics is included. |
| Device or other IDs | Device or other IDs | App functionality | Push token. **Optional**, only if the user allows notifications and you shipped `google-services.json`. If you did not set up Firebase, leave this out. |

Say **no** to: location, contacts, photos and videos (the camera image is read on the phone by ML Kit and
never sent anywhere), audio, files, calendar, health, messages, web browsing, search history, and any
analytics or advertising use. Camera access itself is not a data type; it is covered by the permission.

If you later add analytics, ads, a crash reporter or phone login, this table must be updated first.

## 4. Other forms in App content
- **Privacy policy:** the `privacy.html` URL.
- **Ads:** No ads.
- **App access:** reviewers have to log in. Email codes go to *your* inbox, so a reviewer cannot use them.
  Create a dedicated Google account just for review (turn 2-step verification off for it), and put its
  email and password in "App access" with the note: "Tap continue with Google, then use this account."
  Google sign-in opens a browser, so check once yourself that it works with that account.
- **Content rating:** answer the questionnaire honestly: no violence, no sexual content, no gambling, no
  user-to-user chat, no location sharing. Expect **Everyone** (PEGI 3).
- **Target audience:** choose **18 and over**. It handles money between friends and the policy says 13+.
  Choosing adults avoids the Families policy.
- **Financial features:** Splitbit calculates shares only. It does not move, hold or lend money, so choose
  that the app has no financial features. If you later add in-app payments, redo this.
- **Government app / news / health / COVID:** No.
- **Permissions in the manifest** are only `INTERNET`, `CAMERA` (scan a receipt) and `POST_NOTIFICATIONS`.

## 5. Store listing (suggestion)
- **Name:** Splitbit
- **Short description (80 max):** Scan a receipt, pick who ate what, share each person's bill.
- **Full description:** Splitbit splits restaurant bills fairly. Scan the receipt, tap who had what, and
  VAT and service charge are shared out by what each person ate. Send everyone a link with their amount and
  your bKash number. Works in taka, built for Bangladesh. No ads.
- **Category:** Productivity (Finance also fits but invites extra questions).
- **Graphics:** 512x512 icon (use `apps/mobile/assets`), a 1024x500 feature graphic, and at least 2 phone
  screenshots. Take them from the app at its normal size.

## 6. Test, then release
New personal developer accounts must run a **closed test with at least 12 testers opted in for 14 days in a
row** before they can apply for production. Plan for it:
1. Build: `powershell -File tool\build_aab.ps1`, then upload `app-release.aab` under Testing, Closed
   testing, Create release. Let Play manage the app signing key (the default).
2. Add 12 or more testers by email (a Google Group is easiest) and send them the opt-in link.
3. Keep them opted in 14 days, then apply for production access in the Dashboard.
Bump the number after `+` in `apps/mobile/pubspec.yaml` before every upload.

Back up `splitup-release.jks` and its passwords (the file name still says splitup; that is fine, it is only
a file name). It is your upload key; if you lose it, Play can reset it, but it takes days.
