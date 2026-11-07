# SmartTubeCore

UI-independent code for the SmartTube tvOS app: models, InnerTube and SponsorBlock clients, stores and
decision logic. It must not import SwiftUI, UIKit or AVFoundation; see
[ADR-0011](../docs/adr/0011-one-core-package.md).

Run the tests with `just test-core`. They need the tvOS simulator, so `swift test` isn't supported.
