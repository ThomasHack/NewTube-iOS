import NewTubeCore
import SwiftUI

// MARK: - InnerTubeAPIKey

private struct InnerTubeAPIKey: EnvironmentKey {
    static let defaultValue = InnerTubeAPI()
}

extension EnvironmentValues {
    var innerTubeAPI: InnerTubeAPI {
        get { self[InnerTubeAPIKey.self] }
        set { self[InnerTubeAPIKey.self] = newValue }
    }
}
