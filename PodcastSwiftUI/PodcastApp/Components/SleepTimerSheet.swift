import SwiftUI

/// Sleep timer sheet matching Apple Podcasts design.
/// Features a horizontal ruler/dial scrubber with tick marks, large minute display,
/// and native Start/Turn Off button.
struct SleepTimerSheet: View {
    @ObservedObject var player: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMinutes: Int = 5

    private var isTimerActive: Bool {
        player.sleepTimerRemaining != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // MARK: - Large Display Label
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if selectedMinutes == 0 {
                        Text("Off")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    } else {
                        Text("\(selectedMinutes)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("MIN")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: selectedMinutes)

                // Active timer status
                if isTimerActive {
                    let remaining = Int(player.sleepTimerRemaining ?? 0)
                    let m = remaining / 60
                    let s = remaining % 60
                    Text("Active: \(m)m\(s > 0 ? " \(s)s" : "") remaining")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }

                Spacer()
                    .frame(height: 20)

                // MARK: - Horizontal Ruler Scrubber
                HorizontalRulerPicker(
                    value: $selectedMinutes,
                    range: 0...60,
                    majorEvery: 5
                )
                .frame(height: 80)

                Spacer()
                    .frame(minHeight: 16, maxHeight: 40)

                // MARK: - Action Button (native iOS 26 glass)
                Button {
                    if selectedMinutes > 0 {
                        player.setSleepTimer(minutes: Double(selectedMinutes))
                    } else {
                        player.setSleepTimer(minutes: nil)
                    }
                    dismiss()
                } label: {
                    if selectedMinutes > 0 {
                        Label(buttonLabel, systemImage: "moon.zzz.fill")
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(buttonLabel)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.extraLarge)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let remaining = player.sleepTimerRemaining {
                selectedMinutes = max(1, Int(remaining / 60))
            }
        }
    }

    private var buttonLabel: String {
        if isTimerActive && selectedMinutes == 0 {
            return "Turn Off Timer"
        }
        return selectedMinutes == 0 ? "Turn Off Timer" : "Start"
    }
}

// MARK: - Horizontal Ruler Picker

/// A horizontal ruler/dial picker with tick marks, center indicator, and snap behavior.
/// Mimics the Apple Podcasts sleep timer dial.
struct HorizontalRulerPicker: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let majorEvery: Int

    private let tickSpacing: CGFloat = 12
    private let majorTickHeight: CGFloat = 30
    private let minorTickHeight: CGFloat = 14
    private let labelOffset: CGFloat = 14

    @State private var dragOffset: CGFloat = 0
    @State private var baseOffset: CGFloat = 0
    @GestureState private var isDragging: Bool = false
    @State private var lastHapticValue: Int = -1

    private let haptic = UISelectionFeedbackGenerator()

    private var tickCount: Int { range.upperBound - range.lowerBound }

    private func offsetForValue(_ val: Int) -> CGFloat {
        CGFloat(val - range.lowerBound) * tickSpacing
    }

    private func valueForOffset(_ offset: CGFloat) -> Int {
        let index = Int(round(offset / tickSpacing))
        return min(max(range.lowerBound + index, range.lowerBound), range.upperBound)
    }

    private func clamp(_ offset: CGFloat) -> CGFloat {
        let maxOffset = CGFloat(tickCount) * tickSpacing
        return min(max(offset, 0), maxOffset)
    }

    var body: some View {
        GeometryReader { geo in
            let halfWidth = geo.size.width / 2
            let currentOffset = clamp(baseOffset + dragOffset)
            let rulerCenterY = (geo.size.height - labelOffset) / 2

            ZStack {
                // MARK: Tick marks and labels
                Canvas { context, size in
                    for i in 0...tickCount {
                        let tickValue = range.lowerBound + i
                        let x = halfWidth - currentOffset + CGFloat(i) * tickSpacing

                        // Cull off-screen ticks
                        guard x > -30 && x < size.width + 30 else { continue }

                        let isMajor = tickValue % majorEvery == 0

                        // Fade based on distance from center
                        let distFromCenter = abs(x - halfWidth)
                        let normalizedDist = min(distFromCenter / halfWidth, 1.0)
                        let opacity = max(1.0 - normalizedDist * 1.3, 0.05)

                        let tickH = isMajor ? majorTickHeight : minorTickHeight
                        let tickW: CGFloat = isMajor ? 1.5 : 1.0

                        // Draw tick
                        let tickRect = CGRect(
                            x: x - tickW / 2,
                            y: rulerCenterY - tickH / 2,
                            width: tickW,
                            height: tickH
                        )
                        context.fill(
                            Path(tickRect),
                            with: .color(.primary.opacity(opacity))
                        )

                        // Draw label for major ticks
                        if isMajor {
                            let label = tickValue == 0 ? "Off" : "\(tickValue)"
                            let text = Text(label)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.secondary.opacity(opacity))
                            let resolved = context.resolve(text)
                            context.draw(
                                resolved,
                                at: CGPoint(x: x, y: rulerCenterY + tickH / 2 + labelOffset),
                                anchor: .center
                            )
                        }
                    }
                }

                // MARK: Center indicator
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: majorTickHeight + 12)
                    .position(x: halfWidth, y: rulerCenterY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { gesture in
                        haptic.prepare()
                        dragOffset = -gesture.translation.width
                        let newVal = valueForOffset(clamp(baseOffset + dragOffset))
                        if newVal != value {
                            value = newVal
                            if newVal != lastHapticValue {
                                haptic.selectionChanged()
                                lastHapticValue = newVal
                            }
                        }
                    }
                    .onEnded { _ in
                        baseOffset = clamp(baseOffset + dragOffset)
                        dragOffset = 0
                        // Snap to nearest
                        let snapped = offsetForValue(value)
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                            baseOffset = snapped
                        }
                    }
            )
            .onAppear {
                baseOffset = offsetForValue(value)
            }
        }
    }
}
