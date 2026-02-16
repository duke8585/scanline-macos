import Foundation
import EventKit

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let calendarColor: CGColor

    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier
        self.title = ekEvent.title ?? "Untitled"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.calendarTitle = ekEvent.calendar.title
        self.calendarColor = ekEvent.calendar.cgColor
    }

    init(id: String, title: String, startDate: Date, endDate: Date, calendarTitle: String, calendarColor: CGColor) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.calendarColor = calendarColor
    }
}

@Observable
final class AppState {
    var selectedCalendarIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(selectedCalendarIDs), forKey: "selectedCalendarIDs")
        }
    }
    var reminderBeforeEnabled: Bool {
        didSet { UserDefaults.standard.set(reminderBeforeEnabled, forKey: "reminderBeforeEnabled") }
    }
    var reminderBeforeMinutes: Int {
        didSet { UserDefaults.standard.set(reminderBeforeMinutes, forKey: "reminderBeforeMinutes") }
    }
    var reminderAtStartEnabled: Bool {
        didSet { UserDefaults.standard.set(reminderAtStartEnabled, forKey: "reminderAtStartEnabled") }
    }
    var reminderAfterEnabled: Bool {
        didSet { UserDefaults.standard.set(reminderAfterEnabled, forKey: "reminderAfterEnabled") }
    }
    var reminderAfterMinutes: Int {
        didSet { UserDefaults.standard.set(reminderAfterMinutes, forKey: "reminderAfterMinutes") }
    }
    var activeOverlayEvent: CalendarEvent? {
        didSet { handleOverlayChange() }
    }
    var eventQueue: [CalendarEvent] = []
    var snoozeQueue: [(event: CalendarEvent, fireDate: Date)] = []
    var permissionGranted: Bool = false
    var firedAlarmKeys: Set<String> = []
    var refreshTick: Int = 0

    let calendarService = CalendarService()
    private(set) var eventMonitor: EventMonitor?
    private let overlayController = OverlayWindowController()

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: "selectedCalendarIDs") ?? []
        self.selectedCalendarIDs = Set(saved)

        let defaults = UserDefaults.standard
        self.reminderBeforeEnabled = defaults.bool(forKey: "reminderBeforeEnabled")
        self.reminderBeforeMinutes = defaults.object(forKey: "reminderBeforeMinutes") == nil
            ? 5 : defaults.integer(forKey: "reminderBeforeMinutes")
        self.reminderAtStartEnabled = defaults.object(forKey: "reminderAtStartEnabled") == nil
            ? true : defaults.bool(forKey: "reminderAtStartEnabled")
        self.reminderAfterEnabled = defaults.bool(forKey: "reminderAfterEnabled")
        self.reminderAfterMinutes = defaults.object(forKey: "reminderAfterMinutes") == nil
            ? 5 : defaults.integer(forKey: "reminderAfterMinutes")
    }

    func setup() {
        let monitor = EventMonitor(appState: self, calendarService: calendarService)
        self.eventMonitor = monitor

        Task { @MainActor in
            self.permissionGranted = await calendarService.requestAccess()
            if self.permissionGranted {
                monitor.start()
            }
        }
    }

    func syncNow() {
        calendarService.refreshSources()
        eventMonitor?.poll()
    }

    func testOverlay() {
        let event = CalendarEvent(
            id: "test-\(UUID().uuidString)",
            title: "Test Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarTitle: "Test Calendar",
            calendarColor: CGColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)
        )
        enqueueEvent(event)
    }

    func enqueueEvent(_ event: CalendarEvent) {
        if activeOverlayEvent == nil {
            activeOverlayEvent = event
        } else {
            eventQueue.append(event)
        }
    }

    func dismiss() {
        activeOverlayEvent = nil
        showNextQueued()
    }

    func snooze(minutes: Int) {
        if let event = activeOverlayEvent {
            let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
            snoozeQueue.append((event: event, fireDate: fireDate))
            eventMonitor?.reschedule()
        }
        activeOverlayEvent = nil
        showNextQueued()
    }

    private func showNextQueued() {
        if !eventQueue.isEmpty {
            activeOverlayEvent = eventQueue.removeFirst()
        }
    }

    private func handleOverlayChange() {
        if let event = activeOverlayEvent {
            overlayController.show(
                event: event,
                onDismiss: { [weak self] in self?.dismiss() },
                onSnooze: { [weak self] minutes in self?.snooze(minutes: minutes) }
            )
        } else {
            overlayController.close()
        }
    }
}
