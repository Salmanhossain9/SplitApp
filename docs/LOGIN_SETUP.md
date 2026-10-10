# Login with Google and with an email code

The login screen offers: **continue with Google**, **continue with Apple** (a placeholder for now),
and **send me a code** to an **email**. Email codes already work. Google needs a one time setup that only
you can do, below. Phone login was removed for now (SMS costs money and Banglalink numbers were a problem
elsewhere); the code is easy to bring back when you pick an SMS service.

**Log in and sign up are the same thing.** Nobody sets a password. A new email or Google
account simply creates the account the first time. The two tabs only change the wording.

---

## Google

You need a free Google Cloud project. About 10 minutes.

1. Open https://console.cloud.google.com and sign in. At the top, **Select a project** → **New project**,
   name it `Splitbit`, create it, and make sure it is the selected project.
2. Left menu → **APIs & Services** → **OAuth consent screen** (the new layout calls it **Google Auth platform**).
   - **User type: External**, then **Create**.
   - App name `Splitbit`, your email as the support email and the developer email. Save and continue.
   - Scopes: leave the defaults (email, profile, openid). Save and continue.
   - **Publishing status**: press **Publish app** (or **Make external**). If you leave it on *Testing*, only
     the test users you list can log in, and your friends will be refused. Plain email and profile access
     needs no Google review.
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**.
   - **Application type: Web application** (yes, Web, even though the app is Android).
   - Name `Splitbit`.
   - **Authorized redirect URIs → Add URI**:
     ```
     https://iykuzkqapxkibrkqzcjb.supabase.co/auth/v1/callback
     ```
     (your Supabase project URL, then `/auth/v1/callback`).
   - **Create**. Copy the **Client ID** and the **Client secret**.
4. Supabase dashboard → **Authentication → Sign In / Providers → Google**:
   switch **Enable** on, paste the **Client ID** and **Client secret**, **Save**.
5. Supabase → **Authentication → URL Configuration → Redirect URLs → Add URL**:
   ```
   splitbit://login-callback
   ```
   Save. This is how the browser hands the person back to the app.
6. **Rebuild the app.** The app needs its new Android link filter, so run `flutter run` again or
   build a new APK (`tool\build_apk.ps1`).

Try it: **continue with Google** opens the browser, the person picks an account, and the app opens again
signed in. New people then see the profile screen with their Google name already filled in.

If the screen says "google sign-in is not set up yet", step 4 is missing or the Client ID is wrong.
If the browser shows a *redirect_uri_mismatch* error, the URI in step 3 does not match exactly.
If the browser finishes but the app does not open, step 5 is missing or you did not rebuild.

---

## Apple
**continue with Apple** is a placeholder: it tells the person it is coming soon. Real Apple sign-in needs
an Apple developer account and an iPhone build, which is not set up yet.
