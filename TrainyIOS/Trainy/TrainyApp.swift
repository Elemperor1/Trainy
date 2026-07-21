import FirebaseCore
import FirebaseCrashlytics
import SwiftUI
import TrainyCore

@main
struct TrainyApp: App {
    @StateObject private var rootDependencies: TrainyRootDependencies

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--trainy-reset-diagnostics-consent") {
            UserDefaults.standard.removeObject(forKey: "trainy.diagnosticsConsent")
        }
        #endif
        FirebaseApp.configure()
        let diagnosticsConsent = UserDefaults.standard.bool(forKey: "trainy.diagnosticsConsent")
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(diagnosticsConsent)
        if !diagnosticsConsent {
            Crashlytics.crashlytics().deleteUnsentReports()
        }
        #if DEBUG
        _rootDependencies = StateObject(
            wrappedValue: TrainyRootDependencies(
                automationScenario: TrainyAutomationScenario.fromLaunchArguments()
            )
        )
        #else
        _rootDependencies = StateObject(wrappedValue: TrainyRootDependencies())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(rootDependencies: rootDependencies)
        }
    }
}
