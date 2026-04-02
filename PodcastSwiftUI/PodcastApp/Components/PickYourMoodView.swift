import SwiftUI

// MARK: - Section View

struct PickYourMoodView: View {
    @Binding var selectedMood: PodcastMood?
    let moodEpisodes: [RecentReleasesEntry]
    let isMoodLoading: Bool
    let onSelectMood: (PodcastMood) -> Void

    @State private var showHowItWorks = false
    @State private var navigateToDownloads = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Header ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("Pick Your Mood")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("Fresh picks tuned to your mood.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            // ── Mood picker ──────────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PodcastMood.all) { mood in
                        MoodButton(
                            mood: mood,
                            isSelected: selectedMood?.id == mood.id,
                            onTap: { onSelectMood(mood) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }

            // ── Episode cards ────────────────────────────────────────
            if selectedMood != nil {
                GeometryReader { geo in
                    let cardW = geo.size.width - 72
                    if isMoodLoading {
                        MoodEpisodesSkeleton(cardW: cardW)
                    } else if moodEpisodes.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white.opacity(0.25))
                                Text("No episodes found for this mood.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 40)
                            Spacer()
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(moodEpisodes) { entry in
                                    RecentEpisodeCard(entry: entry, cardW: cardW, navigateToDownloads: $navigateToDownloads)
                                        .scrollTransition(.interactive) { content, phase in
                                            content.scaleEffect(1 - abs(phase.value) * 0.04)
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(height: 226)
            }

            // ── Footer ───────────────────────────────────────────────
            HStack {
                Button {
                    showHowItWorks = true
                } label: {
                    HStack(spacing: 5) {
                        Text("How it works")
                            .font(.system(size: 13))
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                    Text("Powered by Wave Intelligence")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .sheet(isPresented: $showHowItWorks) {
            HowItWorksSheet()
        }
        .navigationDestination(isPresented: $navigateToDownloads) {
            DownloadsView()
        }
    }
}

// MARK: - Mood Button

private struct MoodButton: View {
    let mood: PodcastMood
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Icon inside translucent circle — 20pt padding from top
                ZStack {
                    Circle()
                        .fill(.white.opacity(isSelected ? 0.22 : 0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: mood.icon)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 20)
                .padding(.bottom, 6)

                Text(mood.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.7))
                    .lineLimit(1)
                    .padding(.bottom, 12)

                Spacer(minLength: 0)
            }
            .frame(width: 90, height: 98)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(mood.color.mix(with: .black, by: isSelected ? 0.1 : 0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(isSelected ? 0.18 : 0.05), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}

// MARK: - How It Works Sheet

private struct HowItWorksSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Sparkles icon with pulse ─────────────────────────────
            Image(systemName: "sparkles")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white)
                .scaleEffect(pulse)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.8)
                        .repeatForever(autoreverses: true)
                    ) {
                        pulse = 1.12
                    }
                }

            Spacer().frame(height: 32)

            // ── Text ─────────────────────────────────────────────────
            VStack(spacing: 10) {
                Text("How it works")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text("Wave fetches fresh episodes from top podcasts and trusted publishers throughout the day. Wave Intelligence then maps those episodes to your selected mood and picks the best matches for you.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer().frame(height: 32)

            // ── CTA ──────────────────────────────────────────────────
            Button {
                dismiss()
            } label: {
                Text("Okay, got it")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.white)
            .foregroundStyle(.black)
            .hoverEffect(.highlight)

            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.black.opacity(0.40))
    }
}

// MARK: - Skeleton

private struct MoodEpisodesSkeleton: View {
    let cardW: CGFloat
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .frame(width: cardW, height: 218)
                        .redacted(reason: .placeholder)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
}
