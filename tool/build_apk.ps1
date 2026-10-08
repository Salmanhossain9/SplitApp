# Builds the APK you can send to friends. Run from anywhere:  powershell -File tool\build_apk.ps1
# Needs apps\mobile\env.json (your Supabase URL and publishable key) and, for a shareable build,
# apps\mobile\android\key.properties (see docs\BUILD_APK.md).
$ErrorActionPreference = "Stop"
$mobile = Join-Path $PSScriptRoot "..\apps\mobile"
Set-Location $mobile
if (-not (Test-Path "env.json")) { throw "env.json is missing. Copy env.example.json and fill it in." }
if (-not (Test-Path "android\key.properties")) {
  Write-Warning "android\key.properties is missing: this APK will be signed with the debug key. Follow docs\BUILD_APK.md step 1 first if you are sharing it."
}
flutter build apk --release --split-per-abi --dart-define-from-file=env.json
$out = Resolve-Path "build\app\outputs\flutter-apk"
Write-Host ""
Write-Host "Done. Send this one to friends (works on nearly every phone):"
Write-Host "  $out\app-arm64-v8a-release.apk"
Write-Host "Older 32 bit phones need:  $out\app-armeabi-v7a-release.apk"
