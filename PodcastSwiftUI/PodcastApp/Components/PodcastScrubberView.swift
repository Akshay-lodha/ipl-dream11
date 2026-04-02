import SwiftUI

/// Apple Podcasts–style scrubber bar.
///
/// Behavior:
/// - Chapter segments shown as separate bars with gaps on appear, then gaps animate closed
/// - Tap: activates scrubber state, reveals chapter name (does NOT jump)
/// - Drag left/right: scrubs through episode with continuous haptic ticks
/// - Drag down while scrubbing: precision (quarter-speed) mode
/// - No thumb knob — only the bar fill state changes
/// - Time label color brightens when active
/// - Whole component expands wider and taller when active (padding shrinks)
struct PodcastScrubberView: View {
    @Binding var currentTime: Double
    let totalTime: Double
    @Binding var isScrubbing: Bool
    let formattedCurrentTime: String
    let formattedRemainingTime: String
    let chapters: [PodcastChapter]
    let onSeek: (Double) -> Void

    // MARK: - State
    @State private var isActive = false
    @State private var scrubTime: Double = 0
    @State private var dragStartX: CGFloat = 0
    @State private var dragStartTime: Double = 0
    @State private var dragStartY: CGFloat = 0
    @State private var isPrecision = false
    @State private var showChapterGaps = false
    @State private var hasDragged = false
    @State private var lastHapticProgress: CGFloat = 0

    // MARK: - Constants
    private let inactiveHeight: CGFloat = 6
    private let activeHeight: CGFloat = 16
    private let gapWidth: CGFloat = 4
    private let precisionThreshold: CGFloat = 50
    private let hapticProgressStep: CGFloat = 0.015

    /// Horizontal padding shrinks when active so the scrubber stretches wider
    private let inactivePadding: CGFloat = 24
    private let activePadding: CGFloat = 16

    // Haptic generator
    private let scrubHaptic = UISelectionFeedbackGenerator()

    private var safeTotalTime: Double { max(totalTime, 1) }
    private var displayTime: Double { isActive ? scrubTime : currentTime }
    /// Progress clamped to 0…1. Returns 0 when totalTime is unknown to prevent jumps.
    private var progress: CGFloat {
        guard totalTime > 0 else { return 0 }
        return min(max(CGFloat(displayTime / safeTotalTime), 0), 1)
    }
    private var trackHeight: CGFloat { isActive ? activeHeight : inactiveHeight }
    private var horizontalPadding: CGFloat { isActive ? activePadding : inactivePadding }

    /// Current chapter based on displayTime
    private var currentChapter: PodcastChapter? {
        guard !chapters.isEmpty else { return nil }
        return chapters.last(where: { $0.startTime <= displayTime })
    }

    /// Status text shown in center
    private var centerText: String? {
        if isPrecision { return "Fine Scrubbing" }
        if isActive, let chapter = currentChapter { return chapter.title }
        return nil
    }

    /// Timer text color — full white when active
    private var timeColor: Color {
        isActive ? .white : .white.opacity(0.45)
    }

    var body: some View {
        // Fixed spacing between track and timestamps — both move together
        VStack(spacing: 6) {
            // MARK: - Track
            GeometryReader { geo in
                let width = geo.size.width

                Group {
                    if chapters.count > 1 {
                        chapterSegments(totalWidth: width)
                    } else {
                        singleBar(totalWidth: width)
                    }
                }
                .frame(width: width, height: geo.size.height)
                .contentShape(Rectangle().inset(by: -20))
                .gesture(scrubGesture(trackWidth: width))
            }
            // Constant outer frame prevents layout shift; inner track animates within it
            .frame(height: activeHeight)

            // MARK: - Time labels + center info
            HStack(spacing: 0) {
                Text(formattedCurrentTime)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(timeColor)
                    .fixedSize()

                Spacer(minLength: 4)

                if let text = centerText {
                    Text(text)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .transition(.opacity)
                        .layoutPriority(-1)
                }

                Spacer(minLength: 4)

                Text(formattedRemainingTime)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(timeColor)
                    .fixedSize()
            }
            .animation(.easeInOut(duration: 0.2), value: centerText != nil)
        }
        .padding(.horizontal, horizontalPadding)
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .onChange(of: chapters.count) { oldCount, newCount in
            if newCount > 1 && oldCount != newCount {
                animateChapterGapsReveal()
            }
        }
        .onAppear {
            if chapters.count > 1 {
                animateChapterGapsReveal()
            }
        }
    }

