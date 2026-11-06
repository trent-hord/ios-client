# Trentfinity VPN fork notes

Trentfinity VPN is an independent Apple TV client compatible with NetBird. The initial fork retains upstream networking behavior and adds its own name, artwork, identifiers, project links, and optional-Firebase startup policy. It is not an official NetBird product and does not operate a replacement NetBird management service.

## Source and provenance

Development lives on the [`trentfinity-vpn` branch of `trent-hord/ios-client`](https://github.com/trent-hord/ios-client/tree/trentfinity-vpn). [Report fork issues here](https://github.com/trent-hord/ios-client/issues). These are the initial upstream pins, not a promise to track a moving branch automatically:

| Component | Initial pin |
| --- | --- |
| NetBird Apple client | [`14f139df5cea1d373b3c512103f0b862b3d2385b`](https://github.com/netbirdio/ios-client/commit/14f139df5cea1d373b3c512103f0b862b3d2385b) |
| `netbird-core` submodule | [`772d0b86f8662f898c6d434b24c25bd7893dbddc`](https://github.com/netbirdio/netbird/commit/772d0b86f8662f898c6d434b24c25bd7893dbddc) |
| tvOS gomobile fork | [`v0.0.0-20260129172842-a56582c0e7c9`](https://github.com/netbirdio/gomobile-tvos-fork/commit/a56582c0e7c97feda06c4f8a74995129e6b3f89a) |

The unchanged [upstream README snapshot](UPSTREAM_README.md) comes from the Apple-client pin above. Its Git blob is `80549d04f60bfb249262fd38ecbb2d5257d2ea32`. Follow this fork's instructions for signing, Firebase, support, and releases.

Keep the submodule at a deliberate commit when updating upstream. Recheck dependencies, native support code, and bundled notices for each release; the top-level app license does not replace component licenses.

## Build and signing

1. Use macOS with **Xcode 26.1.1** selected as the active developer directory. Confirm with `xcodebuild -version`.
2. Install Go using the version/toolchain declared in `netbird-core/go.mod`. The initial pin declares `go 1.26.0` and `toolchain go1.26.10`; allow Go's normal toolchain selection to use that pin.
3. Clone this branch with submodules, or run `git submodule update --init --recursive` after cloning.
4. Run `./build-go-lib.sh --tvos` from the repository root. It installs the pinned gomobile tools as needed and builds `NetBirdSDK.xcframework` for iOS and tvOS device/simulator targets. Do not substitute an unpinned `gomobile@latest` command for this script.
5. Open `NetBird.xcodeproj` and choose the shared **Trentfinity VPN** scheme. The scheme builds the TV app and its tunnel extension; underlying target names remain `NetBird TV` and `NetBirdTVNetworkExtension`.
6. Select **your own** signing team for both targets. Configure their registered identifiers, App Group, Network Extension capability, and matching provisioning profiles. No upstream signing identity or certificate is supplied.
7. Pair a physical Apple TV running **tvOS 17+** with Xcode and use it as the run destination. Simulator compilation cannot validate a live VPN tunnel, routing, or connection recovery.

The initial fork identifiers are:

| Setting | Value |
| --- | --- |
| TV display name and scheme | `Trentfinity VPN` |
| TV app bundle identifier | `com.trentfinity.vpn.tv` |
| TV tunnel extension bundle identifier | `com.trentfinity.vpn.tv.extension` |
| TV App Group | `group.com.trentfinity.vpn.tv` |
| TV app and extension marketing version / build | `0.1.0` / `1` |

If an identifier is unavailable to your team, choose your own and update the Xcode build settings, both targets' entitlements, and shared runtime constants consistently. Changing only the app's bundle identifier is insufficient for extension and shared-storage access. Separate identifiers also mean this app does not take over the official NetBird app's settings or VPN configuration.

## Continuous integration

The [`trentfinity-tvos.yml` workflow](../.github/workflows/trentfinity-tvos.yml) builds this fork on pushes to `trentfinity-vpn` using the shared scheme and unsigned settings. It does not require Apple signing secrets, upload to App Store Connect, or produce a distributable signed app. A successful run confirms the build covered by the workflow; it does not prove live VPN behavior, privacy compliance, or Apple approval. Check the actual workflow result before describing a revision as build-verified.

Inherited release, TestFlight, scratch-build, and version-bump entry jobs are gated to `github.repository == 'netbirdio/ios-client'`. Their upstream signing setup is not a Trentfinity publishing pipeline. Use the new unsigned workflow for this fork; signed release automation is intentionally not configured.

## Routing-node details

The main TV screen shows the installed routing peer underneath the exit-node choice: hostname/IP, address family, P2P or Relayed, and the core's measured round-trip latency in milliseconds. The exit-node choice names a route group; its physical routing peer can change during failover. IPv4 and IPv6 can use different peers, so both are shown when reported.

These values come from the latest core status sample, refreshed every ten seconds. Changes can take until the next sample to appear. No exit node selected means there is no single internet gateway to summarize; individual mesh connections remain available under Peers. Disconnecting or switching profiles hides the previous tunnel's measurements.

Zero or absent RTT is displayed as **Unavailable**. Some relay transports do not provide an RTT; a positive measurement from a TURN-backed path is retained. No additional network probes are started for this display.

`tests/ExitNodeConnectionTests.swift` checks routing-peer selection, failover updates, separate IPv4/IPv6 nodes, transport labels, and Go duration conversion. The tvOS CI workflow runs it with the native Swift compiler before building the app.

## Firebase is optional

Firebase is disabled by default: the app's Info.plist setting `TrentfinityFirebaseEnabled` is **false**, and startup additionally checks for a valid configuration matching the app's bundle identifier. Unit-test runs skip Firebase initialization. The fork removes the required `GoogleService-Info.plist` resource references and automatic Crashlytics symbol-upload build scripts.

The Firebase SDK dependencies remain in the Xcode project. The tvOS app links Analytics and Crashlytics for optional usage analytics and crash reporting. The inherited iOS targets also contain Performance and App Check packages. Firebase is **not** the NetBird VPN engine, NetBird management server, or the sign-in implementation; turning it off does not disable the VPN or NetBird authentication.

To opt into Firebase for a private build:

1. Register the appropriate app in **your own** Firebase project using its actual bundle identifier.
2. Download its matching `GoogleService-Info.plist`, add it to the intended app target, and include it in that target's Copy Bundle Resources. Do not reuse NetBird's configuration or a CI placeholder.
3. Change `TrentfinityFirebaseEnabled` to **true** for that app target's Info.plist configuration. A missing, malformed, or mismatched configuration still prevents initialization.
4. Configure any desired Crashlytics symbol upload explicitly for your project; the fork does not install an upload script automatically.
5. Review data collection and disclosures for the resulting build before sharing it. When enabled, the existing crash-report path can attach Go panic output to Crashlytics.

The default means Firebase startup is off; it is not a no-logging or no-data-collection guarantee. NetBird servers, identity providers, local diagnostics, and other dependencies have their own behavior. This repository does not yet supply a reviewed release privacy policy.

## Branding and licenses

The fork uses original Trentfinity infinity-shield artwork. Its vector source, preview, and asset manifest are in [`scripts/branding`](../scripts/branding); the TV UI also draws the mark with SwiftUI. NetBird names remain where they identify the protocol implementation, cloud service, server configuration, documentation, or upstream attribution. They are not presented as endorsement.

The Apple app remains under the [upstream GNU GPLv3 license](../LICENSE); this fork does not relicense that code. Existing copyrights and contributor credit are retained, and changed source files identify fork modifications. When distributing builds, preserve applicable notices and provide the corresponding source and other materials the relevant licenses require. An in-app link or a public repository alone does not resolve every distribution obligation.

The Go core, generated binding support, and other dependencies retain their own licenses, including any directory-specific or native-code terms. A new UI or name does not remove obligations from reused GPL-covered app and extension code.

## Before a public release

Apple distribution remains an unresolved release step. The existence of an upstream App Store app or an aging upstream release does not establish permission to distribute this fork or guarantee review approval.

- Resolve the compatibility of the proposed App Store distribution terms with the GPL-covered code and all other bundled licenses, including any permissions needed for that distribution.
- Plan for Apple Developer **organization** enrollment under [App Review guideline 5.4](https://developer.apple.com/app-store/review/guidelines/#vpn-apps), unless Apple confirms a different interpretation for this specific app.
- Review the app's distinct user-facing value under [guidelines 4.1 and 4.2](https://developer.apple.com/app-store/review/guidelines/#design), with accurate upstream attribution and independent branding.
- Prepare a reviewed privacy policy, in-app VPN data disclosures, App Store privacy answers, encryption/export information, and any territory-specific requirements for the actual build.
- Test on physical hardware, including authentication, reconnects, private-resource access, DNS, routing, exit nodes, and upgrade behavior; provide usable review access to Apple.
- Sign with the publisher's own team and complete beta/release review before claiming a supported public release.

These notes describe the work still required; they do not claim legal clearance, release approval, or completed device testing.
