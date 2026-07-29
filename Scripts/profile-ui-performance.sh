#!/bin/zsh
set -euo pipefail

usage() {
  print -u2 'usage: Scripts/profile-ui-performance.sh <MacIsland-pid> <absolute-output-directory> <state> [seconds]'
  print -u2 'The caller must prepare and visually verify the requested state before running this command.'
  exit 64
}

(( $# >= 3 && $# <= 4 )) || usage

pid=$1
output_dir=${2:A}
state=$3
seconds=${4:-5}

[[ "$pid" == <-> ]] || { print -u2 "Invalid PID: $pid"; exit 64; }
[[ "$seconds" == <-> ]] || { print -u2 "Invalid duration: $seconds"; exit 64; }
(( seconds >= 3 )) || { print -u2 'Duration must be at least three seconds.'; exit 64; }

process_name=$(ps -p "$pid" -o comm= 2>/dev/null || true)
[[ "$process_name" == *'/MacIsland.app/Contents/MacOS/MacIsland' ]] || {
  print -u2 "PID $pid is not a running MacIsland app process."
  exit 66
}
command -v xcrun >/dev/null || { print -u2 'xcrun is required for Instruments profiling.'; exit 69; }

mkdir -p "$output_dir"
timestamp=$(date +%Y%m%d-%H%M%S)
prefix="$output_dir/${timestamp}-${state}"
sample_count=$(( seconds + 1 ))

# Persist host context beside each measurement. The frame budget comes from the
# active display rather than an assumed 60 Hz target.
system_profiler SPDisplaysDataType -json > "${prefix}-displays.json"
refresh_hz=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); Math.round(Number($.NSScreen.mainScreen.maximumFramesPerSecond));')
frame_budget_ms=$(awk -v hz="$refresh_hz" 'BEGIN { printf "%.2f", 1000 / hz }')

# top is sampled separately from Instruments so CPU/RSS evidence is readable
# without depending on private trace schemas. Keep its raw output authoritative.
top -l "$sample_count" -s 1 -pid "$pid" -stats pid,cpu,mem > "${prefix}-top.txt"
awk -v pid="$pid" '
  function rssToMiB(value, unit) {
    gsub(/[+-]/, "", value)
    unit = substr(value, length(value), 1)
    value = substr(value, 1, length(value) - 1)
    if (unit == "G") return value * 1024
    if (unit == "M") return value
    if (unit == "K") return value / 1024
    if (unit == "B") return value / (1024 * 1024)
    return 0
  }
  $1 == pid && $2 ~ /^[0-9]+(\.[0-9]+)?$/ {
    values[++count] = $2
    if ($2 > maximum || count == 1) maximum = $2
    memory = $3
    memoryMiB = rssToMiB(memory)
    if (memoryMiB > peakMemoryMiB || count == 1) peakMemoryMiB = memoryMiB
  }
  END {
    if (count == 0) exit 1
    for (i = 1; i <= count; i++) {
      for (j = i + 1; j <= count; j++) {
        if (values[j] < values[i]) { temporary = values[i]; values[i] = values[j]; values[j] = temporary }
      }
    }
    if (count % 2) median = values[(count + 1) / 2]
    else median = (values[count / 2] + values[(count / 2) + 1]) / 2
    printf "samples=%d\ncpu_median_percent=%.1f\ncpu_max_percent=%.1f\npeak_rss_mib=%.1f\nlast_rss=%s\n", count, median, maximum, peakMemoryMiB, memory
  }
' "${prefix}-top.txt" > "${prefix}-cpu-memory.txt"

trace_path="${prefix}-animation-hitches.trace"
xcrun xctrace record \
  --template 'Animation Hitches' \
  --attach "$pid" \
  --time-limit "${seconds}s" \
  --output "$trace_path" \
  --no-prompt

# xctrace returns after writing the trace bundle, while its tables can take a
# moment to become exportable on the local host.
sleep 2

# A hitch in this template is a frame taking more than 33 ms. Surface-swap data
# is system compositor scope, so retain it as raw context and never mislabel it
# as MacIsland-only FPS.
xcrun xctrace export --input "$trace_path" \
  --xpath "/trace-toc/run[@number='1']/data/table[@schema='hitches']" \
  > "${prefix}-hitches.xml"
xcrun xctrace export --input "$trace_path" \
  --xpath "/trace-toc/run[@number='1']/data/table[@schema='displayed-surfaces-per-second']" \
  > "${prefix}-displayed-surfaces.xml"
hitch_count=$(grep -c '<row>' "${prefix}-hitches.xml" || true)

{
  print "state=$state"
  print "pid=$pid"
  print "refresh_hz=$refresh_hz"
  print "frame_budget_ms=$frame_budget_ms"
  print 'hitch_threshold_ms=33'
  print "hitch_count=$hitch_count"
  cat "${prefix}-cpu-memory.txt"
  print 'displayed_surfaces_scope=system_compositor_not_app_only'
  print "raw_top=${prefix}-top.txt"
  print "raw_hitches=${prefix}-hitches.xml"
  print "raw_displayed_surfaces=${prefix}-displayed-surfaces.xml"
  print "trace=${trace_path}"
} > "${prefix}-summary.txt"

print "Profiled MacIsland state: $state"
cat "${prefix}-summary.txt"
