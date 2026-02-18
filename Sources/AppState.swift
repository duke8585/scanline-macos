import Foundation
import EventKit

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let calendarColor: CGColor
    let notes: String?

    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.title = ekEvent.title ?? "Untitled"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.calendarTitle = ekEvent.calendar.title
        self.calendarColor = ekEvent.calendar.cgColor
        self.notes = ekEvent.notes
    }

    init(id: String, title: String, startDate: Date, endDate: Date, calendarTitle: String, calendarColor: CGColor, notes: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.calendarColor = calendarColor
        self.notes = notes
    }
}

struct SnoozedEvent {
    let event: CalendarEvent
    let fireDate: Date
}

@Observable @MainActor
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
    var snoozeQueue: [SnoozedEvent] = []
    var permissionGranted: Bool = false
    var firedAlarmKeys: Set<String> = []
    var cachedUpcomingEvents: [CalendarEvent] = []
    var cachedCalendars: [(String, [EKCalendar])] = []

    let calendarService: any CalendarServiceProtocol
    private(set) var eventMonitor: EventMonitor?
    private let overlayController: any OverlayPresenting

    // Note: didSet observers don't fire during init, so direct assignment is safe here.
    init(calendarService: any CalendarServiceProtocol = CalendarService(),
         overlayPresenter: any OverlayPresenting = OverlayWindowController()) {
        UserDefaults.standard.register(defaults: [
            "reminderBeforeMinutes": 5,
            "reminderAtStartEnabled": true,
            "reminderAfterMinutes": 5,
        ])

        self.calendarService = calendarService
        self.overlayController = overlayPresenter

        let saved = UserDefaults.standard.stringArray(forKey: "selectedCalendarIDs") ?? []
        self.selectedCalendarIDs = Set(saved)

        let defaults = UserDefaults.standard
        self.reminderBeforeEnabled = defaults.bool(forKey: "reminderBeforeEnabled")
        self.reminderBeforeMinutes = defaults.integer(forKey: "reminderBeforeMinutes")
        self.reminderAtStartEnabled = defaults.bool(forKey: "reminderAtStartEnabled")
        self.reminderAfterEnabled = defaults.bool(forKey: "reminderAfterEnabled")
        self.reminderAfterMinutes = defaults.integer(forKey: "reminderAfterMinutes")
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
            calendarColor: CGColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0),
            notes: "This is a sample meeting description to preview the overlay layout. It may span multiple lines depending on the content length."
        )
        enqueueEvent(event)
    }

    func enqueueEvent(_ event: CalendarEvent) {
        guard activeOverlayEvent?.id != event.id,
              !eventQueue.contains(where: { $0.id == event.id }) else { return }
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
            snoozeQueue.append(SnoozedEvent(event: event, fireDate: fireDate))
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

    func refreshCaches() {
        guard permissionGranted else { return }
        let now = Date()
        let range = DateInterval(start: now, duration: 24 * 60 * 60)
        if !selectedCalendarIDs.isEmpty {
            let events = calendarService.events(for: selectedCalendarIDs, in: range)
            cachedUpcomingEvents = events
                .filter { $0.startDate > now }
                .sorted { $0.startDate < $1.startDate }
        } else {
            cachedUpcomingEvents = []
        }
        let calendars = calendarService.allCalendars()
        let grouped = Dictionary(grouping: calendars) { $0.source.title }
        cachedCalendars = grouped.sorted { $0.key < $1.key }
    }

    func pruneFiredAlarmKeys(currentEvents: [CalendarEvent]) {
        let validIDs = Set(currentEvents.map(\.id))
        firedAlarmKeys = firedAlarmKeys.filter { key in
            validIDs.contains(where: { key.hasPrefix($0) })
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
