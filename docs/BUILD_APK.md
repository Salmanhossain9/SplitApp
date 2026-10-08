# Build an APK to share with friends (Android)

Friends install it by tapping the file. There is no Play Store step. iPhones cannot install it.

## 1. Make your signing key (once)
This key proves every update comes from you. **Keep the file and its passwords safe: if you lose it,
friends must uninstall the app before they can install a newer one.**

In PowerShell, in `F:\Splitit\splitup\apps\mobile\android\app`:
```powershell
keytool -genkey -v -keystore splitup-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias splitup
```
It asks for a password (use a long one, remember it) and some details (name, city; any answer is fine).
If `keytool` is not found, use the one that comes with Android Studio, for example
`& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey ...` (same options).

Then create the text file `apps\mobile\android\key.properties` with:
```
storePassword=THE_PASSWORD_YOU_TYPED
keyPassword=THE_PASSWORD_YOU_TYPED
keyAlias=splitup
storeFile=splitup-release.jks
```
Both files are in `.gitignore`, so they never go to GitHub. Back them up somewhere private (not in the repo).

## 2. Check `env.json`
`apps\mobile\env.json` must hold your real `SUPABASE_URL`, `SUPABASE_ANON_KEY` (the `sb_publishable_` key)
and `SHARE_BASE_URL`. The build bakes these into the app, so friends sign in to *your* Supabase project.
The publishable key is meant to be inside apps. Never put the `sb_secret_` key anywhere in the app.

## 3. Raise the version for every new build you send
In `apps\mobile\pubspec.yaml`: `version: 1.0.0+1`. The number after `+` must go up each time
(`+2`, `+3`...) or Android refuses to install it over the old one.

## 4. Build
From the repo root:
```powershell
powershell -File tool\build_apk.ps1
```
(or by hand in `apps\mobile`: `flutter build apk --release --split-per-abi --dart-define-from-file=env.json`).
Send `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` (about 30 to 40 MB). Almost every phone
from the last ten years needs this one. Very old 32 bit phones need `app-armeabi-v7a-release.apk`.

**Try it on your own phone first**: `adb install -r app-arm64-v8a-release.apk` or copy it over and tap it.
A release build is shrunk differently from the `flutter run` one, so check a scan and a send before sharing.

## 5. Send it
- **Google Drive or Telegram** work well. WhatsApp often refuses `.apk` files; zip the file first if you want to use it.
- On their phone: open the file and allow **Install unknown apps** for the app they opened it from
  (Settings asks once). Google Play Protect may say "unknown developer": choose **Install anyway**.
  That is normal for an app that is not on the Play Store.
- On first open they allow the camera (for scanning) and notifications.

## If the release build fails on "Missing classes detected while running R8"
The ML Kit rules in `android/app/proguard-rules.pro` fix it. Pull the latest code, run `flutter clean`, and build again.

## What your friends need to know
- They sign in with their email and a 6 digit code. The code email comes from your Gmail sender, so it can
  land in spam the first time.
- Supabase's free plan **pauses a project after a week without activity**. If the app suddenly cannot
  load, open the Supabase dashboard and press **Restore**.
- Each friend only sees their own bills. The link you share for a bill opens in a browser and needs no app.

## Updating later
Change the code, raise the `+` number, run the build again, send the new APK. They install it over the old
one and keep their data (same key, higher number).