    // MARK: - Single bar (no chapters)

    @ViewBuilder
    private func singleBar(totalWidth: CGFloat) -> some View {
        let h = trackHeight
        let fillWidth = max(0, totalWidth * progress)

        Capsule()
            .fill(.white.opacity(0.2))
            .frame(width: totalWidth, height: h)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(.white)
                    .frame(width: fillWidth, height: h)
            }
            .clipShape(Capsule())
            .frame(maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Chapter segments
    //
    // One continuous Capsule bar with thin vertical gap lines overlaid at chapter
    // boundaries. This matches Apple Podcasts where the bar looks like a single
    // rounded track sliced by razor-thin cuts — not individual pills.
    // Because positions are derived from chapter times (not HStack spacing),
    // toggling gap visibility never shifts segment positions.

    @ViewBuilder
    private func chapterSegments(totalWidth: CGFloat) -> some View {
        let h = trackHeight
        let fillWidth = max(0, totalWidth * progress)
        let gapOpacity: Double = showChapterGaps ? 1.0 : 0.0

        // Background track
        Capsule()
            .fill(.white.opacity(0.2))
            .frame(width: totalWidth, height: h)
            .overlay(alignment: .leading) {
                // Filled portion
                Rectangle()
                    .fill(.white)
                    .frame(width: fillWidth, height: h)
            }
            .overlay {
                // Vertical gap lines punched through the bar at chapter boundaries
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    if index > 0 {
                        let xFraction = CGFloat(chapter.startTime / safeTotalTime)
                        Rectangle()
                            .fill(.white)
                            .frame(width: 2, height: h)
                            .opacity(gapOpacity)
                            .position(x: totalWidth * xFraction, y: h / 2)
                            .blendMode(.destinationOut)
                    }
                }
            }
            .compositingGroup()
            .clipShape(Capsule())
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.easeInOut(duration: 0.6), value: showChapterGaps)
    }

    // MARK: - Chapter gap reveal animation
    // Starts hidden → fades in after a short delay → fades back out

    private func animateChapterGapsReveal() {
        showChapterGaps = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.4)) {
                showChapterGaps = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showChapterGaps = false
                }
            }
        }
    }

    // MARK: - Gesture

    private func scrubGesture(trackWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isActive {
                    isActive = true
                    isScrubbing = true
                    scrubTime = currentTime
                    dragStartX = value.startLocation.x
                    dragStartTime = currentTime
                    dragStartY = value.startLocation.y
                    isPrecision = false
                    hasDragged = false
                    lastHapticProgress = progress

                    scrubHaptic.prepare()

                    if chapters.count > 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showChapterGaps = true
                        }
                    }

                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    return
                }

                if abs(value.translation.width) > 6 {
                    hasDragged = true
                }

                let verticalDelta = value.location.y - dragStartY
                let wasPrecision = isPrecision
                isPrecision = verticalDelta > precisionThreshold

                if isPrecision && !wasPrecision {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }

                guard hasDragged else { return }

                let speed: CGFloat = isPrecision ? 0.25 : 1.0
                let dragDelta = value.location.x - dragStartX
                let timeDelta = Double(dragDelta * speed / trackWidth) * safeTotalTime

                scrubTime = max(0, min(safeTotalTime, dragStartTime + timeDelta))
                // Don't update currentTime binding during drag — only scrubTime
                // (displayTime already returns scrubTime when isActive)
                // This prevents full view hierarchy re-renders on every gesture frame

                let currentProgress = CGFloat(scrubTime / safeTotalTime)
                if abs(currentProgress - lastHapticProgress) >= hapticProgressStep {
                    scrubHaptic.selectionChanged()
                    lastHapticProgress = currentProgress
                }
            }
            .onEnded { _ in
                if hasDragged {
                    onSeek(scrubTime)
                }

                // Immediately animate back to normal state on release
                withAnimation(.easeOut(duration: 0.3)) {
                    isActive = false
                }
                if chapters.count > 1 {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showChapterGaps = false
                    }
                }

                isScrubbing = false
                isPrecision = false
                hasDragged = false
            }
    }
}
