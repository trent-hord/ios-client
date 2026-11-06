#!/bin/bash
# Capture the real disconnected app on a clean Apple TV simulator.
# Requires macOS, Xcode, and the SDK produced by build-go-lib.sh --tvos.
set -euo pipefail

preview_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
screenshots="$preview_root/TrentfinityScreenshots"
derived_data="$preview_root/TrentfinityDerivedData"
mkdir -p "$screenshots"

select_tv() {
  xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    if "tvOS" not in runtime:
        continue
    for device in devices[runtime]:
        if device.get("isAvailable") and "Apple TV" in device["name"]:
            print(device["udid"])
            sys.exit(0)
sys.exit(1)
'
}

if ! simulator_id=$(select_tv); then
  xcodebuild -downloadPlatform tvOS
  simulator_id=$(select_tv)
fi

xcrun simctl bootstatus "$simulator_id" -b

xcodebuild build \
  -project NetBird.xcodeproj \
  -scheme "Trentfinity VPN" \
  -sdk appletvsimulator \
  -destination "id=$simulator_id" \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES

app="$derived_data/Build/Products/Release-appletvsimulator/NetBird TV.app"
xcrun simctl install "$simulator_id" "$app"
xcrun simctl launch --terminate-running-process "$simulator_id" com.trentfinity.vpn.tv

# Allow startup loading and the first SwiftUI render to settle. No login,
# fake connection data, or network-extension session is used for this preview.
sleep 15
xcrun simctl io "$simulator_id" screenshot "$screenshots/connection.png"
printf 'Native simulator captures from commit %s\nDisconnected state; no VPN session.\n' \
  "$(git rev-parse HEAD)" > "$screenshots/README.txt"
