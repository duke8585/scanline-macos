import AppKit
import SwiftUI

protocol OverlayPresenting {
    func show(event: CalendarEvent, onDismiss: @escaping () -> Void, onSnooze: @escaping (Int) -> Void)
    func close()
}

final class OverlayWindowController: OverlayPresenting {
    private var windows: [NSWindow] = []

    func show(event: CalendarEvent, onDismiss: @escaping () -> Void, onSnooze: @escaping (Int) -> Void) {
        close()

        for screen in NSScreen.screens {
            let isPrimary = (screen == NSScreen.main)
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let blurView = NSVisualEffectView(frame: screen.frame)
            blurView.material = .hudWindow
            blurView.appearance = NSAppearance(named: .darkAqua)
            blurView.blendingMode = .behindWindow
            blurView.state = .active
            blurView.autoresizingMask = [.width, .height]

            let overlayView = OverlayView(
                event: event,
                onDismiss: isPrimary ? onDismiss : nil,
                onSnooze: isPrimary ? onSnooze : nil
            )
            let hostingView = NSHostingView(rootView: overlayView)
            hostingView.frame = screen.frame
            hostingView.autoresizingMask = [.width, .height]

            blurView.addSubview(hostingView)
            window.contentView = blurView
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
    }

    func close() {
        let windowsToClose = windows
        windows.removeAll()
        for window in windowsToClose {
            window.orderOut(nil)
        }
    }
}
