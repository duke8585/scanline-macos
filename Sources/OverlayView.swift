import SwiftUI

enum OverlayPendingAction: Equatable {
    case dismiss
    case snooze(Int)
}

@Observable
final class OverlayKeyState {
    var showSnoozeOptions = false
    var pendingAction: OverlayPendingAction?
}

struct SnoozeChoice {
    let key: String
    let label: String
    let getMinutes: () -> Int

    static let all: [SnoozeChoice] = [
        .init(key: "1", label: "1 min", getMinutes: { 1 }),
        .init(key: "2", label: "5 min", getMinutes: { 5 }),
        .init(key: "3", label: "10 min", getMinutes: { 10 }),
        .init(key: "4", label: "15 min", getMinutes: { 15 }),
        .init(key: "5", label: "30 min", getMinutes: { 30 }),
        .init(key: "6", label: "1 hour", getMinutes: { 60 }),
        .init(key: "7", label: "2 hours", getMinutes: { 120 }),
        .init(key: "8", label: "4 hours", getMinutes: { 240 }),
        .init(key: "9", label: "tmrw 9:00", getMinutes: { minutesUntilNextDay(hour: 9) }),
        .init(key: "0", label: "tmrw 13:00", getMinutes: { minutesUntilNextDay(hour: 13) }),
    ]

    static func minutesUntilNextDay(hour: Int) -> Int {
        let cal = Calendar.current
        let now = Date()
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        var comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour = hour
        comps.minute = 0
        comps.second = 0
        let target = cal.date(from: comps)!
        return max(1, Int(ceil(target.timeIntervalSince(now) / 60)))
    }
}

struct OverlayView: View {
    let event: CalendarEvent
    let onDismiss: (() -> Void)?
    let onSnooze: ((Int) -> Void)?
    var keyState: OverlayKeyState

    @State private var scaleX: CGFloat = 0.003
    @State private var scaleY: CGFloat = 0.003
    @State private var flashOpacity: Double = 0.0
    @State private var isAnimatingOut = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)

            // Clock - top right, unboxed
            VStack {
                HStack {
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Self.clockFormatter.string(from: context.date))
                            .font(.system(size: 48, weight: .thin, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .overlay { CRTScanlineEffect() }
                    .padding(.trailing, 48)
                    .padding(.top, 48)
                }
                Spacer()
            }

            // Center - meeting info + buttons
            VStack(spacing: 24) {
                // Meeting info box
                VStack(spacing: 12) {
                    Text(event.title)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("\(Self.timeFormatter.string(from: event.startDate)) — \(Self.timeFormatter.string(from: event.endDate))")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(cgColor: event.calendarColor))
                            .frame(width: 10, height: 10)
                        Text(event.calendarTitle)
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    if let notes = event.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .lineLimit(5)
                            .truncationMode(.tail)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12)))

                // Buttons
                if let onDismiss, let onSnooze {
                    HStack(spacing: 16) {
                        Button(action: { animateOut { onDismiss() } }) {
                            shortcutLabel("Dismiss", key: "d")
                                .foregroundStyle(.black)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        Button(action: { keyState.showSnoozeOptions.toggle() }) {
                            shortcutLabel("Snooze", key: "s")
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.4)))
                        }
                        .buttonStyle(.plain)
                    }

                    if keyState.showSnoozeOptions {
                        VStack(spacing: 8) {
                            snoozeRow(Array(SnoozeChoice.all.prefix(5)), onSnooze: onSnooze)
                            snoozeRow(Array(SnoozeChoice.all.suffix(5)), onSnooze: onSnooze, secondary: true)
                        }
                    }
                }
            }
            .padding(48)
        }
        .overlay {
            Color.white.opacity(flashOpacity)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .scaleEffect(x: scaleX, y: scaleY)
        .onAppear {
            withAnimation(.easeOut(duration: 0.225)) {
                scaleX = 1.0
                flashOpacity = 0.7
            } completion: {
                withAnimation(.easeOut(duration: 0.3)) {
                    scaleY = 1.0
                    flashOpacity = 0.0
                }
            }
        }
        .onChange(of: keyState.pendingAction) { _, action in
            guard let action, let onDismiss, let onSnooze else { return }
            switch action {
            case .dismiss:
                animateOut { onDismiss() }
            case .snooze(let minutes):
                animateOut { onSnooze(minutes) }
            }
        }
    }

    private func shortcutLabel(_ text: String, key: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(text)
                .font(.system(size: 18, weight: .semibold))
            (Text("(") + Text(key).underline() + Text(")"))
                .font(.system(size: 12))
                .opacity(0.5)
        }
    }

    private func snoozeRow(_ options: [SnoozeChoice], onSnooze: @escaping (Int) -> Void, secondary: Bool = false) -> some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.key) { option in
                Button(action: { animateOut { onSnooze(option.getMinutes()) } }) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(option.label)
                            .font(.system(size: secondary ? 12 : 14))
                        (Text("(") + Text(option.key).underline() + Text(")"))
                            .font(.system(size: secondary ? 10 : 11))
                            .opacity(0.5)
                    }
                    .foregroundStyle(.white.opacity(secondary ? 0.6 : 1.0))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(secondary ? 0.08 : 0.15), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(secondary ? 0.2 : 0.4)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func animateOut(_ completion: @escaping () -> Void) {
        guard !isAnimatingOut else { return }
        isAnimatingOut = true
        withAnimation(.easeIn(duration: 0.3)) {
            scaleY = 0.003
            flashOpacity = 0.7
        } completion: {
            withAnimation(.easeIn(duration: 0.225)) {
                scaleX = 0.003
                flashOpacity = 0.0
            } completion: {
                completion()
            }
        }
    }
}

// MARK: - CRT Scanline Effect

struct CRTScanlineEffect: View {
    private let lineSpacing: CGFloat = 3
    private let lineOpacity: Double = 0.15

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.black.opacity(lineOpacity)))
                y += lineSpacing
            }
        }
        .allowsHitTesting(false)
    }
}
