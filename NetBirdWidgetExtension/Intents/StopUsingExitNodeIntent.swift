import AppIntents
import NetworkExtension

@available(iOS 16.0, *)
struct StopUsingExitNodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Using Exit Node"
    static var description = IntentDescription("Stop routing traffic through a NetBird exit node.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let manager = try await VPNIntentHelpers.loadManager() else {
            return .result(dialog: "NetBird VPN is not configured.")
        }

        guard manager.connection.status == .connected,
              let session = manager.connection as? NETunnelProviderSession else {
            return .result(dialog: "NetBird VPN is not connected, so no exit node is active.")
        }

        guard let nodes = await ExitNodeIntentHelpers.fetchExitNodes(session: session) else {
            return .result(dialog: "Could not read the exit node list from NetBird VPN. Please try again.")
        }

        // More than one node can be selected if state was left behind by older versions;
        // clear them all, mirroring what selecting "None" in the app converges to.
        let selected = nodes.filter { $0.selected }
        guard !selected.isEmpty else {
            return .result(dialog: "No exit node is in use.")
        }

        for node in selected {
            await ExitNodeIntentHelpers.sendMessage("Deselect-\(node.name)", via: session)
        }

        // The extension replies "true" unconditionally, so only a fresh read of the
        // network map proves the core actually dropped the node. A failed read (nil)
        // proves nothing and must land on the failure dialog, never the success one.
        if let remaining = await ExitNodeIntentHelpers.fetchExitNodes(session: session),
           remaining.allSatisfy({ !$0.selected }) {
            let names = selected.map { "\"\($0.name)\"" }.joined(separator: ", ")
            return .result(dialog: "Stopped using exit node \(names).")
        }
        return .result(dialog: "Failed to stop using the exit node.")
    }
}
