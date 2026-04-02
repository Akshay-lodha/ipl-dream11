import SwiftUI

extension Notification.Name {
    static let navigateToPodcastFromPlayer = Notification.Name("navigateToPodcastFromPlayer")
}

struct MiniPlayerView: View {
    @ObservedObject var player: PlayerViewModel
    @Binding var showFullPlayer: Bool

    // MARK: - Display Helpers

    private var displayTitle: String {
        if player.hasLoadedEpisode { return player.currentEpisodeTitle }
        return player.recentlyPlayed.first?.episode.title ?? ""
    }

    private var displaySubtitle: String {
        if player.hasLoadedEpisode {
            return player.formattedCurrentTime + " · " + player.formattedTotalTime
        }
        if let entry = player.recentlyPlayed.first {
            if let positions = UserDefaults.standard.dictionary(forKey: "savedPlaybackPositions") as? [String: Double],
               let pos = positions[entry.episode.id] {
                let mins = Int(pos) / 60
                let secs = Int(pos) % 60
                if let dur = Double(entry.episode.duration), dur > 0 {
                    let totalMins = Int(dur) / 60
                    let totalSecs = Int(dur) % 60
                    return String(format: "%d:%02d · %d:%02d", mins, secs, totalMins, totalSecs)
                }
                return String(format: "%d:%02d", mins, secs)
            }
            return entry.episode.displayDuration
        }
        return ""
    }

