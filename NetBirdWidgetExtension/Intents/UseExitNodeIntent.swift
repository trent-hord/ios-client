import AppIntents
import NetworkExtension

@available(iOS 16.0, *)
struct UseExitNodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Use Exit Node"
    static var description = IntentDescription("Route all traffic through a NetBird exit node.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Exit Node", requestValueDialog: "Which exit node?")
    var exitNode: ExitNodeEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Use exit node \(\.$exitNode)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let manager = try await VPNIntentHelpers.loadManager() else {
            return .result(dialog: "NetBird VPN is not configured.")
        }

        guard manager.connection.status == .connected,
              let session = manager.connection as? NETunnelProviderSession else {
            return .result(dialog: "NetBird VPN is not connected. Connect first, then choose an exit node.")
        }

        guard let nodes = await ExitNodeIntentHelpers.fetchExitNodes(session: session) else {
            return .result(dialog: "Could not read the exit node list from NetBird VPN. Please try again.")
        }
        guard !nodes.isEmpty else {
            return .result(dialog: "No exit nodes are available in your NetBird network.")
        }
        guard let target = nodes.first(where: { $0.name == exitNode.id }) else {
            return .result(dialog: "Exit node \"\(exitNode.id)\" is not available.")
        }

        let selectedSiblings = nodes.filter { $0.selected && $0.name != target.name }
        if target.selected && selectedSiblings.isEmpty {
            return .result(dialog: "Already using exit node \"\(target.name)\".")
        }

        // Exit nodes are mutually exclusive. Same ordering as RoutesViewModel.selectRoute:
        // fully deselect the currently selected nodes BEFORE selecting the new one —
        // firing the select concurrently lets the core drop the node just added.
        for sibling in selectedSiblings {
            await ExitNodeIntentHelpers.sendMessage("Deselect-\(sibling.name)", via: session)
        }
        await ExitNodeIntentHelpers.sendMessage("Select-\(target.name)", via: session)

        // The extension replies "true" unconditionally, so only a fresh read of the
        // network map proves the core actually applied the node. A failed read (nil)
        // proves nothing and must land on the failure dialog, never the success one.
        let verification = await ExitNodeIntentHelpers.fetchExitNodes(session: session)
        let applied = verification?.first(where: { $0.name == target.name })?.selected ?? false
        if applied {
            return .result(dialog: "Now using exit node \"\(target.name)\".")
        }
        return .result(dialog: "Failed to enable exit node \"\(target.name)\".")
    }
}
