# Builds the Android App Bundle (.aab) that Google Play wants. Run from anywhere:
#   powershell -File tool\build_aab.ps1
# Needs apps\mobile\env.json and apps\mobile\android\key.properties (see docs\BUILD_APK.md step 1).
# Raise the number after "+" in apps\mobile\pubspec.yaml for every upload: Play refuses a repeat.
$ErrorActionPreference = "Stop"
$mobile = Join-Path $PSScriptRoot "..\apps\mobile"
Set-Location $mobile
if (-not (Test-Path "env.json")) { throw "env.json is missing. Copy env.example.json and fill it in." }
if (-not (Test-Path "android\key.properties")) { throw "android\key.properties is missing. Play needs a signed bundle: follow docs\BUILD_APK.md step 1." }
flutter build appbundle --release --dart-define-from-file=env.json
$out = Resolve-Path "build\app\outputs\bundle\release"
Write-Host ""
Write-Host "Done. Upload this file in Play Console (Testing > Closed testing > Create release):"
Write-Host "  $out\app-release.aab"
