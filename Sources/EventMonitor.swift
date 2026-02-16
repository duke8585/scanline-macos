import Foundation

@MainActor
final class EventMonitor {
    private weak var appState: AppState?
    private let calendarService: any CalendarServiceProtocol
    private var refreshTimer: Timer?
    private var fireTimer: Timer?
    private(set) var scheduledFires: [(key: String, fireDate: Date, event: CalendarEvent)] = []

    init(appState: AppState, calendarService: any CalendarServiceProtocol) {
        self.appState = appState
        self.calendarService = calendarService
    }

    func start() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        refreshTimer?.tolerance = 10
        poll()
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        fireTimer?.invalidate()
        fireTimer = nil
    }

    func poll() {
        guard let appState else { return }
        let now = Date()

        fireExpiredSnoozes(appState: appState)

        guard !appState.selectedCalendarIDs.isEmpty else { return }
        let range = DateInterval(start: now, duration: 24 * 60 * 60)
        let events = calendarService.events(for: appState.selectedCalendarIDs, in: range)

        appState.pruneFiredAlarmKeys(currentEvents: events)

        var futureFires: [(key: String, fireDate: Date, event: CalendarEvent)] = []

        for event in events {
            let eventID = event.id

            var fireTimes: [(key: String, date: Date)] = []
            if appState.reminderBeforeEnabled {
                let offset = TimeInterval(-appState.reminderBeforeMinutes * 60)
                fireTimes.append(("\(eventID)_before", event.startDate.addingTimeInterval(offset)))
            }
            if appState.reminderAtStartEnabled {
                fireTimes.append(("\(eventID)_start", event.startDate))
            }
            if appState.reminderAfterEnabled {
                let offset = TimeInterval(appState.reminderAfterMinutes * 60)
                fireTimes.append(("\(eventID)_after", event.startDate.addingTimeInterval(offset)))
            }

            for (key, fireTime) in fireTimes {
                guard !appState.firedAlarmKeys.contains(key) else { continue }
                if fireTime <= now && now.timeIntervalSince(fireTime) < 60 {
                    // Due now (within 60s window) — fire immediately
                    appState.firedAlarmKeys.insert(key)
                    appState.enqueueEvent(event)
                } else if fireTime > now {
                    // Future — track for precise scheduling
                    futureFires.append((key: key, fireDate: fireTime, event: event))
                }
            }
        }

        scheduledFires = futureFires.sorted { $0.fireDate < $1.fireDate }
        appState.refreshCaches()
        scheduleNextFire()
    }

    /// Re-evaluate the next fire time (call after snooze queue changes).
    func reschedule() {
        scheduleNextFire()
    }

    private func scheduleNextFire() {
        fireTimer?.invalidate()
        fireTimer = nil

        let now = Date()
        var nextDate: Date?

        if let first = scheduledFires.first {
            nextDate = first.fireDate
        }
        if let nextSnooze = appState?.snoozeQueue.map({ $0.fireDate }).min() {
            if nextDate == nil || nextSnooze < nextDate! {
                nextDate = nextSnooze
            }
        }

        guard let fireDate = nextDate else { return }

        let delay = max(fireDate.timeIntervalSince(now), 0)
        fireTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.handleFire() }
        }
        fireTimer?.tolerance = 1
    }

    private func handleFire() {
        guard let appState else { return }
        let now = Date()

        fireExpiredSnoozes(appState: appState)

        // Fire scheduled alarms (1s tolerance for timer drift)
        while let first = scheduledFires.first, first.fireDate <= now.addingTimeInterval(1) {
            scheduledFires.removeFirst()
            if !appState.firedAlarmKeys.contains(first.key) {
                appState.firedAlarmKeys.insert(first.key)
                appState.enqueueEvent(first.event)
            }
        }

        scheduleNextFire()
    }

    private func fireExpiredSnoozes(appState: AppState) {
        let now = Date()
        let expiredSnoozes = appState.snoozeQueue.filter { $0.fireDate <= now }
        appState.snoozeQueue.removeAll { $0.fireDate <= now }
        for snoozed in expiredSnoozes {
            appState.enqueueEvent(snoozed.event)
        }
    }
}
