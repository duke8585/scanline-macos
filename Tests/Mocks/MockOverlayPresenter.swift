@testable import CalendarOverlay

final class MockOverlayPresenter: OverlayPresenting {
    private(set) var showCallCount: Int = 0
    private(set) var closeCallCount: Int = 0
    private(set) var lastShownEvent: CalendarEvent?

    func show(event: CalendarEvent, onDismiss: @escaping () -> Void, onSnooze: @escaping (Int) -> Void) {
        showCallCount += 1
        lastShownEvent = event
    }

    func close() {
        closeCallCount += 1
    }
}
