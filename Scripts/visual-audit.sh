#!/bin/zsh
set -euo pipefail

usage() {
  print -u2 'usage: Scripts/visual-audit.sh /path/to/MacIsland.app /absolute/output-directory [state]'
  print -u2 'state: closed | hover | home | expanded | compact | dismissed | shelf | media | timer | battery | calendar | camera | drag | reduce-motion | contrast'
  exit 64
}

(( $# >= 2 && $# <= 3 )) || usage

app_path=${1:A}
output_dir=${2:A}
state=${3:-manual}
valid_states=(closed hover home expanded compact dismissed shelf media timer battery calendar camera drag reduce-motion contrast)

(( ${valid_states[(Ie)$state]} )) || usage
[[ -d "$app_path" ]] || { print -u2 "Missing app: $app_path"; exit 66; }
[[ -t 0 ]] || { print -u2 'Run visual audit from an interactive terminal so state preparation is explicit.'; exit 69; }

mkdir -p "$output_dir"
timestamp=$(date +%Y%m%d-%H%M%S)

# Keep raw host evidence beside every capture. This makes display/notch defects
# reproducible instead of relying on a screenshot without its context.
system_profiler SPDisplaysDataType -json > "$output_dir/${timestamp}-${state}-displays.json"
system_profiler SPSoftwareDataType -json > "$output_dir/${timestamp}-${state}-software.json"

# UI automation is an external host capability. Fail before capture so a result
# cannot be misreported as an interaction test when System Events is unavailable.
if ! osascript -l JavaScript -e 'Application("System Events").processes.byName("Finder").windows.length' >/dev/null 2>&1; then
  print -u2 'Assistive Access unavailable. Grant this terminal/Xcode permission in System Settings > Privacy & Security > Accessibility, then rerun.'
  exit 77
fi

open "$app_path"
for _ in {1..50}; do
  if osascript -l JavaScript -e 'const windows = Application("System Events").processes.byName("MacIsland").windows.length; if (windows < 1) throw new Error("MacIsland has no accessibility window");' >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
if ! osascript -l JavaScript -e 'const windows = Application("System Events").processes.byName("MacIsland").windows.length; if (windows < 1) throw new Error("MacIsland has no accessibility window");' >/dev/null 2>&1; then
  print -u2 'MacIsland did not expose an accessibility window; do not capture an unverified baseline.'
  exit 78
fi
print "Prepare MacIsland state: $state"
print 'Press Return after state is visible; script captures all displays at native scale.'
read -r _

screencapture -x "$output_dir/${timestamp}-${state}.png"
print "Captured $output_dir/${timestamp}-${state}.png"
