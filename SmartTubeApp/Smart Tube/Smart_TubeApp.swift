import SmartTubeCore
import SwiftUI

/// Picks the scene to launch. Hosted unit tests get an empty one, so a test run never starts the
/// real app's sign-in, network and BotGuard work.
@main
enum AppLauncher {
    static func main() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            UnitTestHostApp.main()
        } else {
            SmartTubeTVApp.main()
        }
    }
}

private struct UnitTestHostApp: App {
    var body: some Scene {
        WindowGroup { EmptyView() }
    }
}

/// tvOS entry point for SmartTube.
/// The device-code + QR sign-in flow is natively designed for Apple TV —
/// the user reads a code on screen and activates on their phone at yt.be/activate.
struct SmartTubeTVApp: App {
    // Declared without default values so that init() can build them in dependency order.
    @State private var api: InnerTubeAPI
    @State private var authService: AuthService
    @State private var browseViewModel: BrowseViewModel
    @State private var settingsStore: SettingsStore
    /// Shared download service — required by RootView and VideoCardView even on
    /// tvOS (where downloads are disabled in UI). Must be present in the environment
    /// or SwiftUI throws a fatal "No Observable object of type VideoDownloadService"
    /// error at launch.

    init() {
        let settingsStore = SettingsStore()
        let poTokenProvider: (any PoTokenProvider)? = {
            if let url = settingsStore.settings.poTokenServiceURL {
                return ServerPoTokenProvider(serviceURL: url)
            }
            return BotGuardClient()
        }()
        let api = InnerTubeAPI(authToken: nil, poTokenProvider: poTokenProvider)
        _api = State(initialValue: api)
        _authService = State(initialValue: AuthService())
        _browseViewModel = State(initialValue: BrowseViewModel(api: api))
        _settingsStore = State(initialValue: settingsStore)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(browseViewModel)
                .environment(settingsStore)
                .environment(\.innerTubeAPI, api)
                .onChange(of: authService.accessToken, initial: true) { _, newToken in
                    Task {
                        await api.setAuthToken(newToken)
                        await browseViewModel.updateAuthToken(newToken)
                    }
                }
                .onChange(of: authService.sapisid, initial: true) { _, newSapisid in
                    Task { await api.setSAPISID(newSapisid) }
                }
                .onChange(of: settingsStore.settings.enabledSections) { _, newSections in
                    browseViewModel.configureSections(newSections)
                }
                .onChange(of: settingsStore.settings.historyState, initial: true) { _, newState in
                    browseViewModel.updateHistoryEnabled(newState == .enabled)
                }
        }
    }
}
