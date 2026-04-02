import SwiftUI

/// Full-screen splash shown briefly when Walking Mode activates.
/// Static SF Symbol with smooth ripple pulse and haptic feedback.
struct WalkingSplashView: View {
    let onComplete: () -> Void

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0

    private let accentGreen = Color(red: 0.2, green: 0.84, blue: 0.42)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    // Smooth staggered pulse rings using TimelineView
                    PulseRingsView(color: accentGreen)

                    // Static walking figure (smaller so pulse has breathing room)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(accentGreen)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                VStack(spacing: 8) {
                    Text("Walking mode enabled")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Step tracking is now active while your\npodcast keeps playing.")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .opacity(textOpacity)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            // Visual animations
            withAnimation(.easeOut(duration: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                textOpacity = 1.0
            }

            // Dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onComplete()
            }
        }
        .task {
            // Haptic pulse — synced to ring emergence cycle (2s period, 0.5s stagger)
            // Each ring emerges at: 0s, 0.5s, 1.0s then repeats
            let medium = UIImpactFeedbackGenerator(style: .medium)
            let soft   = UIImpactFeedbackGenerator(style: .soft)
            let light  = UIImpactFeedbackGenerator(style: .light)

            // Pre-warm all generators for zero-latency response
            medium.prepare(); soft.prepare(); light.prepare()

            // Ring 1 — strongest pulse (icon + first ring appear together)
            medium.impactOccurred(intensity: 0.9)

            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            soft.prepare()
            // Ring 2 — medium pulse
            soft.impactOccurred(intensity: 0.7)

            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            light.prepare()
            // Ring 3 — softest pulse
            light.impactOccurred(intensity: 0.5)

            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            // Ring 1 wraps around (second cycle) — gentle echo
            light.impactOccurred(intensity: 0.3)
        }
    }
}

// MARK: - Smooth Pulse Rings (TimelineView driven, no glitches)

private struct PulseRingsView: View {
    let color: Color
    private let ringCount = 3
    private let cycleDuration: Double = 2.0
    private let staggerDelay: Double = 0.5

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseRadius: CGFloat = 50

                for i in 0..<ringCount {
                    let offset = Double(i) * staggerDelay
                    let t = ((now + offset).truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration

                    let scale = 0.8 + t * 1.7   // 0.8 → 2.5
                    let opacity = 0.12 * (1.0 - t) // fade out smoothly

                    let r = baseRadius * CGFloat(scale)
                    let rect = CGRect(
                        x: center.x - r,
                        y: center.y - r,
                        width: r * 2,
                        height: r * 2
                    )

                    context.fill(
                        Circle().path(in: rect),
                        with: .color(color.opacity(opacity))
                    )
                }
            }
        }
        .frame(width: 260, height: 260)
    }
}
