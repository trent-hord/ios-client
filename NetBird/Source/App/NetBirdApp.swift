//
//  NetBirdApp.swift
//  NetBird
//
//  Created by Pascal Fischer on 01.08.23.
//
//  Main entry point for the NetBird app.
//  Supports both iOS and tvOS platforms.
//

import SwiftUI
import FirebaseCore
import Combine
import UserNotifications
import NetBirdSDK

#if os(iOS)
import FirebasePerformance
import WidgetKit
#endif

/// True when the app was launched solely to host unit tests. XCTest sets this
/// environment variable on the test host process.
private var isRunningUnitTests: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

/// Returns whether a GoogleService plist contains a Firebase configuration that
/// is safe to pass to `FirebaseApp.configure`. Firebase throws an uncaught
/// Objective-C exception for placeholder app IDs, so validation must happen
/// before calling into the SDK.
func isUsableFirebaseConfiguration(
    _ configuration: [String: Any],
    bundleIdentifier: String?
) -> Bool {
    if configuration["NETBIRD_FIREBASE_DISABLED"] as? Bool == true {
        return false
    }

    guard let configuredBundleID = configuration["BUNDLE_ID"] as? String,
          !configuredBundleID.isEmpty,
          configuredBundleID == bundleIdentifier,
          let googleAppID = configuration["GOOGLE_APP_ID"] as? String else {
        return false
    }

    let components = googleAppID.split(separator: ":", omittingEmptySubsequences: false)
    guard components.count >= 4,
          components[0] == "1",
          Int(components[1]) != nil,
          components[2] == "ios",
          !components[3].isEmpty else {
        return false
    }

    return true
}

/// Configures Firebase only when the bundled GoogleService plist is real and
/// belongs to the current app. Builds without Firebase remain fully functional.
private func configureFirebaseIfNeeded() {
    guard !isRunningUnitTests,
          FirebaseApp.app() == nil,
          let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
          let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let configuration = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
          ) as? [String: Any],
          isUsableFirebaseConfiguration(
            configuration,
            bundleIdentifier: Bundle.main.bundleIdentifier
          ),
          let options = FirebaseOptions(contentsOfFile: path) else {
        return
    }

    FirebaseApp.configure(options: options)
}

#if os(iOS)
extension Notification.Name {
    static let netbirdLoginNotificationTapped = Notification.Name("io.netbird.loginNotificationTapped")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureFirebaseIfNeeded()

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                AppLogger.shared.log("Notification authorization error: \(error.localizedDescription)")
            } else {
                AppLogger.shared.log("Notification authorization granted: \(granted)")
            }
        }

        return true
    }

    // Show notification banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Handle tap on notification — post event so the app navigates to auth flow
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier == GlobalConstants.notificationLoginRequired {
            NotificationCenter.default.post(name: .netbirdLoginNotificationTapped, object: nil)
        }
        completionHandler()
    }
}
#endif

@main
struct NetBirdApp: App {
    @StateObject private var viewModelLoader = ViewModelLoader()
    @Environment(\.scenePhase) var scenePhase
    @State private var activationTask: Task<Void, Never>?
    @State private var pendingURL: URL?

    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif

    init() {
        // Configure Firebase on main thread as required by Firebase
        #if os(tvOS)
        configureFirebaseIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if let viewModel = viewModelLoader.viewModel {
                MainView()
                    .environmentObject(viewModel)
                    #if os(iOS)
                    .onOpenURL { url in
                        handleWidgetURL(url, viewModel: viewModel)
                    }
                    .onAppear {
                        if let url = pendingURL {
                            handleWidgetURL(url, viewModel: viewModel)
                            pendingURL = nil
                        }
                        if UIApplication.shared.applicationState == .active {
                            startActivation(viewModel: viewModel)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        startActivation(viewModel: viewModel)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                        stopActivation(viewModel: viewModel)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .netbirdLoginNotificationTapped)) { _ in
                        viewModel.showAuthenticationRequired = true
                    }
                    #endif
                    #if os(tvOS)
                    .onAppear {
                        if scenePhase == .active {
                            startActivation(viewModel: viewModel)
                        }
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            startActivation(viewModel: viewModel)
                        } else {
                            stopActivation(viewModel: viewModel)
                        }
                    }
                    #endif
            } else {
                loadingView
                    #if os(iOS)
                    .onOpenURL { url in
                        pendingURL = url
                    }
                    #endif
            }
        }
    }

    // MARK: - Activation

    private func startActivation(viewModel: ViewModel) {
        activationTask?.cancel()
        activationTask = Task { @MainActor in
            guard isAppActive, !Task.isCancelled else { return }

            if let initialStatus = await viewModel.networkExtensionAdapter.loadCurrentConnectionState() {
                // Clear stale button-press flags before applying the fresh NE state.
                // These flags are only valid for the brief gap between a button tap and
                // the corresponding NE state change; any external change (widget action,
                // On Demand trigger) makes them stale when returning to the foreground.
                viewModel.connectPressed = false
                viewModel.disconnectPressed = false
                viewModel.extensionState = initialStatus
                viewModel.updateVPNDisplayState()

                #if os(tvOS)
                // Reconcile even while disconnected so an existing authenticated tvOS
                // install adopts default-on without requiring one manual connection.
                // Credential verification runs off the main actor.
                viewModel.ensureOnDemandConfigured()
                #else
                // Preserve the established iOS behavior: only restore On Demand after
                // the tunnel itself confirms a successful connection.
                if initialStatus == .connected {
                    viewModel.ensureOnDemandConfigured()
                }
                #endif
            } else {
                // No matching VPN profile found — still force a widget timeline refresh so
                // the widget doesn't stay stuck on a transitioning state from a prior
                // widget-initiated disconnect/connect while the app was closed.
                #if os(iOS)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
            }

            guard isAppActive, !Task.isCancelled else { return }
            viewModel.checkExtensionState()
            #if os(iOS)
            viewModel.checkLoginRequiredFlag()
            #endif
            viewModel.startPollingDetails()
        }
    }

    private func stopActivation(viewModel: ViewModel) {
        activationTask?.cancel()
        activationTask = nil
        viewModel.stopPollingDetails()
    }

    private var isAppActive: Bool {
        #if os(iOS)
        UIApplication.shared.applicationState == .active
        #else
        scenePhase == .active
        #endif
    }

    private var loadingView: some View {
        ZStack {
            Color("BgPrimary")
                .ignoresSafeArea()
            Image("netbird-logo-menu")
                .resizable()
                .scaledToFit()
                .frame(width: 200)
        }
    }

    #if os(iOS)
    /// Handles deep link URLs from the Home Screen widget.
    private func handleWidgetURL(_ url: URL, viewModel: ViewModel) {
        guard url.scheme == "netbird" else { return }
        switch url.host {
        case "login":
            viewModel.connect()
        case "connect":
            if viewModel.vpnDisplayState == .disconnected {
                viewModel.connect()
            }
        case "disconnect":
            if viewModel.vpnDisplayState == .connected {
                viewModel.close()
            }
        default:
            break
        }
    }
    #endif
}

/// Loads ViewModel asynchronously to avoid blocking app launch.
/// The Go runtime initialization (from NetBirdSDK) can take several seconds on cold start.
/// By creating the ViewModel in an async Task, the loading screen appears immediately
/// instead of showing a black screen.
@MainActor
class ViewModelLoader: ObservableObject {
    @Published var viewModel: ViewModel?

    init() {
        Task { @MainActor in
            self.viewModel = ViewModel()
        }
    }
}
