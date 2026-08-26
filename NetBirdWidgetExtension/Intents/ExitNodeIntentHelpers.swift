import Foundation
import NetworkExtension

/// Minimal decode-only mirror of NetbirdKit's RoutesSelectionDetails — the widget
/// target compiles only its own folder, so the full model isn't visible here.
/// PropertyListDecoder ignores the payload keys not declared (all, append, id,
/// domains, status).
struct WidgetRouteSelectionDetails: Codable {
    var routeSelectionInfo: [WidgetRouteSelectionInfo]
}

struct WidgetRouteSelectionInfo: Codable {
    var name: String
    var network: String?
    var selected: Bool

    // Mirrors RoutesSelectionInfo.isExitNode: a route that covers all traffic
    // (0.0.0.0/0 or ::/0) is an exit node. The core may merge a v4+v6 pair into
    // a single comma-joined range string.
    var isExitNode: Bool {
        guard let network else { return false }
        return network.split(separator: ",").contains { part in
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            return trimmed == "0.0.0.0/0" || trimmed == "::/0"
        }
    }
}

@available(iOS 16.0, *)
enum ExitNodeIntentHelpers {

    /// Reads the network map from the running tunnel and returns only the exit nodes.
    /// Returns nil when the tunnel doesn't answer or the reply can't be decoded — callers
    /// must not confuse a failed read with a genuinely empty list: a nil here proves
    /// nothing about the network state, so success dialogs must never be built on it.
    static func fetchExitNodes(session: NETunnelProviderSession) async -> [WidgetRouteSelectionInfo]? {
        guard let data = await sendMessage("GetRoutes", via: session),
              let details = try? PropertyListDecoder().decode(WidgetRouteSelectionDetails.self, from: data) else {
            return nil
        }
        return details.routeSelectionInfo.filter { $0.isExitNode }
    }

    /// Sends one provider message and returns the reply — nil on failure or after
    /// `WidgetConstants.providerMessageTimeout`. The timeout matters: a hung extension
    /// would otherwise stall the intent until the system kills the whole perform().
    @discardableResult
    static func sendMessage(_ message: String, via session: NETunnelProviderSession) async -> Data? {
        guard let data = message.data(using: .utf8) else { return nil }
        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var resumed = false
            let finish: (Data?) -> Void = { response in
                lock.lock(); defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: response)
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + WidgetConstants.providerMessageTimeout) {
                finish(nil)
            }

            do {
                try session.sendProviderMessage(data) { finish($0) }
            } catch {
                finish(nil)
            }
        }
    }
}
