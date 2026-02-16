import AppKit
import CoreImage
import SwiftUI

final class OverlayWindowController {
    private var windows: [NSWindow] = []

    func show(event: CalendarEvent, onDismiss: @escaping () -> Void, onSnooze: @escaping (Int) -> Void) {
        close()

        for screen in NSScreen.screens {
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

            // Desaturation layer between blur and SwiftUI content
            let desatView = NSView(frame: screen.frame)
            desatView.wantsLayer = true
            desatView.autoresizingMask = [.width, .height]
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setDefaults()
                filter.setValue(0.0, forKey: kCIInputSaturationKey)
                desatView.layer?.backgroundFilters = [filter]
            }

            let overlayView = OverlayView(
                event: event,
                onDismiss: onDismiss,
                onSnooze: onSnooze
            )
            let hostingView = NSHostingView(rootView: overlayView)
            hostingView.frame = screen.frame
            hostingView.autoresizingMask = [.width, .height]

            blurView.addSubview(desatView)
            desatView.addSubview(hostingView)
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
