import EventKit
@testable import CalendarOverlay

final class MockCalendarService: CalendarServiceProtocol {
    var stubbedEvents: [CalendarEvent] = []
    var accessGranted: Bool = true
    private(set) var eventsFetched: Bool = false

    func requestAccess() async -> Bool {
        accessGranted
    }

    func allCalendars() -> [EKCalendar] {
        []
    }

    func refreshSources() {}

    func events(for calendarIDs: Set<String>, in range: DateInterval) -> [CalendarEvent] {
        eventsFetched = true
        return stubbedEvents
    }
}
