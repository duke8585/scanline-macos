import SwiftUI

struct MenuBarView: View {
    var appState: AppState
    @Environment(\.openSettings) private var openSettings

    private var upcomingEvents: [CalendarEvent] {
        guard appState.permissionGranted, !appState.selectedCalendarIDs.isEmpty else { return [] }
        let now = Date()
        let range = DateInterval(start: now, duration: 24 * 60 * 60)
        let events = appState.calendarService.events(for: appState.selectedCalendarIDs, in: range)
        return events
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(2)
            .map { CalendarEvent(from: $0) }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        let _ = appState.refreshTick
        if !appState.permissionGranted {
            Text("Calendar access needed")
            Button("Open System Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
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

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
