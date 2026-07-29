#!/bin/zsh
set -euo pipefail

if (( $# != 1 )); then
  print -u2 'usage: Scripts/verify-ui-baselines.sh /path/to/manifest.plist'
  exit 64
fi

manifest=${1:A}
[[ -f "$manifest" ]] || { print -u2 "Missing baseline manifest: $manifest"; exit 66; }
plutil -lint "$manifest" >/dev/null

manifest_dir=${manifest:h}
expected_scale=$(plutil -extract display.scale raw "$manifest")
expected_width=$(plutil -extract display.pixelWidth raw "$manifest")
expected_height=$(plutil -extract display.pixelHeight raw "$manifest")
required_states=(closed home shelf timer)
seen_states=()

index=0
while state=$(plutil -extract "states.$index.name" raw "$manifest" 2>/dev/null); do
  image=$(plutil -extract "states.$index.image" raw "$manifest")
  expected_hash=$(plutil -extract "states.$index.sha256" raw "$manifest")
  image_path="$manifest_dir/$image"

  [[ -f "$image_path" ]] || { print -u2 "Missing baseline image: $image_path"; exit 67; }
  [[ -f "${image_path%.png}-displays.json" ]] || { print -u2 "Missing display metadata: $image_path"; exit 68; }
  [[ -f "${image_path%.png}-software.json" ]] || { print -u2 "Missing software metadata: $image_path"; exit 69; }

  actual_hash=$(shasum -a 256 "$image_path" | awk '{print $1}')
  [[ "$actual_hash" == "$expected_hash" ]] || {
    print -u2 "Baseline checksum mismatch for $state: $image_path"
    exit 70
  }

  dimensions=($(sips -g pixelWidth -g pixelHeight "$image_path" | awk '/pixelWidth|pixelHeight/ { print $2 }'))
  [[ ${#dimensions[@]} -eq 2 && "${dimensions[1]}" == "$expected_width" && "${dimensions[2]}" == "$expected_height" ]] || {
    print -u2 "Baseline dimensions mismatch for $state: $image_path"
    exit 71
  }

  seen_states+=("$state")
  (( index += 1 ))
done

for state in "${required_states[@]}"; do
  (( ${seen_states[(Ie)$state]} )) || {
    print -u2 "Missing required baseline state: $state"
    exit 72
  }
done

[[ "$expected_scale" == 2 ]] || {
  print -u2 "Unsupported baseline scale: $expected_scale"
  exit 73
}

print "UI baselines verified: ${manifest} (${seen_states[*]})"
