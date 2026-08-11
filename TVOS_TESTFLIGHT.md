# Building and Uploading NetBird tvOS to TestFlight

This guide covers two release paths:

1. A private TestFlight build signed by a personal Apple Developer team, used to test a feature branch before opening an upstream pull request.
2. NetBird's upstream TestFlight workflow, used after the change is ready for review.

The private build must use its own App Store Connect app, bundle identifiers, and app group. Do not attach it to an unrelated app such as TrackThatWorkout, and do not commit personal signing identifiers to a NetBird pull request.

## Prerequisites

- A Mac with the full Xcode application selected.
- An Apple Developer Program membership with access to App Store Connect.
- A physical Apple TV running tvOS 17 or later. The VPN cannot be tested in the tvOS simulator.
- Go at the version declared by `netbird-core/go.mod`.
- The repository submodules.
- A unique marketing version and build number. The app and embedded extension must use the same values.

Select Xcode and initialize the repository:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
git submodule update --init --recursive
```

If Xcode reports that the tvOS platform is missing, install it in **Xcode > Settings > Components**, or run:

```bash
xcodebuild -downloadPlatform tvOS
```

## Build the NetBird Go framework

The upstream tvOS workflow currently uses this pinned gomobile fork revision:

```bash
TVOS_GOMOBILE_VERSION=v0.0.0-20260129172842-a56582c0e7c9
GOPROXY=direct go install github.com/netbirdio/gomobile-tvos-fork/cmd/gomobile-netbird@${TVOS_GOMOBILE_VERSION}
GOPROXY=direct go install github.com/netbirdio/gomobile-tvos-fork/cmd/gobind-netbird@${TVOS_GOMOBILE_VERSION}
./build-go-lib.sh --tvos
```

`build-go-lib.sh --tvos` currently runs `go get ...@latest` inside the `netbird-core` submodule. Build from a disposable worktree or confirm afterward that `netbird-core/go.mod` and `netbird-core/go.sum` did not change. A release should use the same pinned fork revision as CI rather than silently accepting a newer `latest` revision.

The result is `NetBirdSDK.xcframework` at the repository root.

## Validate the branch without signing

Use isolated package and Derived Data directories when possible. This avoids failures caused by stale SwiftPM artifact caches.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

xcodebuild build \
  -project NetBird.xcodeproj \
  -scheme "NetBird TV" \
  -configuration Release \
  -destination 'generic/platform=tvOS' \
  -clonedSourcePackagesDirPath /tmp/netbird-tvos-packages \
  -derivedDataPath /tmp/netbird-tvos-derived-data \
  CODE_SIGNING_ALLOWED=NO
```

Before packaging, also run:

```bash
git diff --check
```

Warnings that the app and extension have different versions must be fixed before upload. Pass both values on the archive command so they are applied to every target.

## Private TestFlight setup

Use dedicated identifiers so the test build can coexist with the production NetBird app and does not affect another product's App Store record.

| Resource | Personal test value |
| --- | --- |
| tvOS app ID | `cloud.hord.netbird.tv` |
| packet-tunnel extension ID | `cloud.hord.netbird.tv.extension` |
| app group | `group.cloud.hord.netbird.tv` |

In Certificates, Identifiers & Profiles:

1. Create explicit App IDs for the app and extension.
2. Enable **Network Extensions** with `packet-tunnel-provider` for both IDs.
3. Create the app group and assign it to both IDs.
4. Allow Xcode to regenerate the tvOS development and App Store provisioning profiles after the capabilities are enabled.

In App Store Connect, create a new tvOS app using `cloud.hord.netbird.tv`. Do not add NetBird as a platform under the TrackThatWorkout record; that would combine unrelated products under one App Store identity.

### Keep personal signing changes isolated

Create a disposable worktree or local-only packaging copy. In that copy, update only the tvOS signing inputs:

- The `NetBird TV` target bundle identifier and development team.
- The `NetBirdTVNetworkExtension` bundle identifier and development team.
- The app group in both tvOS entitlement files.
- `GlobalConstants.userPreferencesSuiteName` for tvOS.
- `NetworkExtensionAdapter.extensionID` for tvOS.
- A valid Firebase plist whose `BUNDLE_ID` matches the personal app, or an
  explicitly disabled placeholder containing only
  `NETBIRD_FIREBASE_DISABLED = true`.

Do not replace iOS, widget, test-target, or production identifiers. Do not commit the personal values to the feature branch.

