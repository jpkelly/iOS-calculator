import SwiftUI

/// SwiftUI app entry point.
///
/// Hosts `ContentView`, which wraps the framework-independent `Calculator`
/// engine from the `CalculatorEngine` package.
@main
struct CalculatorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
