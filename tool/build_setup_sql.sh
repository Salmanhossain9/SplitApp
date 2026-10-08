#!/usr/bin/env bash
# Joins the migrations into one file you can paste into the Supabase SQL editor.
#   tool/build_setup_sql.sh           rewrites supabase/setup_all.sql
#   tool/build_setup_sql.sh --check   fails if setup_all.sql is out of date (CI and tests/run.sh)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/supabase/setup_all.sql"
tmp="$(mktemp)"
{
  echo "-- Splitbit database setup. Paste this whole file into the Supabase SQL editor and run it ONCE"
  echo "-- on a new project. It is generated from supabase/migrations by tool/build_setup_sql.sh."
  for f in "$root"/supabase/migrations/*.sql; do
    echo
    echo "-- ======================================================================"
    echo "-- $(basename "$f")"
    echo "-- ======================================================================"
    cat "$f"
  done
} > "$tmp"
if [ "${1:-}" = "--check" ]; then
  diff -q "$tmp" "$out" >/dev/null || { echo "supabase/setup_all.sql is out of date: run tool/build_setup_sql.sh"; rm -f "$tmp"; exit 1; }
  rm -f "$tmp"; echo "setup_all.sql is up to date"
else
  mv "$tmp" "$out"; echo "wrote $out"
fi
