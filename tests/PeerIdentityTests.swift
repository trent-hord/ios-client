import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// StatusDetails references the tunnel state, which is unrelated to peer list
// identity. This test-only stand-in keeps the standalone runner independent of
// the app and Go SDK; the production PeerInfo implementation is compiled as-is.
enum ClientState: Codable, Equatable {
    case disconnected
}

@main
struct PeerIdentityTests {
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
        key: String = "gateway-key",
        ip: String = "100.64.0.10",
        name: String = "gateway.example.net",
        latency: String = "12ms"
    ) -> PeerInfo {
        PeerInfo(
            ip: ip,
            fqdn: name,
            localIceCandidateEndpoint: "",
            remoteIceCandidateEndpoint: "",
            localIceCandidateType: "",
            remoteIceCandidateType: "",
            pubKey: key,
            latency: latency,
            bytesRx: 0,
            bytesTx: 0,
            connStatus: "Connected",
            connStatusUpdate: "",
            direct: false,
            lastWireguardHandshake: "",
            relayed: false,
            rosenpassEnabled: false,
            routes: ["0.0.0.0/0"]
        )
    }

    private static let cases: [(String, () throws -> Void)] = [
        ("Latency refresh retains list identity and fresh data", {
            let previous = peer(latency: "12ms")
            let incoming = peer(latency: "34ms")
            PeerInfo.preserveListIdentities(in: [incoming], from: [previous])
            try equal(incoming.id, previous.id, "An RTT refresh must not replace the focused row's identity")
            try equal(incoming.latency, "34ms", "Preserving identity must not restore old telemetry")
            try equal(previous.latency, "12ms", "The previous sample is not mutated")
        }),
        ("Stable public key survives address and name changes", {
            let previous = peer(ip: "100.64.0.10", name: "old.example.net", latency: "10ms")
            let incoming = peer(ip: "100.64.0.99", name: "new.example.net", latency: "20ms")
            PeerInfo.preserveListIdentities(in: [incoming], from: [previous])
            try equal(incoming.id, previous.id, "The public key identifies the same node after metadata changes")
            try equal(incoming.ip, "100.64.0.99", "The fresh address is retained")
            try equal(incoming.fqdn, "new.example.net", "The fresh hostname is retained")
            try equal(incoming.latency, "20ms", "Fresh telemetry is retained with the stable identity")
        }),
        ("A new public key at an old address gets a new identity", {
            let previous = peer(key: "old-key")
            let incoming = peer(key: "new-key")
            let incomingID = incoming.id
            PeerInfo.preserveListIdentities(in: [incoming], from: [previous])
            try equal(incoming.id, incomingID, "An address reused by another node must not inherit the old selection")
            try equal(incoming.id == previous.id, false, "Different public keys remain distinct")
        }),
        ("Missing public keys fall back to matching IP addresses", {
            let previous = peer(key: "", name: "old.example.net")
            let incoming = peer(key: "", name: "renamed.example.net", latency: "18ms")
            PeerInfo.preserveListIdentities(in: [incoming], from: [previous])
            try equal(incoming.id, previous.id, "The IP fallback stabilizes older or incomplete SDK records")
            try equal(incoming.fqdn, "renamed.example.net", "The fallback must not keep old display metadata")
            try equal(incoming.latency, "18ms", "The fallback must not keep old measurements")
        }),
        ("Records without identity are not aliased to a previous row", {
            let previous = peer(key: "", ip: "")
            let first = peer(key: "", ip: "")
            let second = peer(key: "", ip: "")
            let firstID = first.id
            let secondID = second.id
            PeerInfo.preserveListIdentities(in: [first, second], from: [previous])
            try equal(first.id, firstID, "Unknown first node retains its own identity")
            try equal(second.id, secondID, "Unknown second node retains its own identity")
            try equal(first.id == previous.id, false, "An unknown node must not inherit a cached row identity")
            try equal(first.id == second.id, false, "Unknown records must not collapse into one row")
        }),
        ("Reordered responses match peers by public key", {
            let previousA = peer(key: "a", ip: "100.64.0.10", name: "a.example.net")
            let previousB = peer(key: "b", ip: "100.64.0.20", name: "b.example.net")
            let incomingB = peer(key: "b", ip: "100.64.0.20", name: "b-new.example.net", latency: "25ms")
            let incomingA = peer(key: "a", ip: "100.64.0.10", name: "a-new.example.net", latency: "15ms")
            PeerInfo.preserveListIdentities(in: [incomingB, incomingA], from: [previousA, previousB])
            try equal(incomingB.id, previousB.id, "The first incoming row belongs to B despite its new index")
            try equal(incomingA.id, previousA.id, "The second incoming row belongs to A despite its new index")
            try equal(incomingB.fqdn, "b-new.example.net", "B keeps its own fresh metadata")
            try equal(incomingA.latency, "15ms", "A keeps its own fresh measurement")
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
        print("Peer identity tests: \(cases.count - failures)/\(cases.count) passed")
        if failures > 0 {
            exit(EXIT_FAILURE)
        }
    }
}
