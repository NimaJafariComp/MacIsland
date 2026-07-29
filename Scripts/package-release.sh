#!/bin/zsh
set -euo pipefail

if (( $# != 2 )); then
  print -u2 'usage: Scripts/package-release.sh /path/to/MacIsland.app /path/to/MacIsland.zip'
  exit 64
fi

app_path=${1:A}
archive_path=${2:A}
repo_root=${0:A:h:h}
staging_dir=$(mktemp -d "${TMPDIR:-/tmp}/macisland-release.XXXXXX")
trap 'rm -rf "$staging_dir"' EXIT

[[ -d "$app_path" ]] || { print -u2 "Missing app: $app_path"; exit 66; }
mkdir -p "$staging_dir/MacIsland"
ditto "$app_path" "$staging_dir/MacIsland/MacIsland.app"
cp "$repo_root/LICENSE" "$repo_root/THIRD_PARTY_LICENSES" "$staging_dir/MacIsland/"
codesign --verify --deep --strict --verbose=2 "$staging_dir/MacIsland/MacIsland.app"
rm -f "$archive_path"
ditto -c -k --keepParent "$staging_dir/MacIsland" "$archive_path"