    private var displayArtworkURL: URL? {
        if player.hasLoadedEpisode { return player.artworkURL }
        return player.recentlyPlayed.first?.episode.artworkUrl ?? player.recentlyPlayed.first?.podcast.artworkURL
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Tappable area: artwork + title → opens full player
            Button {
                if !player.hasLoadedEpisode, let entry = player.recentlyPlayed.first {
                    player.loadEpisode(entry.episode, from: entry.podcast, autoPlay: false)
                }
                showFullPlayer = true
            } label: {
                HStack(spacing: 12) {
                    // Artwork
                    Group {
                        if let url = displayArtworkURL {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1))
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1))
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Title + time
                    VStack(alignment: .leading, spacing: 1) {
                        Text(displayTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(displaySubtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Play / Pause — separate hit target
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if player.hasLoadedEpisode {
                    player.togglePlayback()
                } else if let entry = player.recentlyPlayed.first {
                    player.loadEpisode(entry.episode, from: entry.podcast)
                }
            } label: {
                if player.isBuffering {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 36, height: 36)
                }
            }
            .buttonStyle(.plain)

            // Skip 30 — separate hit target
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if player.hasLoadedEpisode {
                    player.skipForward()
                } else if let entry = player.recentlyPlayed.first {
                    player.loadEpisode(entry.episode, from: entry.podcast)
                }
            } label: {
                Image(systemName: "30.arrow.trianglehead.clockwise")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Full Player Sheet
struct FullPlayerView: View {
    @ObservedObject var player: PlayerViewModel
    @EnvironmentObject var queueStore: QueueStore
    @ObservedObject private var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showSleepTimer = false
    @State private var showQueue = false
    @State private var showChapters = false
    @State private var showPlaybackEffects = false
    @State private var showBookmark = false

    /// Darker version of the dominant color for the gradient bottom
    private var darkColor: Color {
        Color(UIColor(player.artworkColor).adjusted(brightness: 0.15))
    }

    /// Static fade mask for description scroll — doesn't depend on artworkColor
    /// so it never triggers re-renders during scroll
    private var descriptionFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom)
                .frame(height: 16)
            Color.white
            LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 16)
        }
    }

    var body: some View {
        if player.isWalkingMode {
            WalkingModeView(player: player, viewModel: player.walkingViewModel) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    player.isWalkingMode = false
                }
            }
            .id(player.walkSessionId) // Forces view recreation on each new walk
            .presentationDragIndicator(.visible)
            .presentationDetents([.large])
            .presentationCornerRadius(20)
        } else {
        VStack(spacing: 0) {
            // MARK: Top section — artwork, title, description
            Group {
                if let url = player.artworkURL {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                }
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 30, y: 16)
            .scaleEffect(player.isPlaying ? 1.0 : 0.9)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: player.isPlaying)
            .padding(.bottom, 24)

            Button {
                // Dismiss sheet, then navigate to podcast detail
                if player.currentPodcast != nil {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        NotificationCenter.default.post(
                            name: .navigateToPodcastFromPlayer,
                            object: player.currentPodcast
                        )
                    }
                }
            } label: {
                Text(player.currentPodcastTitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)

            Text(player.currentEpisodeTitle)
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            // Scrollable description with edge fades
            if !player.currentEpisodeDescription.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(player.currentEpisodeDescription)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .scrollBounceBehavior(.basedOnSize)
                .mask(descriptionFadeMask)
                .frame(maxHeight: .infinity)
                .padding(.bottom, 12)
            } else {
                Spacer()
            }

            // MARK: Bottom section — pills, slider, controls

            // Action pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    actionPill(icon: "bookmark", label: "Bookmark") {
                        showBookmark = true
                    }

                    actionPill(icon: "figure.walk", label: "Walk") {
                        player.walkSessionId += 1
                        withAnimation(.easeInOut(duration: 0.3)) {
                            player.isWalkingMode = true
                        }
                    }

                    actionPill(icon: "list.bullet", label: "Queue",
                               tint: !queueStore.items.isEmpty ? Color.accentColor : nil) {
                        showQueue = true
                    }

                    if !player.chapters.isEmpty {
                        actionPill(icon: "list.number", label: "Chapters", tint: Color.accentColor) {
                            showChapters = true
                        }
                    }

                    let isDownloaded = downloadManager.isDownloaded(player.currentEpisodeId)
                    actionPill(icon: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle",
                               label: isDownloaded ? "Downloaded" : "Download",
                               tint: isDownloaded ? Color.accentColor : nil) {
                        if !isDownloaded,
                           let entry = player.recentlyPlayed.first(where: { $0.episode.id == player.currentEpisodeId }) {
                            downloadManager.download(episode: entry.episode)
                        }
                    }

                    if let entry = player.recentlyPlayed.first(where: { $0.episode.id == player.currentEpisodeId }),
                       let audioUrl = entry.episode.audioUrl {
                        ShareLink(item: audioUrl) {
                            pillLabel(icon: "square.and.arrow.up", label: "Share")
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
            }
            .scrollClipDisabled()
            .padding(.bottom, 22)

            // Progress scrubber (Apple Podcasts style)
            PodcastScrubberView(
                currentTime: $player.currentTime,
                totalTime: player.totalTime,
                isScrubbing: $player.isScrubbing,
                formattedCurrentTime: player.formattedCurrentTime,
                formattedRemainingTime: player.formattedRemainingTime,
                chapters: player.chapters,
                onSeek: { player.seek(to: $0) }
            )
            .padding(.bottom, 28)

            // Playback controls: Speed | ⏪ | ▶ | ⏩ | 🌙
            HStack(spacing: 0) {
                Button(action: { showPlaybackEffects = true }) {
                    Text(player.playbackRateLabel)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(player.playbackRate == 1.0
                                         ? .white.opacity(0.6)
                                         : Color.accentColor)
                        .frame(width: 44, height: 36)
                }

                Spacer()

                Button(action: { player.skipBackward() }) {
                    Image(systemName: "gobackward.\(player.skipBackInterval)")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }

                Spacer()

                Button(action: player.togglePlayback) {
                    if player.isBuffering {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.3)
                            .frame(width: 56, height: 56)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 56, height: 56)
                    }
                }

                Spacer()

                Button(action: { player.skipForward() }) {
                    Image(systemName: "goforward.\(player.skipForwardInterval)")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }

                Spacer()

                Button(action: { showSleepTimer = true }) {
                    VStack(spacing: 1) {
                        Image(systemName: player.sleepTimerRemaining != nil
                              ? "moon.fill" : "moon.zzz")
                            .font(.system(size: 22))
                            .foregroundStyle(player.sleepTimerRemaining != nil
                                             ? Color.accentColor
                                             : .white.opacity(0.6))
                        if !player.sleepTimerLabel.isEmpty {
                            Text(player.sleepTimerLabel)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(width: 44, height: 36)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .background(
            LinearGradient(
                colors: [darkColor, Color(UIColor(player.artworkColor).adjusted(brightness: 0.35, saturationScale: 0.7))],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: player.artworkColor.description)
        )
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationCornerRadius(20)
        .sheet(isPresented: $showQueue) {
            QueueSheet(queueStore: queueStore)
        }
        .sheet(isPresented: $showChapters) {
            ChaptersSheet(player: player)
        }
        .sheet(isPresented: $showPlaybackEffects) {
            PlaybackEffectsSheet(player: player)
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerSheet(player: player)
        }
        .sheet(isPresented: $showBookmark) {
            BookmarkSheet(player: player)
        }
        } // end else (normal player)
    }

    // MARK: - Pill Helpers

    @ViewBuilder
    private func pillLabel(icon: String, label: String, tint: Color? = nil) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(tint ?? .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contentShape(Capsule())
    }

    private func actionPill(icon: String, label: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pillLabel(icon: icon, label: label, tint: tint)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .buttonStyle(.plain)
    }
}

// MARK: - Queue Sheet
struct QueueSheet: View {
    @ObservedObject var queueStore: QueueStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                if queueStore.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Queue is empty")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(queueStore.items) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.episode.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Text(item.podcast.name)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .listRowBackground(Color.white.opacity(0.08))
                        }
                        .onDelete { queueStore.remove(at: $0) }
                        .onMove { queueStore.move(from: $0, to: $1) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Up Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.accentColor)
                }
                if !queueStore.items.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") { queueStore.items.removeAll() }
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Chapters Sheet
struct ChaptersSheet: View {
    @ObservedObject var player: PlayerViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                List(player.chapters) { chapter in
                    Button(action: {
                        player.seek(to: chapter.startTime)
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Text(formatTime(chapter.startTime))
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 60, alignment: .leading)

                            Text(chapter.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                    }
                    .listRowBackground(
                        player.currentTime >= chapter.startTime &&
                        (player.chapters.last?.id == chapter.id ||
                         player.currentTime < (player.chapters.first(where: { $0.startTime > chapter.startTime })?.startTime ?? Double.infinity))
                        ? Color.accentColor.opacity(0.15)
                        : Color(hex: "#1C1C1E")
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