Never package `GOOGLE_APP_ID = dummy`. Firebase treats that as an invalid app
identifier and terminates tvOS before the first screen appears. If analytics and
crash reporting are not needed for a private build, use this build-only plist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NETBIRD_FIREBASE_DISABLED</key><true/>
</dict>
</plist>
```

## Archive

In Xcode, select the `NetBird TV` scheme and **Any tvOS Device**, then choose **Product > Archive**. Automatic signing should use the personal team.

The equivalent command is:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

xcodebuild archive \
  -project NetBird.xcodeproj \
  -scheme "NetBird TV" \
  -configuration Release \
  -destination 'generic/platform=tvOS' \
  -archivePath /tmp/NetBirdTV.xcarchive \
  -allowProvisioningUpdates \
  MARKETING_VERSION=0.1.6 \
  CURRENT_PROJECT_VERSION=101
```

Increase `CURRENT_PROJECT_VERSION` for every upload. App Store Connect rejects a reused build number.

## Verify the archive before uploading

First verify identifiers and versions:

```bash
APP=/tmp/NetBirdTV.xcarchive/Products/Applications/NetBird\ TV.app
EXTENSION="$APP/PlugIns/NetBirdTVNetworkExtension.appex"

/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$EXTENSION/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$EXTENSION/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$EXTENSION/Info.plist"
```

Then inspect both signatures:

```bash
codesign -d --entitlements :- "$APP"
codesign -d --entitlements :- "$EXTENSION"
```

Both must contain:

```text
com.apple.developer.networking.networkextension = [packet-tunnel-provider]
com.apple.security.application-groups = [group.cloud.hord.netbird.tv]
```

Stop if either entitlement is absent. An archive can upload successfully but the VPN tunnel and shared configuration will not work.

## Upload to personal TestFlight

The simplest path uses Xcode's cloud-managed distribution certificate:

1. Open **Window > Organizer > Archives**.
2. Select the NetBird tvOS archive.
3. Choose **Distribute App**.
4. Choose **TestFlight Internal Only** or **App Store Connect > Upload**.
5. Keep automatic signing enabled and complete validation.
6. Upload, wait for App Store Connect processing, and add the Apple ID under **TestFlight > Internal Testing**.

For a command-line upload, create `/tmp/ExportOptions-tvos.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>3F53ZKRU6Q</string>
  <key>testFlightInternalTestingOnly</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
```

Upload it:

```bash
xcodebuild -exportArchive \
  -archivePath /tmp/NetBirdTV.xcarchive \
  -exportOptionsPlist /tmp/ExportOptions-tvos.plist \
  -exportPath /tmp/netbird-tvos-upload \
  -allowProvisioningUpdates
```

Never store certificates, private keys, App Store Connect API keys, provisioning profiles, or export credentials in the repository.

## Device test checklist

Test on a physical Apple TV:

1. Fresh install: sign in and confirm VPN On Demand defaults to enabled.
2. Reboot: confirm NetBird reconnects without opening the app.
3. Opt out: disable On Demand, reboot, and confirm it remains disabled.
4. Manual disconnect: confirm the app explains that On Demand must be disabled to remain disconnected.
5. Server change and logout: confirm the old tunnel and credentials are not reused.
6. PSK and Rosenpass changes: confirm the tunnel restarts with the new configuration.
7. Expired or revoked authentication: confirm the OS does not enter a repeated reconnect/failure loop.
8. Offline launch and foregrounding: confirm the UI remains responsive.

Only move the feature to an upstream pull request after these device checks pass.

## Upstream NetBird TestFlight

The upstream workflow is intentionally maintainer-gated. After opening a pull request against `netbirdio/ios-client`, a maintainer with write access can comment:

```text
/testflight
```

The current gate builds and uploads both iOS and tvOS. Omitting a hard-coded build number lets the workflow query App Store Connect for the next build. A fork without NetBird's signing secrets cannot run the upstream upload independently.

## Troubleshooting

- **The tvOS SDK is missing:** install the platform in Xcode Settings or run `xcodebuild -downloadPlatform tvOS`.
- **SwiftPM reports an artifact already exists:** use new `-clonedSourcePackagesDirPath` and `-derivedDataPath` directories instead of deleting a shared cache.
- **The extension version differs from the app:** pass the same `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` to the archive command.
- **Automatic signing removes VPN entitlements:** enable Network Extensions and App Groups on both App IDs, regenerate profiles, archive again, and repeat the entitlement check.
- **App Store Connect cannot find the app:** create the tvOS app record with the exact host bundle ID before uploading.
- **On Demand disables another VPN:** tvOS permits only one active On Demand VPN configuration; disable the other VPN profile while testing.
