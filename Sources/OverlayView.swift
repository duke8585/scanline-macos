import SwiftUI

struct OverlayView: View {
    let event: CalendarEvent
    let onDismiss: () -> Void
    let onSnooze: (Int) -> Void

    @State private var showSnoozeOptions = false
    @State private var scaleX: CGFloat = 0.003
    @State private var scaleY: CGFloat = 0.003
    @State private var flashOpacity: Double = 0.0
    @State private var isAnimatingOut = false

    private static let snoozeOptions: [(label: String, minutes: Int)] = [
        ("1 min", 1), ("2 min", 2), ("3 min", 3), ("5 min", 5),
        ("10 min", 10), ("30 min", 30), ("1 hour", 60), ("2 hours", 120),
        ("4 hours", 240), ("12 hours", 720), ("24 hours", 1440),
    ]

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)

            VStack(spacing: 24) {
                Text(event.title)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("\(Self.timeFormatter.string(from: event.startDate)) — \(Self.timeFormatter.string(from: event.endDate))")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(cgColor: event.calendarColor))
                        .frame(width: 12, height: 12)
                    Text(event.calendarTitle)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                }

                HStack(spacing: 16) {
                    Button(action: { animateOut { onDismiss() } }) {
                        Text("Dismiss")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button(action: { showSnoozeOptions.toggle() }) {
                        Text("Snooze")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.4)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                if showSnoozeOptions {
                    HStack(spacing: 10) {
                        ForEach(Self.snoozeOptions, id: \.minutes) { option in
                            Button(action: { animateOut { onSnooze(option.minutes) } }) {
                                Text(option.label)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.4)))
                            }
                            .buttonStyle(.plain)
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
            // Phase 1: horizontal expand from dot to line + flash
            withAnimation(.easeOut(duration: 0.15)) {
                scaleX = 1.0
                flashOpacity = 0.7
            }
            // Phase 2: vertical expand from line to full + flash fades
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.2)) {
                    scaleY = 1.0
                    flashOpacity = 0.0
                }
            }
        }
    }

    private func animateOut(_ completion: @escaping () -> Void) {
        guard !isAnimatingOut else { return }
        isAnimatingOut = true
        // Phase 1: vertical collapse + flash
        withAnimation(.easeIn(duration: 0.2)) {
            scaleY = 0.003
            flashOpacity = 0.7
        }
        // Phase 2: horizontal collapse to dot + flash fades
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.15)) {
                scaleX = 0.003
                flashOpacity = 0.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            completion()
        }
    }
}
