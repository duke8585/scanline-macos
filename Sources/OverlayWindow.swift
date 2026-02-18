import AppKit
import SwiftUI

protocol OverlayPresenting {
    func show(event: CalendarEvent, onDismiss: @escaping () -> Void, onSnooze: @escaping (Int) -> Void)
    func close()
}

final class OverlayWindowController: OverlayPresenting {
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private var keyState = OverlayKeyState()

    func show(event: CalendarEvent, onDismiss: @escaping () -> Void, onSnooze: @escaping (Int) -> Void) {
        close()

        keyState = OverlayKeyState()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] nsEvent in
            guard let self else { return nsEvent }
            // Don't intercept Cmd shortcuts (Cmd+Q, etc.)
            if nsEvent.modifierFlags.contains(.command) { return nsEvent }

            // Escape
            if nsEvent.keyCode == 53 {
                onDismiss()
                return nil
            }

            guard let chars = nsEvent.characters?.lowercased() else { return nil }

            if chars == "d" {
                onDismiss()
                return nil
            }
            if chars == "s" {
                self.keyState.showSnoozeOptions.toggle()
                return nil
            }
            if self.keyState.showSnoozeOptions,
               let choice = SnoozeChoice.all.first(where: { $0.key == chars }) {
                onSnooze(choice.getMinutes())
                return nil
            }

            // Consume all other keys to prevent error beep
            return nil
        }

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
                onSnooze: isPrimary ? onSnooze : nil,
                keyState: keyState
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
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        let windowsToClose = windows
        windows.removeAll()
        for window in windowsToClose {
            window.orderOut(nil)
        }
    }
}
