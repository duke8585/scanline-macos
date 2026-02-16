import EventKit

final class CalendarService {
    let store = EKEventStore()

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func allCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
    }

    func refreshSources() {
        store.refreshSourcesIfNecessary()
    }

    func events(for calendarIDs: Set<String>, in range: DateInterval) -> [EKEvent] {
        let calendars = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: calendars)
        return store.events(matching: predicate)
    }
}
