import Foundation
import CoreGraphics
import Testing
@testable import CalendarOverlay

@Suite @MainActor
struct AppStateTests {
    private let appState: AppState
    private let mockPresenter: MockOverlayPresenter

    init() {
        mockPresenter = MockOverlayPresenter()
        appState = AppState(
            calendarService: MockCalendarService(),
            overlayPresenter: mockPresenter
        )
    }

    private func makeEvent(id: String = "test-\(UUID().uuidString)", title: String = "Test") -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarTitle: "Test Calendar",
            calendarColor: CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        )
    }

    @Test func enqueueWhenNoActiveOverlay_setsActiveOverlayEvent() {
        let event = makeEvent(id: "e1")
        appState.enqueueEvent(event)
        #expect(appState.activeOverlayEvent?.id == event.id)
        #expect(appState.eventQueue.isEmpty)
    }

    @Test func enqueueWhenOverlayActive_addsToQueue() {
        let event1 = makeEvent(id: "e1")
        let event2 = makeEvent(id: "e2")
        appState.enqueueEvent(event1)
        appState.enqueueEvent(event2)
        #expect(appState.activeOverlayEvent?.id == "e1")
        #expect(appState.eventQueue.count == 1)
        #expect(appState.eventQueue.first?.id == "e2")
    }

    @Test func dismiss_clearsActiveOverlay() {
        appState.enqueueEvent(makeEvent())
        appState.dismiss()
        #expect(appState.activeOverlayEvent == nil)
    }

    @Test func dismiss_showsNextQueued() {
        appState.enqueueEvent(makeEvent(id: "e1"))
        appState.enqueueEvent(makeEvent(id: "e2"))
        appState.dismiss()
        #expect(appState.activeOverlayEvent?.id == "e2")
    }

    @Test func dismiss_emptyQueue_activeOverlayIsNil() {
        appState.enqueueEvent(makeEvent())
        appState.dismiss()
        #expect(appState.activeOverlayEvent == nil)
        #expect(appState.eventQueue.isEmpty)
    }

    @Test func snooze_addsToSnoozeQueueWithCorrectFireDate() {
        let event = makeEvent(id: "s1")
        appState.enqueueEvent(event)
        let before = Date()
        appState.snooze(minutes: 5)
        let after = Date()

        #expect(appState.snoozeQueue.count == 1)
        #expect(appState.snoozeQueue.first?.event.id == event.id)
        let fireDate = appState.snoozeQueue.first!.fireDate
        #expect(fireDate >= before.addingTimeInterval(300))
        #expect(fireDate <= after.addingTimeInterval(300))
    }

    @Test func snooze_clearsActiveOverlay() {
        appState.enqueueEvent(makeEvent())
        appState.snooze(minutes: 1)
        #expect(appState.activeOverlayEvent == nil)
    }

    @Test func snooze_showsNextQueued() {
        appState.enqueueEvent(makeEvent(id: "e1"))
        appState.enqueueEvent(makeEvent(id: "e2"))
        appState.snooze(minutes: 1)
        #expect(appState.activeOverlayEvent?.id == "e2")
    }

    @Test func multipleEnqueues_preserveFIFOOrder() {
        let events = (1...5).map { makeEvent(id: "e\($0)") }
        for event in events {
            appState.enqueueEvent(event)
        }
        #expect(appState.activeOverlayEvent?.id == "e1")
        #expect(appState.eventQueue.map(\.id) == ["e2", "e3", "e4", "e5"])
    }
}
