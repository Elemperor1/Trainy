import FirebaseCore
import SwiftUI
import TrainyCore

@main
struct TrainyApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
