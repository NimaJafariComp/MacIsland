#!/bin/zsh
set -euo pipefail

if (( $# != 1 )); then
  print -u2 'usage: Scripts/verify-distribution.sh /path/to/MacIsland.app'
  exit 64
fi

app_path=${1:A}
[[ -d "$app_path" ]] || { print -u2 "Missing app: $app_path"; exit 66; }

codesign --verify --deep --strict --verbose=4 "$app_path"

signature=$(codesign -dvvv "$app_path" 2>&1)
if [[ "$signature" != *'Authority=Developer ID Application:'* ]]; then
  print -u2 'Distribution gate failed: app is not signed with a Developer ID Application certificate.'
  exit 65
fi

spctl --assess --type execute --verbose=4 "$app_path"
xcrun stapler validate "$app_path"
print "Distribution verification passed: $app_path"
