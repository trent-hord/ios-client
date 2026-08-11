//
//  GlobalConstants.swift
//  NetBird
//
//  Created by Diego Romar on 03/12/25.
//

import Foundation

struct GlobalConstants {
    #if os(tvOS)
    static let userPreferencesSuiteName = "group.io.netbird.app.tv"
    #else
    static let userPreferencesSuiteName = "group.io.netbird.app"
    #endif

    static let keyForceRelayConnection = "isConnectionForceRelayed"
    static let keyLoginRequired = "netbird.loginRequired"
    static let keyNetworkUnavailable = "netbird.networkUnavailable"
    static let keyConnectOnDemand = "netbird.connectOnDemand"
    static let keyTVOnDemandPreferenceVersion = "netbird.tv.onDemandPreferenceVersion"
    static let currentTVOnDemandPreferenceVersion = 1
    static let keyOnDemandWiFiPolicy = "netbird.onDemand.wifiPolicy"
    static let keyOnDemandCellularPolicy = "netbird.onDemand.cellularPolicy"
    static let keyOnDemandWiFiNetworks = "netbird.onDemand.wifiNetworks"
    static let keyKnownSSIDs = "netbird.knownSSIDs"

    // Widget shared state keys
    static let keyWidgetVPNStatus = "netbird.widget.vpnStatus"
    static let keyWidgetIP = "netbird.widget.ip"
    static let keyWidgetFQDN = "netbird.widget.fqdn"
    // Active profile paths stored by the main app so the widget intent can
    // start the tunnel without the main app running (mirrors WidgetConstants).
    static let keyWidgetActiveConfigPath = "netbird.widget.activeConfigPath"
    static let keyWidgetActiveStatePath  = "netbird.widget.activeStatePath"

    /// startVPNTunnel(options:) key. Set by the main app when it has just verified the
    /// login state itself (its own isLoginRequired() check, or a login it just completed),
    /// letting the extension skip its duplicate check — each such check is a full Login RPC
    /// against the management server. Absent for starts the main app did not initiate
    /// (On Demand, widget intent), where the extension must still verify.
    static let optionLoginVerified = "loginVerified"
    static let optionTVConfigJSON = "tvConfigJSON"

    static let configFileName = "netbird.cfg"
    static let stateFileName = "state.json"
    static let serverURLFileName = "netbird_server_url"

    // Local notification identifiers
    static let notificationLoginRequired = "netbird.login.required"
}

/// Persists the user's VPN On Demand choice and handles the one-time tvOS
/// migration from releases that had no user-facing On Demand preference.
struct OnDemandPreferenceStore {
    let defaults: UserDefaults

    func loadTVOSDefaultEnabled() -> Bool {
        let version = defaults.integer(forKey: GlobalConstants.keyTVOnDemandPreferenceVersion)
        if version < GlobalConstants.currentTVOnDemandPreferenceVersion {
            // Older tvOS builds could persist false internally even though users had no
            // toggle. Treat that value as legacy state and adopt the new default once.
            defaults.set(true, forKey: GlobalConstants.keyConnectOnDemand)
            defaults.set(
                GlobalConstants.currentTVOnDemandPreferenceVersion,
                forKey: GlobalConstants.keyTVOnDemandPreferenceVersion
            )
            return true
        }

        guard defaults.object(forKey: GlobalConstants.keyConnectOnDemand) != nil else {
            return true
        }
        return defaults.bool(forKey: GlobalConstants.keyConnectOnDemand)
    }

    func setTVOSExplicitPreference(_ enabled: Bool) {
        defaults.set(enabled, forKey: GlobalConstants.keyConnectOnDemand)
        defaults.set(
            GlobalConstants.currentTVOnDemandPreferenceVersion,
            forKey: GlobalConstants.keyTVOnDemandPreferenceVersion
        )
    }
}
