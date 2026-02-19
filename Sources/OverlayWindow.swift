import AppKit
import SwiftUI

protocol OverlayPresenting {
    func show(event: CalendarEvent, onDismiss: @escaping () -> Void, onSnooze: @escaping (Int) -> Void)
    func close()
}

private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class OverlayWindowController: OverlayPresenting {
    private var windows: [NSWindow] = []
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var keyState = OverlayKeyState()

    func show(event: CalendarEvent, onDismiss: @escaping () -> Void, onSnooze: @escaping (Int) -> Void) {
        close()

        keyState = OverlayKeyState()

        // Local monitor: fires when app is active, can consume events
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] nsEvent in
            guard let self else { return nsEvent }
            if nsEvent.modifierFlags.contains(.command) { return nsEvent }
            self.handleKeyEvent(nsEvent)
            return nil
        }

        // Global monitor: fires when app is NOT active (e.g. another app has focus)
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] nsEvent in
            guard let self else { return }
            if nsEvent.modifierFlags.contains(.command) { return }
            self.handleKeyEvent(nsEvent)
        }

        NSApp.setActivationPolicy(.regular)

        for screen in NSScreen.screens {
            let isPrimary = (screen == NSScreen.main)
            let window = KeyableWindow(
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

        DispatchQueue.main.async { [weak self] in
            NSApp.activate()
            self?.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    func close() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        let windowsToClose = windows
        windows.removeAll()
        for window in windowsToClose {
            window.orderOut(nil)
        }
        NSApp.setActivationPolicy(.accessory)
    }

    private func handleKeyEvent(_ nsEvent: NSEvent) {
        if nsEvent.keyCode == 53 {
            keyState.pendingAction = .dismiss
            return
        }

        guard let chars = nsEvent.characters?.lowercased() else { return }

        if chars == "d" {
            keyState.pendingAction = .dismiss
            return
        }
        if chars == "s" {
            keyState.showSnoozeOptions.toggle()
            return
        }
        if keyState.showSnoozeOptions,
           let choice = SnoozeChoice.all.first(where: { $0.key == chars }) {
            keyState.pendingAction = .snooze(choice.getMinutes())
            return
        }
    }
}
