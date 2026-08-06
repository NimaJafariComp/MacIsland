#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
derived_root=${DERIVED_DATA_PATH:-/private/tmp/macisland-derived}
test_adapter="${derived_root}-test/Build/Products/Debug/MacIsland.app/Contents/Resources/mediaremote-adapter.pl"

cleanup_test_adapter() {
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    command_line=$(ps -p "$pid" -o command= 2>/dev/null || true)
    if [[ "$command_line" == *"$test_adapter"* ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  done < <(pgrep -f "$test_adapter" || true)
  return 0
}

trap cleanup_test_adapter EXIT

cd "$repo_root"

for configuration in Debug Release; do
  xcodebuild \
    -project MacIsland.xcodeproj \
    -scheme MacIsland \
    -configuration "$configuration" \
    -derivedDataPath "${derived_root}-${configuration:l}" \
    CODE_SIGNING_ALLOWED=NO \
    build
done

xcodebuild \
  -project MacIsland.xcodeproj \
  -scheme MacIsland \
  -destination 'platform=macOS' \
  -derivedDataPath "${derived_root}-test" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY=- \
  PRODUCT_BUNDLE_IDENTIFIER=com.macisland.validation \
  test

debug_app="${derived_root}-debug/Build/Products/Debug/MacIsland.app"
plutil -extract CFBundleIdentifier raw "$debug_app/Contents/Info.plist"
plutil -p MacIsland/MacIsland.entitlements
plutil -p MacIslandXPCHelper/MacIslandXPCHelper.entitlements
[[ -f "$debug_app/Contents/Resources/NOTICE.md" ]] || { print -u2 'Missing bundled NOTICE.md.'; exit 1; }
[[ -f "$debug_app/Contents/Resources/THIRD_PARTY_NOTICES.md" ]] || { print -u2 'Missing bundled THIRD_PARTY_NOTICES.md.'; exit 1; }
[[ -f "$debug_app/Contents/Resources/LICENSE" ]] || { print -u2 'Missing bundled LICENSE.'; exit 1; }
[[ -f "$debug_app/Contents/Resources/THIRD_PARTY_LICENSES" ]] || { print -u2 'Missing bundled THIRD_PARTY_LICENSES.'; exit 1; }
if rg -n 'https://github\\.com/TheBoredTeam/boring\\.notch|Boring Notch upstream|MacIsland is GPL-3\\.0 open source and based on Boring Notch|theboringteam\\.boringnotch|TheBoredTeam\\.github\\.io/boring\\.notch/appcast\\.xml' \
  MacIsland MacIslandXPCHelper --glob '*.swift'; then
  print -u2 'Found prohibited user-facing branding.'
  exit 1
fi
