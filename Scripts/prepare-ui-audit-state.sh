#!/bin/zsh
set -euo pipefail

if (( $# != 2 )); then
  print -u2 'usage: Scripts/prepare-ui-audit-state.sh /path/to/MacIsland.app closed|dismissed|home|expanded|hover'
  exit 64
fi

app_path=${1:A}
state=$2
[[ -d "$app_path" ]] || { print -u2 "Missing app: $app_path"; exit 66; }
[[ "$state" == closed || "$state" == dismissed || "$state" == home || "$state" == expanded || "$state" == hover ]] || {
  print -u2 "Unsupported UI audit state: $state"
  exit 64
}
command -v cliclick >/dev/null || {
  print -u2 'cliclick is required for approved Assistive-Access state preparation.'
  exit 69
}

open "$app_path"
for _ in {1..50}; do
  if osascript -l JavaScript -e 'const windows = Application("System Events").processes.byName("MacIsland").windows.length; if (windows < 1) throw new Error("MacIsland has no accessibility window");' >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

if ! osascript -l JavaScript -e 'const windows = Application("System Events").processes.byName("MacIsland").windows.length; if (windows < 1) throw new Error("MacIsland has no accessibility window");' >/dev/null 2>&1; then
  print -u2 'MacIsland did not expose an accessibility window.'
  exit 78
fi

read -r screen_width screen_height <<< "$(osascript -l JavaScript <<'JXA'
ObjC.import('AppKit');
const frame = $.NSScreen.mainScreen.frame;
`${Number(frame.size.width)} ${Number(frame.size.height)}`;
JXA
)"
safe_y=$(( screen_height - 16 ))

# `cliclick` uses logical desktop points. Derive the target from the actual
# accessibility window rather than a screenshot or an assumed display center;
# Retina captures have twice the pixel dimensions and previously produced false
# interaction failures when those coordinate systems were mixed.
read -r island_x island_y island_width island_height <<< "$(osascript -l JavaScript <<'JXA'
const window = Application("System Events").processes.byName("MacIsland").windows[0];
const position = window.position();
const size = window.size();
`${Math.round(position[0])} ${Math.round(position[1])} ${Math.round(size[0])} ${Math.round(size[1])}`;
JXA
)"
target_x=$(( island_x + island_width / 2 ))
# On a notched Mac, y=15 can fall inside the physical camera housing. Use the
# visible lower edge of the closed hit target instead, while remaining safely
# inside the panel on notchless displays.
target_y=$(( island_y + (island_height < 40 ? island_height / 2 : 40) ))

# Moving away first gives the island's normal close path time to settle. The
# eased movement preserves the production hover path instead of teleporting
# through it as a synthetic coordinate jump.
cliclick -e 3 -w 50 "m:16,$safe_y" w:700

case "$state" in
  closed|dismissed) ;;
  home|expanded) cliclick -e 3 -w 50 "m:$target_x,$target_y" w:250 "c:$target_x,$target_y" w:500 ;;
  # The default hover frame is centered on the island. Keeping the audit
  # pointer on the live AX window center exercises the production hit target
  # regardless of display scale or the optional extended-hover preference.
  hover) cliclick -e 3 -w 50 "m:$target_x,$target_y" w:500 ;;
esac

print "Prepared MacIsland UI audit state: $state"
