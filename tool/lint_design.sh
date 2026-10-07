#!/usr/bin/env bash
# Fails if feature or ui code breaks the design rules (spec section 14).
# lib/theme is the only place allowed to define colours, sizes and fonts.
set -u
cd "$(dirname "$0")/../apps/mobile"

DIRS="lib/features lib/ui"
# The avatar ring is the one allowed stroke.
EXCLUDE='lib/ui/avatar.dart'
PATTERNS=(
  'Color\(0x'
  'Colors\.'
  'BoxShadow'
  'elevation'
  'LinearGradient'
  'RadialGradient'
  'SweepGradient'
  'Border\.all'
  'Border\('
  'fontSize:'
  '\bdouble\b[^;=(]*\b(amount|price|total|poisha|subtotal)\w*'
)

fail=0
for pat in "${PATTERNS[@]}"; do
  hits=$(grep -rnE --include='*.dart' "$pat" $DIRS 2>/dev/null | grep -v "$EXCLUDE" || true)
  if [ -n "$hits" ]; then
    echo "design lint: forbidden pattern /$pat/"
    echo "$hits"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then echo "design lint: ok"; fi
exit "$fail"
