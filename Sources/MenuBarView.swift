import SwiftUI

struct MenuBarView: View {
    var appState: AppState
    @Environment(\.openSettings) private var openSettings

    private var upcomingEvents: [CalendarEvent] {
        Array(appState.cachedUpcomingEvents.filter { $0.startDate > Date() }.prefix(2))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        if !appState.permissionGranted {
            Text("Calendar access needed")
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
        } else if appState.selectedCalendarIDs.isEmpty {
            Text("Select calendars in Settings")
        } else if upcomingEvents.isEmpty {
            Text("No upcoming events")
        } else {
            ForEach(upcomingEvents) { event in
                Text("\(Self.timeFormatter.string(from: event.startDate))  \(event.title)")
            }
        }

        Divider()

        Button("Sync Now") {
            appState.syncNow()
        }

        Divider()

        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }

        Divider()

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        Button("GitHub") {
            if let url = URL(string: "https://github.com/duke8585/scanline-macos") {
                NSWorkspace.shared.open(url)
            }
        }

        Button("Quit Scanline") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")

        Divider()

        Text("v\(version)")
            .foregroundStyle(.secondary)
            .font(.caption)
    }
}
