#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

SNAPSHOT_RUNTIME="26.5"

if ! xcrun simctl list runtimes | grep -q "iOS ${SNAPSHOT_RUNTIME}"; then
  echo "error: iOS ${SNAPSHOT_RUNTIME} simulator runtime not installed — snapshot references are pinned to iOS ${SNAPSHOT_RUNTIME}. Install it via Xcode > Settings > Platforms and re-run." >&2
  exit 1
fi

export TZ="America/New_York"

devices=("qbremote-VisualTests-17Pro" "qbremote-VisualTests-iPadPro13")
device_types=(
  "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
  "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-16GB"
)
runtime_id="com.apple.CoreSimulator.SimRuntime.iOS-26-5"

available_devices="$(xcrun simctl list devices available)"
for index in "${!devices[@]}"; do
  if ! grep -Fq "${devices[$index]} (" <<<"${available_devices}"; then
    xcrun simctl create "${devices[$index]}" "${device_types[$index]}" "${runtime_id}"
  fi
done

trap 'echo "On failure, diff artifacts (if collected) land under: ~/Library/Developer/CoreSimulator/Devices/*/tmp/*SnapshotTests*/*.png" >&2' ERR

set -o pipefail
for device in "${devices[@]}"; do
  echo "Running snapshot tests on ${device}..."
  if command -v xcbeautify >/dev/null 2>&1; then
    xcodebuild test \
      -project qbremote.xcodeproj \
      -scheme qbremoteSnapshotTests \
      -destination "platform=iOS Simulator,name=${device},OS=${SNAPSHOT_RUNTIME}" \
      | xcbeautify
  else
    xcodebuild test \
      -project qbremote.xcodeproj \
      -scheme qbremoteSnapshotTests \
      -destination "platform=iOS Simulator,name=${device},OS=${SNAPSHOT_RUNTIME}"
  fi
done
