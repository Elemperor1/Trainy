import FirebaseCore
import SwiftUI
import TrainyCore

@main
struct TrainyApp: App {
    @StateObject private var rootDependencies: TrainyRootDependencies

    init() {
        FirebaseApp.configure()
        _rootDependencies = StateObject(
            wrappedValue: TrainyRootDependencies(
                automationScenario: TrainyAutomationScenario.fromLaunchArguments()
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(rootDependencies: rootDependencies)
        }
    }
}
