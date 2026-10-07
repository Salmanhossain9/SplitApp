#!/usr/bin/env bash
# Smoke test in a real browser engine. The app itself is Android/iOS only, so this builds the
# Flutter *web* target from a throwaway copy (nothing web-specific lands in the repo) and drives
# the whole demo-mode flow in Chromium: new bill, group, scan (file upload), claim in every
# mode, VAT and service, send bills, share sheet, settle with a tab, all settled, home.
# It fails if anything throws or the golden numbers do not show up.
#
#   tool/web_e2e/run.sh [screenshot-dir]        needs flutter and node; CHROMIUM=/path/to/chrome optional
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
shots="${1:-$here/screenshots}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/apps"
cp -r "$repo/apps/mobile" "$work/apps/mobile"
cp -r "$repo/packages" "$work/packages"
cd "$work/apps/mobile"
rm -rf build .dart_tool android ios test
flutter create . --platforms web --project-name splitup >/dev/null
flutter pub get >/dev/null
flutter build web --release --no-tree-shake-icons

cd "$here"
[ -d node_modules ] || npm install --silent
node e2e.mjs "$work/apps/mobile/build/web" "$shots"
