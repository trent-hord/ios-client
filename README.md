# Trentfinity VPN

<img src="scripts/branding/trentfinity-mark.svg" alt="Trentfinity infinity shield" width="112" />

An independently maintained NetBird client for Apple TV, based on the upstream NetBird Apple app and Go client. This fork brings upstream development into a separately branded app while retaining compatibility with NetBird Cloud and self-hosted NetBird servers. It is not affiliated with or endorsed by NetBird GmbH.

This is a development fork. Building it does not establish App Store eligibility, and Apple distribution and GPL-related release questions remain unresolved.

- [Source branch](https://github.com/trent-hord/ios-client/tree/trentfinity-vpn)
- [Support and issues](https://github.com/trent-hord/ios-client/issues)
- [Fork details, pinned versions, and release preparation](docs/FORK.md)
- [Upstream NetBird documentation](https://docs.netbird.io)

## Build for Apple TV

Use a Mac with **Xcode 26.1.1** selected and Go compatible with [`netbird-core/go.mod`](netbird-core/go.mod). The initial core pin declares Go 1.26.0 and toolchain `go1.26.10`. Live VPN testing requires a physical Apple TV running **tvOS 17 or later**.

```sh
git clone --branch trentfinity-vpn --recurse-submodules \
  https://github.com/trent-hord/ios-client.git trentfinity-vpn
cd trentfinity-vpn
./build-go-lib.sh --tvos
open NetBird.xcodeproj
```

Select the shared **Trentfinity VPN** scheme, configure your own Apple Developer team for the TV app and tunnel extension, and run on your paired Apple TV. The Xcode project and underlying target names retain their upstream names to keep the fork easy to maintain.

| Component | Identifier |
| --- | --- |
| TV app | `com.trentfinity.vpn.tv` |
| TV tunnel extension | `com.trentfinity.vpn.tv.extension` |
| Shared App Group | `group.com.trentfinity.vpn.tv` |

The initial TV app and extension version is **0.1.0**, build **1**. Register compatible identifiers and provisioning profiles under your team; if you change these identifiers, update the app, extension, entitlements, and shared configuration together. See [the build and signing notes](docs/FORK.md#build-and-signing).

## What changed

- Trentfinity VPN name, original infinity-shield artwork, and separate app identity.
- TV Settings → About includes upstream credit, GPLv3 information, and this fork's source/support links.
- Firebase startup is disabled by default through `TrentfinityFirebaseEnabled=false`. Firebase is optional diagnostics/analytics infrastructure, not the VPN or sign-in implementation. This setting is not a claim that the app or connected servers collect no data.
- [Unsigned tvOS CI](.github/workflows/trentfinity-tvos.yml) builds pushes to this branch without App Store credentials. Its output is a build check, not a signed installable release. The inherited publishing jobs are restricted to the upstream repository; Trentfinity publishing is not configured.

## License and attribution

The Apple app retains the upstream [GNU GPLv3 license](LICENSE). Upstream work is by NetBird GmbH and contributors; fork changes are by Trentfinity VPN contributors. The Go core and third-party dependencies retain their respective licenses and notices.

The original upstream README is preserved unchanged in [docs/UPSTREAM_README.md](docs/UPSTREAM_README.md) for reference. Its branding, release links, and configuration instructions describe the upstream project; use this README and [docs/FORK.md](docs/FORK.md) for this fork.
