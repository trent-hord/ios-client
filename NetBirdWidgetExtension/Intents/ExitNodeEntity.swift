import AppIntents
import NetworkExtension

@available(iOS 16.0, *)
struct ExitNodeEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Exit Node")
    static var defaultQuery = ExitNodeEntityQuery()

    /// The route identifier from the core network map — the same string the app's
    /// exit node selector displays and Select-/Deselect- messages address.
    var id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

@available(iOS 16.0, *)
struct ExitNodeEntityQuery: EntityStringQuery {

    /// The id is the display name, so identifiers resolve without the live node list.
    /// That keeps saved shortcuts intact while the tunnel is down (the list is only
    /// readable through the running extension); a node that no longer exists fails at
    /// perform time with a clear dialog instead.
    func entities(for identifiers: [String]) async throws -> [ExitNodeEntity] {
        identifiers.map { ExitNodeEntity(id: $0) }
    }

    func entities(matching string: String) async throws -> [ExitNodeEntity] {
        try await suggestedEntities().filter { $0.id.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [ExitNodeEntity] {
        // Prefer the live network map from the running tunnel.
        if let manager = try? await VPNIntentHelpers.loadManager(),
           manager.connection.status == .connected,
           let session = manager.connection as? NETunnelProviderSession,
           let live = await ExitNodeIntentHelpers.fetchExitNodes(session: session),
           !live.isEmpty {
            return live.map { ExitNodeEntity(id: $0.name) }
        }

        // While the VPN is down the map is unreachable; offer the names the main app
        // cached on its last successful route read so shortcuts stay configurable.
        let cached = VPNIntentHelpers.defaults?.stringArray(forKey: WidgetConstants.keyExitNodes) ?? []
        return cached.map { ExitNodeEntity(id: $0) }
    }
}
