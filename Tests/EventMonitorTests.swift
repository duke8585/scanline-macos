import Foundation
import CoreGraphics
import Testing
@testable import CalendarOverlay

@Suite @MainActor
struct EventMonitorTests {
    private let appState: AppState
    private let mockService: MockCalendarService
    private let mockPresenter: MockOverlayPresenter
    private let monitor: EventMonitor

    init() {
        mockService = MockCalendarService()
        mockPresenter = MockOverlayPresenter()
        appState = AppState(calendarService: mockService, overlayPresenter: mockPresenter)
        appState.selectedCalendarIDs = Set(["cal1"])
        monitor = EventMonitor(appState: appState, calendarService: mockService)
    }

    private func makeEvent(id: String = "evt1", startDate: Date = Date()) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: "Test Event",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(3600),
            calendarTitle: "Test Calendar",
            calendarColor: CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        )
    }

    // MARK: - Reminder type tests

    @Test func poll_reminderBeforeEnabled_firesWhenDue() {
        appState.reminderBeforeEnabled = true
        appState.reminderBeforeMinutes = 5
        appState.reminderAtStartEnabled = false
        appState.reminderAfterEnabled = false

        // Event starts in 4min50s → "before" fire time was 10s ago
        let eventStart = Date().addingTimeInterval(4 * 60 + 50)
        mockService.stubbedEvents = [makeEvent(startDate: eventStart)]

        monitor.poll()

        #expect(appState.activeOverlayEvent != nil)
    }

    @Test func poll_reminderAtStartEnabled_firesWhenDue() {
        appState.reminderAtStartEnabled = true
        appState.reminderBeforeEnabled = false
        appState.reminderAfterEnabled = false

        // Event started 10s ago
        let eventStart = Date().addingTimeInterval(-10)
        mockService.stubbedEvents = [makeEvent(startDate: eventStart)]

        monitor.poll()

        #expect(appState.activeOverlayEvent != nil)
    }

    @Test func poll_reminderAfterEnabled_firesWhenDue() {
        appState.reminderAfterEnabled = true
        appState.reminderAfterMinutes = 5
        appState.reminderBeforeEnabled = false
        appState.reminderAtStartEnabled = false

        // Event started 5min10s ago → "after" fire time was 10s ago
        let eventStart = Date().addingTimeInterval(-5 * 60 - 10)
        mockService.stubbedEvents = [makeEvent(startDate: eventStart)]

        monitor.poll()

        #expect(appState.activeOverlayEvent != nil)
    }

    // MARK: - Detection window boundary tests

    @Test func poll_eventAt59SecondsAgo_fires() {
        appState.reminderAtStartEnabled = true
        appState.reminderBeforeEnabled = false
        appState.reminderAfterEnabled = false

        let eventStart = Date().addingTimeInterval(-59)
        mockService.stubbedEvents = [makeEvent(startDate: eventStart)]

        monitor.poll()

        #expect(appState.activeOverlayEvent != nil)
    }

    @Test func poll_eventAt61SecondsAgo_doesNotFire() {
        appState.reminderAtStartEnabled = true
        appState.reminderBeforeEnabled = false
        appState.reminderAfterEnabled = false

        let eventStart = Date().addingTimeInterval(-61)
        mockService.stubbedEvents = [makeEvent(startDate: eventStart)]

        monitor.poll()

        #expect(appState.activeOverlayEvent == nil)
    }

    // MARK: - Future event scheduling

    @Test func poll_futureEvent_addedToScheduledFires() {
        appState.reminderAtStartEnabled = true
        appState.reminderBeforeEnabled = false
        appState.reminderAfterEnabled = false

        let eventStart = Date().addingTimeInterval(600) // 10 min in future
        mockService.stubbedEvents = [makeEvent(startDate: eventStart)]

        monitor.poll()

        #expect(appState.activeOverlayEvent == nil)
        #expect(monitor.scheduledFires.count == 1)
    }

    // MARK: - Deduplication

    @Test func poll_duplicateAlarmKey_doesNotFireTwice() {
        appState.reminderAtStartEnabled = true
        appState.reminderBeforeEnabled = false
        appState.reminderAfterEnabled = false

        let eventStart = Date().addingTimeInterval(-10)
        mockService.stubbedEvents = [makeEvent(id: "dup1", startDate: eventStart)]

        monitor.poll()
        #expect(appState.activeOverlayEvent != nil)
        appState.dismiss()

        // Second poll — same event, key already fired
        monitor.poll()
        #expect(appState.activeOverlayEvent == nil)
    }

    // MARK: - No calendars selected

    @Test func poll_noSelectedCalendars_returnsEarly() {
        appState.selectedCalendarIDs = Set()
        appState.reminderAtStartEnabled = true

        mockService.stubbedEvents = [makeEvent(startDate: Date().addingTimeInterval(-10))]

        monitor.poll()

        #expect(appState.activeOverlayEvent == nil)
        #expect(!mockService.eventsFetched)
    }

    // MARK: - Snooze

    @Test func poll_expiredSnooze_firesImmediately() {
        let event = makeEvent(id: "snoozed1")
        appState.snoozeQueue.append(SnoozedEvent(event: event, fireDate: Date().addingTimeInterval(-1)))

        monitor.poll()

        #expect(appState.activeOverlayEvent != nil)
        #expect(appState.activeOverlayEvent?.id == "snoozed1")
        #expect(appState.snoozeQueue.isEmpty)
    }

    // MARK: - Multiple reminder types

    @Test func poll_allReminderTypes_generates3Keys() {
        appState.reminderBeforeEnabled = true
        appState.reminderBeforeMinutes = 5
        appState.reminderAtStartEnabled = true
        appState.reminderAfterEnabled = true
        appState.reminderAfterMinutes = 5

        // Future event so all 3 are scheduled, not fired
        let eventStart = Date().addingTimeInterval(600) // 10 min from now
        mockService.stubbedEvents = [makeEvent(id: "multi", startDate: eventStart)]

        monitor.poll()

        #expect(monitor.scheduledFires.count == 3)
        let keys = Set(monitor.scheduledFires.map(\.key))
        #expect(keys.contains("multi_before"))
        #expect(keys.contains("multi_start"))
        #expect(keys.contains("multi_after"))
    }
}
