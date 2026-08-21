#!/usr/bin/env bash
#
# Regenerates the launcher icon on both platforms, from the mark up.
#
#   tool/icons.sh
#
# Three steps, in order:
#
#   1. Draw the 1024 masters into assets/icon/ from the stone geometry in
#      tool/icon/generate_icon_sources.dart, which mirrors the app's own
#      CairnMark painter
#   2. Fan them out with flutter_launcher_icons: every Android mipmap density,
#      the adaptive foreground, background and monochrome layers with their XML,
#      and every slot in the iOS AppIcon.appiconset
#   3. Check the iOS set is the right sizes with no alpha channel, which is what
#      App Store Connect rejects an upload for
#
# Everything it writes is committed. Nothing under assets/icon/ is bundled into
# the app; it is not listed under `flutter: assets:`. See docs/app-icon.md.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "==> drawing the 1024 masters"
dart run tool/icon/generate_icon_sources.dart

echo "==> fanning out to Android and iOS"
dart run flutter_launcher_icons

# flutter_launcher_icons rewrites every line containing ASSETCATALOG in the
# Xcode build configuration to the icon set's name, which turns
# ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES into
# = AppIcon. Xcode builds anyway, so the change is silent, and it has nothing to
# do with the icon: the set was already called AppIcon. Put it back, so the
# script leaves the Xcode project exactly as it found it.
sed -i '' \
  's/\(ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = \)AppIcon;/\1YES;/' \
  ios/Runner.xcodeproj/project.pbxproj

echo "==> checking the iOS set"
dart run tool/icon/check_ios_opaque.dart

echo "==> done"
