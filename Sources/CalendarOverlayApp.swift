import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.setup()
    }
}

@main
struct CalendarOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra("CalendarOverlay", systemImage: "calendar.badge.clock") {
            MenuBarView(appState: delegate.appState)
        }
        Settings {
            SettingsView(appState: delegate.appState)
        }
    }
}
