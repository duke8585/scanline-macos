import EventKit

protocol CalendarServiceProtocol {
    func requestAccess() async -> Bool
    func allCalendars() -> [EKCalendar]
    func refreshSources()
    func events(for calendarIDs: Set<String>, in range: DateInterval) -> [CalendarEvent]
}

final class CalendarService: CalendarServiceProtocol {
    let store = EKEventStore()

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            print("[CalendarOverlay] Calendar access error: \(error)")
            return false
        }
    }

    func allCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
    }

    func refreshSources() {
        store.refreshSourcesIfNecessary()
    }

    func events(for calendarIDs: Set<String>, in range: DateInterval) -> [CalendarEvent] {
        let calendars = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: calendars)
        return store.events(matching: predicate).map { CalendarEvent(from: $0) }
    }
}
