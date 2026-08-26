import Foundation

enum WidgetConstants {
    static let appGroupSuite = "group.io.netbird.app"
    static let deepLinkConnect = URL(string: "netbird://connect")
    static let deepLinkDisconnect = URL(string: "netbird://disconnect")
    static let deepLinkLogin = URL(string: "netbird://login")

    // UserDefaults keys (must match GlobalConstants in NetbirdKit)
    static let keyVPNStatus = "netbird.widget.vpnStatus"
    static let keyIP = "netbird.widget.ip"
    static let keyFQDN = "netbird.widget.fqdn"
    static let keyLoginRequired = "netbird.loginRequired"
    // Active profile paths written by the main app so the widget intent can pass
    // them to startVPNTunnel(options:) without the main app being in-process.
    static let keyActiveConfigPath = "netbird.widget.activeConfigPath"
    static let keyActiveStatePath  = "netbird.widget.activeStatePath"
    // Exit node names cached by the main app on every successful route read, so the
    // Shortcuts exit-node picker can offer suggestions while the VPN is down.
    static let keyExitNodes = "netbird.widget.exitNodes"

    static let pollInterval: TimeInterval = 0.3
    static let pollTimeout: TimeInterval = 5.0
    // Cap on a single provider-message round-trip from an intent, so a hung
    // extension can't stall perform() until the system kills it.
    static let providerMessageTimeout: TimeInterval = 5.0
    static let timelineRefreshMinutes = 5
    // Short refresh used when NE was mid-transition at load time so the widget
    // recovers to the correct stable state as soon as NE settles.
    static let transitionPollInterval: TimeInterval = 5.0

}
