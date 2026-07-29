#!/bin/zsh
set -euo pipefail

if (( $# != 2 )); then
  print -u2 'usage: Scripts/create-dmg.sh /path/to/MacIsland.app /path/to/MacIsland.dmg'
  exit 64
fi

app_path=${1:A}
dmg_path=${2:A}
repo_root=${0:A:h:h}
staging_dir=$(mktemp -d "${TMPDIR:-/tmp}/macisland-dmg.XXXXXX")

cleanup() {
  [[ -d "$staging_dir" ]] && find "$staging_dir" -depth -delete
}
trap cleanup EXIT

[[ -d "$app_path" ]] || { print -u2 "Missing app: $app_path"; exit 66; }
codesign --verify --deep --strict --verbose=2 "$app_path"

mkdir -p "${dmg_path:h}"
payload_dir="$staging_dir/MacIsland"
mkdir -p "$payload_dir"
ditto "$app_path" "$payload_dir/MacIsland.app"
ln -s /Applications "$payload_dir/Applications"
cp "$repo_root/LICENSE" "$repo_root/THIRD_PARTY_LICENSES" "$payload_dir/"

# Standard Finder DMG when DiskManagement is available.
if hdiutil create -srcfolder "$payload_dir" -format UDZO -volname MacIsland "$dmg_path"; then
  exit 0
fi

# Sandboxed CI hosts can create/convert a file-only hybrid image even when
# DiskManagement cannot create or attach a blank HFS/APFS image.
[[ -e "$dmg_path" ]] && mv "$dmg_path" "$staging_dir/failed-primary.dmg"
intermediate_image="$staging_dir/MacIsland.iso"
hdiutil makehybrid -hfs -udf -hfs-volume-name MacIsland -o "$intermediate_image" "$payload_dir"
hdiutil convert "$intermediate_image" -format UDZO -o "$dmg_path"
[[ -f "$dmg_path" ]] || { print -u2 "Failed to create DMG: $dmg_path"; exit 1; }
