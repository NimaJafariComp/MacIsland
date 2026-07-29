#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
derived_root=${DERIVED_DATA_PATH:-/private/tmp/macisland-derived}

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
if rg -n 'theboringteam\\.boringnotch|TheBoredTeam\\.github\\.io/boring\\.notch/appcast\\.xml|Alcove|Perch|DynamicLake' \
  MacIsland MacIslandXPCHelper; then
  print -u2 'Found prohibited upstream or reference-product branding.'
  exit 1
fi
