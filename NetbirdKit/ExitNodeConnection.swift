// Added for Trentfinity VPN on 2026-11-06.
// Presentation of the routing peers reported by the latest core status sample.

import Foundation

struct ExitNodePeerSnapshot: Equatable {
    let key: String
    let hostname: String
    let ip: String
    let connectionStatus: String
    let relayed: Bool
    let latency: String
    let routes: [String]
}

struct ExitNodeConnectionDetails: Equatable {
    enum State: Equatable {
        case disconnected, noExitNode, waiting, active
    }

    struct Peer: Identifiable, Equatable {
        let id: String
        let name: String
        let address: String
        let connectionType: String
        let latencyText: String
        let addressFamilies: String
    }

    let state: State
    let peers: [Peer]

    init(isConnected: Bool, selectedNetwork: String?, peers snapshots: [ExitNodePeerSnapshot]) {
        guard isConnected else {
            state = .disconnected
            peers = []
            return
        }

        let defaultPrefixes: Set<String> = ["0.0.0.0/0", "::/0"]
        let selectedPrefixes = Self.prefixes(in: [selectedNetwork ?? ""]).intersection(defaultPrefixes)
        guard !selectedPrefixes.isEmpty else {
            state = .noExitNode
            peers = []
            return
        }

        // Peer routes are the installed allowed-IP routes, not all advertised
        // routes. They follow the core's chosen routing peer through HA failover.
        // A selector name is a route-group NetID, so it must never be matched to
        // a hostname or used to choose an arbitrary connected peer.
        var installed: [String: (snapshot: ExitNodePeerSnapshot, prefixes: Set<String>)] = [:]
        for snapshot in snapshots where snapshot.connectionStatus == "Connected" {
            let matching = Self.prefixes(in: snapshot.routes).intersection(selectedPrefixes)
            guard !matching.isEmpty else { continue }
            let key = snapshot.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let identity = key.isEmpty ? "\(snapshot.ip)|\(snapshot.hostname)" : key
            if var previous = installed[identity] {
                previous.prefixes.formUnion(matching)
                installed[identity] = previous
            } else {
                installed[identity] = (snapshot, matching)
            }
        }

        peers = installed.map { identity, entry in
            let peer = entry.snapshot
            let hostname = peer.hostname.trimmingCharacters(in: .whitespacesAndNewlines)
            let address = peer.ip.trimmingCharacters(in: .whitespacesAndNewlines)
            let families = [
                entry.prefixes.contains("0.0.0.0/0") ? "IPv4" : nil,
                entry.prefixes.contains("::/0") ? "IPv6" : nil
            ].compactMap { $0 }.joined(separator: " + ")

            return Peer(
                id: identity,
                name: hostname.isEmpty ? (address.isEmpty ? "Unknown node" : address) : hostname,
                address: address,
                // The current SDK leaves `direct` false even for P2P links.
                // Its relayed flag is authoritative for a connected peer.
                connectionType: peer.relayed ? "Relayed" : "P2P",
                latencyText: Self.formatLatency(peer.latency),
                addressFamilies: families
            )
        }.sorted { lhs, rhs in
            if lhs.name != rhs.name { return lhs.name < rhs.name }
            return lhs.id < rhs.id
        }
        state = peers.isEmpty ? .waiting : .active
    }

    private static func prefixes(in routes: [String]) -> Set<String> {
        Set(routes.flatMap { $0.split(separator: ",") }.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        })
    }

    private static func formatLatency(_ raw: String) -> String {
        // Go's time.Duration string includes its units and can be compound, e.g.
        // "1m2.5s". Zero is an unmeasured RTT; relayed ICE/TURN links can still
        // report a legitimate positive sample, so do not hide those samples.
        let duration = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !duration.isEmpty,
              let pattern = try? NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)(ns|us|µs|μs|ms|s|m|h)"#) else {
            return "Unavailable"
        }
        let text = duration as NSString
        let matches = pattern.matches(in: duration, range: NSRange(location: 0, length: text.length))
        let millisecondsPerUnit: [String: Double] = [
            "ns": 0.000001, "us": 0.001, "µs": 0.001, "μs": 0.001,
            "ms": 1, "s": 1_000, "m": 60_000, "h": 3_600_000
        ]
        var nextLocation = 0
        var milliseconds = 0.0
        for match in matches {
            guard match.range.location == nextLocation,
                  let amount = Double(text.substring(with: match.range(at: 1))),
                  let multiplier = millisecondsPerUnit[text.substring(with: match.range(at: 2))] else {
                return "Unavailable"
            }
            milliseconds += amount * multiplier
            nextLocation = NSMaxRange(match.range)
        }
        guard nextLocation == text.length, milliseconds.isFinite, milliseconds > 0 else {
            return "Unavailable"
        }
        guard milliseconds >= 1 else { return "<1 ms" }
        let value = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), milliseconds)
        return (value.hasSuffix(".0") ? String(value.dropLast(2)) : value) + " ms"
    }
}
