import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// A standalone Foundation test runner so the route-to-peer rules can be checked
// without booting the app, creating a tunnel, or requiring Apple signing.
@main
struct ExitNodeConnectionTests {
    private struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    private static func equal<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        guard actual == expected else {
            throw Failure(description: "\(file):\(line): \(context): expected \(expected), received \(actual)")
        }
    }

    private static func peer(
        key: String = "peer-a",
        hostname: String = "gateway-a.example.net",
        ip: String = "100.64.0.10",
        status: String = "Connected",
        relayed: Bool = false,
        latency: String = "12.4ms",
        routes: [String] = ["0.0.0.0/0"]
    ) -> ExitNodePeerSnapshot {
        ExitNodePeerSnapshot(
            key: key,
            hostname: hostname,
            ip: ip,
            connectionStatus: status,
            relayed: relayed,
            latency: latency,
            routes: routes
        )
    }

    private static func details(
        connected: Bool = true,
        network: String? = "0.0.0.0/0",
        peers: [ExitNodePeerSnapshot]
    ) -> ExitNodeConnectionDetails {
        ExitNodeConnectionDetails(isConnected: connected, selectedNetwork: network, peers: peers)
    }

    private static let cases: [(String, () throws -> Void)] = [
        ("Only the peer carrying the exit prefix is shown", {
            let result = details(peers: [
                peer(key: "unrelated", hostname: "other.example.net", routes: ["10.0.0.0/8"]),
                peer()
            ])
            try equal(result.state, .active, "A connected routing peer activates the details")
            try equal(result.peers.count, 1, "Unrelated connected mesh peers are excluded")
            try equal(result.peers[0].name, "gateway-a.example.net", "The actual routing peer supplies the name")
            try equal(result.peers[0].address, "100.64.0.10", "The routing peer's overlay address is retained")
            try equal(result.peers[0].connectionType, "P2P", "A non-relayed connected path is P2P")
            try equal(result.peers[0].latencyText, "12.4 ms", "The core's RTT is formatted for display")
            try equal(result.peers[0].addressFamilies, "IPv4", "The active prefix identifies its address family")
        }),
        ("Cached peers do not imply an active disconnected tunnel", {
            let result = details(connected: false, peers: [peer()])
            try equal(result.state, .disconnected, "Tunnel state overrides a cached connected peer")
            try equal(result.peers.count, 0, "Disconnected state has no live node measurements")
        }),
        ("No selected exit node does not pick an arbitrary peer", {
            let result = details(network: nil, peers: [peer()])
            try equal(result.state, .noExitNode, "Mesh connections alone do not imply a selected exit node")
            try equal(result.peers.count, 0, "No peer is substituted for an absent exit selection")
        }),
        ("Pending exit node reports waiting", {
            let result = details(peers: [])
            try equal(result.state, .waiting, "A selection without an installed routing peer is pending")
            try equal(result.peers.count, 0, "Pending details contain no invented peer")
        }),
        ("Inactive routing peers cannot supply live metrics", {
            let result = details(peers: [
                peer(key: "idle", status: "Idle"),
                peer(key: "connecting", status: "Connecting"),
                peer(key: "disconnected", status: "Disconnected")
            ])
            try equal(result.state, .waiting, "The routing peer itself must be connected")
            try equal(result.peers.count, 0, "Stale RTT and path information is hidden")
        }),
        ("Exit prefixes match exactly", {
            let result = details(peers: [
                peer(routes: ["10.0.0.0/0", "0.0.0.0/00", "0.0.0.0/1", "::/0"])
            ])
            try equal(result.state, .waiting, "A similar prefix or unselected address family is not a match")
            try equal(result.peers.count, 0, "No substring match can invent an active exit peer")
        }),
        ("An IPv6-only selection identifies the IPv6 routing peer", {
            let result = details(network: "::/0", peers: [
                peer(key: "ipv4", routes: ["0.0.0.0/0"]),
                peer(key: "ipv6", hostname: "gateway-v6.example.net", routes: ["::/0"])
            ])
            try equal(result.peers.count, 1, "Only the selected address family is included")
            try equal(result.peers[0].name, "gateway-v6.example.net", "The IPv6 gateway is identified")
            try equal(result.peers[0].addressFamilies, "IPv6", "The IPv6 family is visible")
        }),
        ("IPv4 and IPv6 can use different routing peers", {
            let result = details(network: "0.0.0.0/0, ::/0", peers: [
                peer(key: "v4", ip: "100.64.0.10", routes: ["0.0.0.0/0"]),
                peer(key: "v6", ip: "100.64.0.20", routes: ["::/0"])
            ])
            try equal(result.state, .active, "Both connected route owners are active")
            try equal(result.peers.count, 2, "Distinct gateways must not be collapsed into one")
            try equal(result.peers.first { $0.address == "100.64.0.10" }?.addressFamilies, "IPv4", "IPv4 ownership is retained")
            try equal(result.peers.first { $0.address == "100.64.0.20" }?.addressFamilies, "IPv6", "IPv6 ownership is retained")
        }),
        ("One dual-stack peer is shown once with both families", {
            let result = details(network: " 0.0.0.0/0 , ::/0 ", peers: [
                peer(routes: ["0.0.0.0/0", "::/0"])
            ])
            try equal(result.peers.count, 1, "A dual-stack gateway is a single node")
            try equal(result.peers[0].addressFamilies, "IPv4 + IPv6", "Both active address families are shown")
        }),
        ("Repeated public keys do not duplicate the node", {
            let result = details(peers: [peer(), peer()])
            try equal(result.peers.count, 1, "Duplicate status entries for one public key collapse")
        }),
        ("Duplicate node entries retain both installed address families", {
            let result = details(network: "0.0.0.0/0, ::/0", peers: [
                peer(routes: ["0.0.0.0/0"]),
                peer(routes: ["::/0"])
            ])
            try equal(result.peers.count, 1, "One public key identifies one node across route entries")
            try equal(result.peers[0].addressFamilies, "IPv4 + IPv6", "Deduplication does not discard the other family")
        }),
        ("Different route owners are not chosen arbitrarily", {
            let result = details(peers: [
                peer(key: "a", hostname: "a.example.net", ip: "100.64.0.10"),
                peer(key: "b", hostname: "b.example.net", ip: "100.64.0.20")
            ])
            try equal(result.peers.count, 2, "Two reported active owners remain explicit during overlap or transition")
        }),
        ("A relay path can have a measured ICE RTT", {
            let result = details(peers: [peer(relayed: true, latency: "24.6ms")])
            try equal(result.peers.count, 1, "The relay node remains visible")
            try equal(result.peers[0].connectionType, "Relayed", "Relay status comes from the core")
            try equal(result.peers[0].latencyText, "24.6 ms", "A valid TURN-backed ICE measurement is preserved")
        }),
        ("Hostname falls back to the overlay address", {
            let result = details(peers: [peer(hostname: "")])
            try equal(result.peers.count, 1, "A gateway without DNS metadata is still shown")
            try equal(result.peers[0].name, "100.64.0.10", "An empty hostname falls back to the IP")
        }),
        ("Missing hostname and address use an explicit unknown name", {
            let result = details(peers: [peer(hostname: " ", ip: "")])
            try equal(result.peers.count, 1, "Known route ownership still identifies a node without display metadata")
            try equal(result.peers[0].name, "Unknown node", "No hostname or IP is fabricated")
        }),
        ("Latency-only changes are observable in a new snapshot", {
            try equal(peer(latency: "12ms") == peer(latency: "13ms"), false, "Polling must publish a changed RTT without a connection-state change")
            try equal(peer(latency: "12ms") == peer(latency: "12ms"), true, "An identical sample does not force a redundant refresh")
        }),
        ("Route content changes matter even when route count is unchanged", {
            let before = peer(routes: ["0.0.0.0/0"])
            let after = peer(routes: ["10.0.0.0/8"])
            try equal(before.routes.count, after.routes.count, "This regression case holds the route count constant")
            try equal(before == after, false, "A removed exit prefix must refresh node details")
            try equal(details(peers: [before]).state, .active, "The old sample owned the exit route")
            try equal(details(peers: [after]).state, .waiting, "The new sample no longer owns that route")
        }),
        ("Changed peer identity and name are observable", {
            try equal(peer(key: "old-key") == peer(key: "new-key"), false, "Replacing a node at the same address must refresh its identity")
            try equal(peer(hostname: "old.example.net") == peer(hostname: "new.example.net"), false, "Renaming a node must refresh its display name")
        }),
        ("Missing, zero, negative, and malformed RTT are unavailable", {
            for value in ["", " ", "0", "0s", "0ms", "0.0ms", "-1ms", "NaNms", "Infinitys", "unknown", "12", "12sec", "1.2.3ms", "1ms garbage"] {
                let result = details(peers: [peer(latency: value)])
                try equal(result.peers.count, 1, "An unavailable RTT does not hide the gateway")
                try equal(result.peers[0].latencyText, "Unavailable", "Invalid or missing RTT '\(value)' must not be presented as zero latency")
            }
        }),
        ("Go duration units are converted to milliseconds", {
            for (value, expected) in [
                ("12ms", "12 ms"),
                ("12.41ms", "12.4 ms"),
                ("1s", "1000 ms"),
                ("1.234s", "1234 ms"),
                ("1m2.3s", "62300 ms"),
                ("250µs", "<1 ms"),
                ("500ns", "<1 ms")
            ] {
                let result = details(peers: [peer(latency: value)])
                try equal(result.peers.count, 1, "The gateway remains present for duration \(value)")
                try equal(result.peers[0].latencyText, expected, "Duration \(value) retains the correct scale")
            }
        })
    ]

    static func main() {
        var failures = 0
        for (name, run) in cases {
            do {
                try run()
                print("PASS: \(name)")
            } catch {
                failures += 1
                print("FAIL: \(name)\n  \(error)")
            }
        }
        print("Exit node connection tests: \(cases.count - failures)/\(cases.count) passed")
        if failures > 0 {
            exit(EXIT_FAILURE)
        }
    }
}
