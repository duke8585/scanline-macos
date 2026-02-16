import SwiftUI
import EventKit

struct SettingsView: View {
    var appState: AppState

    private static let minuteOptions = [1, 2, 3, 5, 10, 15, 30]
    private static let debugTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var calendarsBySource: [(String, [EKCalendar])] {
        let calendars = appState.calendarService.allCalendars()
        let grouped = Dictionary(grouping: calendars) { $0.source.title }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        Form {
            if !appState.permissionGranted {
                Section {
                    Text("Calendar access is required.")
                    Button("Grant Access") {
                        Task {
                            appState.permissionGranted = await appState.calendarService.requestAccess()
                        }
                    }
                }
            } else {
                ForEach(calendarsBySource, id: \.0) { source, calendars in
                    Section(header: Text(source)) {
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
                            Toggle(isOn: Binding(
                                get: { appState.selectedCalendarIDs.contains(calendar.calendarIdentifier) },
                                set: { isOn in
                                    if isOn {
                                        appState.selectedCalendarIDs.insert(calendar.calendarIdentifier)
                                    } else {
                                        appState.selectedCalendarIDs.remove(calendar.calendarIdentifier)
                                    }
                                }
                            )) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(cgColor: calendar.cgColor))
                                        .frame(width: 10, height: 10)
                                    Text(calendar.title)
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Reminders")) {
                    if !appState.reminderBeforeEnabled && !appState.reminderAtStartEnabled && !appState.reminderAfterEnabled {
                        Text("No reminders enabled — overlays won't fire.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Toggle("Before event", isOn: Binding(
                        get: { appState.reminderBeforeEnabled },
                        set: { appState.reminderBeforeEnabled = $0 }
                    ))
                    if appState.reminderBeforeEnabled {
                        Picker("Minutes before", selection: Binding(
                            get: { appState.reminderBeforeMinutes },
                            set: { appState.reminderBeforeMinutes = $0 }
                        )) {
                            ForEach(Self.minuteOptions, id: \.self) { m in
                                Text("\(m) min").tag(m)
                            }
                        }
                    }

                    Toggle("At event start", isOn: Binding(
                        get: { appState.reminderAtStartEnabled },
                        set: { appState.reminderAtStartEnabled = $0 }
                    ))

                    Toggle("After event starts", isOn: Binding(
                        get: { appState.reminderAfterEnabled },
                        set: { appState.reminderAfterEnabled = $0 }
                    ))
                    if appState.reminderAfterEnabled {
                        Picker("Minutes after", selection: Binding(
                            get: { appState.reminderAfterMinutes },
                            set: { appState.reminderAfterMinutes = $0 }
                        )) {
                            ForEach(Self.minuteOptions, id: \.self) { m in
                                Text("\(m) min").tag(m)
                            }
                        }
                    }
                }

                Section {
                    Button("Test Overlay") {
                        appState.testOverlay()
                    }
                }

                Section(header: Text("Debug")) {
                    Button("Refresh") { appState.syncNow() }
                    let _ = appState.refreshTick
                    let entries: [(id: String, title: String, tag: String, tagColor: Color, fireDate: Date)] = {
                        let fires = (appState.eventMonitor?.scheduledFires ?? []).map {
                            let tag = $0.key.components(separatedBy: "_").last ?? ""
                            let color: Color = switch tag {
                            case "before": .red
                            case "after": .blue
                            default: .secondary
                            }
                            return (id: $0.key, title: $0.event.title ?? "Untitled",
                                    tag: tag, tagColor: color, fireDate: $0.fireDate)
                        }
                        let snoozes = appState.snoozeQueue.enumerated().map { i, s in
                            (id: "snooze_\(i)", title: s.event.title,
                             tag: "snooze", tagColor: Color.orange, fireDate: s.fireDate)
                        }
                        return (fires + snoozes).sorted { $0.fireDate < $1.fireDate }
                    }()

                    if entries.isEmpty {
                        Text("No scheduled fires").foregroundStyle(.secondary)
                    }

                    ForEach(entries, id: \.id) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.title)
                                    .font(.caption.weight(.medium))
                                Text(entry.tag)
                                    .font(.caption2)
                                    .foregroundStyle(entry.tagColor)
                            }
                            Spacer()
                            Text(Self.debugTimeFormatter.string(from: entry.fireDate))
                                .font(.caption.monospaced())
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 600)
    }
}
