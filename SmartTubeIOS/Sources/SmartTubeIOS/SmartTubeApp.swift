import SmartTubeIOSCore
import SwiftUI

/// App entry point – supports iOS 17+, iPadOS 17+, macOS 14+.
struct SmartTubeApp: App {
    @State private var api: InnerTubeAPI
    @State private var authService: AuthService
    @State private var browseViewModel: BrowseViewModel
    @State private var settingsStore: SettingsStore
    /// Shared download service used by video cards. Lives at the app scope so
    /// the download task is not orphaned when a card view leaves the hierarchy
    /// (e.g. after a context menu dismiss). PlayerView creates its own isolated
    /// service instance and is unaffected.
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let api = InnerTubeAPI()
        _api = State(initialValue: api)
        _authService = State(initialValue: AuthService())
        _browseViewModel = State(initialValue: BrowseViewModel(api: api))
        let settingsStore = SettingsStore()
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
                .onChange(of: settingsStore.settings.enabledSections) { _, newSections in
                    browseViewModel.configureSections(newSections)
                }
                .task {
                    // Sync enablement state on launch, then start the iCloud KV listener.
                    iCloudSyncManager.shared.syncEnabled = settingsStore.settings.iCloudSyncEnabled
                    await iCloudSyncManager.shared.start()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await authService.refreshIfNeeded()
                    authService.handleForeground()
                }
            }
        }
    }
}
