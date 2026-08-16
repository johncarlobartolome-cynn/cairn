#!/usr/bin/env bash
#
# Captures one PNG of every route, plus the mark-climbed sheet, in both themes
# on a running Android emulator.
#
#   tool/screenshots.sh
#
# Output goes to screenshots/ (gitignored) and is overwritten in place, so the file
# set is the same every run. Set CAIRN_SCREENSHOT_DIR to write elsewhere.
#
# The harness fails rather than half-succeeds: no emulator, a build error, a route
# that never leaves its loading spinner, or a missing image all exit non-zero.
#
# Written for bash 3.2, which is what macOS ships, so no mapfile and no
# associative arrays.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${CAIRN_SCREENSHOT_DIR:-$PROJECT_ROOT/screenshots}"

DRIVER="test_driver/integration_test.dart"
TARGET="integration_test/screenshot_test.dart"

# integration_test/screenshot_test.dart is the source of truth for these names.
# Listed again here so a rename fails the run instead of quietly shipping nine
# fresh images and one stale tenth.
EXPECTED="peaks-light peaks-climbed-light peak-detail-light mark-climbed-light climb-detail-light badges-light share-card-light
peaks-dark peaks-climbed-dark peak-detail-dark mark-climbed-dark climb-detail-dark badges-dark share-card-dark"
EXPECTED_COUNT=14

die() {
  echo "" >&2
  echo "screenshots: $*" >&2
  exit 1
}

for cmd in flutter adb; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is not on PATH."
done

# Emulators only, picked by state rather than by name, and a physical phone on the
# cable is deliberately left alone.
serials="$(adb devices | awk '$2 == "device" && $1 ~ /^emulator-/ { print $1 }')"

if [ -z "$serials" ]; then
  die "no Android emulator is running.
  Start one, wait for the home screen, then run this again:
    flutter emulators
    flutter emulators --launch <emulator_id>"
fi

serial="$(printf '%s\n' "$serials" | head -1)"
serial_count="$(printf '%s\n' "$serials" | wc -l | tr -d ' ')"
if [ "$serial_count" -gt 1 ]; then
  echo "screenshots: $serial_count emulators up, using $serial"
fi

# A device can report `device` while it is still booting, and an app that starts
# that early renders nothing.
booted="$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)"
[ "$booted" = "1" ] || die "$serial is attached but has not finished booting."

echo "screenshots: capturing $EXPECTED_COUNT images on $serial"
echo ""

mkdir -p "$OUT_DIR"
# Clear the last run so the count at the end counts this run's work.
rm -f -- "$OUT_DIR"/*.png

cd "$PROJECT_ROOT"
# --keep-app-running or flutter drive uninstalls the app when it finishes, and
# an uninstall takes cairn.sqlite and every climb photo with it. Harmless while
# the harness only read; T17 gave the app data worth losing.
if ! CAIRN_SCREENSHOT_DIR="$OUT_DIR" flutter drive \
  --device-id "$serial" \
  --keep-app-running \
  --driver "$DRIVER" \
  --target "$TARGET"; then
  die "flutter drive failed. The output above says why."
fi

missing=""
for name in $EXPECTED; do
  if [ ! -s "$OUT_DIR/$name.png" ]; then
    missing="$missing $name.png"
  fi
done

if [ -n "$missing" ]; then
  die "flutter drive passed but these images are missing or empty:$missing
  Check the screenshot names in $TARGET against EXPECTED in this script."
fi

count="$(find "$OUT_DIR" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
if [ "$count" -ne "$EXPECTED_COUNT" ]; then
  die "expected $EXPECTED_COUNT images in $OUT_DIR but found $count."
fi

echo ""
echo "screenshots: $count images in $OUT_DIR"
ls -1 "$OUT_DIR"/*.png | sed 's|.*/|  |'
