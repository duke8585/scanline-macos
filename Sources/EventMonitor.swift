import Foundation
import EventKit

final class EventMonitor {
    private let appState: AppState
    private let calendarService: CalendarService
    private var refreshTimer: Timer?
    private var fireTimer: Timer?
    private(set) var scheduledFires: [(key: String, fireDate: Date, event: EKEvent)] = []

    init(appState: AppState, calendarService: CalendarService) {
        self.appState = appState
        self.calendarService = calendarService
    }

    func start() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        fireTimer?.invalidate()
        fireTimer = nil
    }

    func poll() {
        let now = Date()

        // Fire expired snoozes
        let expiredSnoozes = appState.snoozeQueue.filter { $0.fireDate <= now }
        appState.snoozeQueue.removeAll { $0.fireDate <= now }
        for snoozed in expiredSnoozes {
            appState.enqueueEvent(snoozed.event)
        }

        guard !appState.selectedCalendarIDs.isEmpty else { return }
        let range = DateInterval(start: now, duration: 24 * 60 * 60)
        let events = calendarService.events(for: appState.selectedCalendarIDs, in: range)

        var futureFires: [(key: String, fireDate: Date, event: EKEvent)] = []

        for ekEvent in events {
            let eventID = ekEvent.eventIdentifier ?? ""

            var fireTimes: [(key: String, date: Date)] = []
            if appState.reminderBeforeEnabled {
                let offset = TimeInterval(-appState.reminderBeforeMinutes * 60)
                fireTimes.append(("\(eventID)_before", ekEvent.startDate.addingTimeInterval(offset)))
            }
            if appState.reminderAtStartEnabled {
                fireTimes.append(("\(eventID)_start", ekEvent.startDate))
            }
            if appState.reminderAfterEnabled {
                let offset = TimeInterval(appState.reminderAfterMinutes * 60)
                fireTimes.append(("\(eventID)_after", ekEvent.startDate.addingTimeInterval(offset)))
            }

            for (key, fireTime) in fireTimes {
                guard !appState.firedAlarmKeys.contains(key) else { continue }
                if fireTime <= now && now.timeIntervalSince(fireTime) < 60 {
                    // Due now (within 60s window) — fire immediately
                    appState.firedAlarmKeys.insert(key)
                    appState.enqueueEvent(CalendarEvent(from: ekEvent))
                } else if fireTime > now {
                    // Future — track for precise scheduling
                    futureFires.append((key: key, fireDate: fireTime, event: ekEvent))
                }
            }
        }

        scheduledFires = futureFires.sorted { $0.fireDate < $1.fireDate }
        appState.refreshTick += 1
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
        if let nextSnooze = appState.snoozeQueue.map({ $0.fireDate }).min() {
            if nextDate == nil || nextSnooze < nextDate! {
                nextDate = nextSnooze
            }
        }

        guard let fireDate = nextDate else { return }

        let delay = max(fireDate.timeIntervalSince(now), 0)
        fireTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.handleFire()
        }
    }

    private func handleFire() {
        let now = Date()

        // Fire expired snoozes
        let expiredSnoozes = appState.snoozeQueue.filter { $0.fireDate <= now }
        appState.snoozeQueue.removeAll { $0.fireDate <= now }
        for snoozed in expiredSnoozes {
            appState.enqueueEvent(snoozed.event)
        }

        // Fire scheduled alarms (1s tolerance for timer drift)
        while let first = scheduledFires.first, first.fireDate <= now.addingTimeInterval(1) {
            scheduledFires.removeFirst()
            if !appState.firedAlarmKeys.contains(first.key) {
                appState.firedAlarmKeys.insert(first.key)
                appState.enqueueEvent(CalendarEvent(from: first.event))
            }
        }

        scheduleNextFire()
    }
}
