import SwiftUI

// MARK: - Swipeable Pager (carousel / section swipe-between-podcasts)
struct PodcastDetailPagerView: View {
    let podcasts: [PodcastSummary]
    @State private var currentIndex: Int
    @State private var dominantColor: Color = Color(hex: "#2A1A4A")

    init(podcasts: [PodcastSummary], startIndex: Int) {
        self.podcasts = podcasts
        self._currentIndex = State(initialValue: startIndex)
    }

    private var currentPodcast: PodcastSummary { podcasts[currentIndex] }

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(podcasts.enumerated()), id: \.element.id) { idx, podcast in
                PodcastDetailView(podcast: podcast, isActive: idx == currentIndex, pagerColor: $dominantColor)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .background {
            LinearGradient(
                colors: [dominantColor.opacity(0.85), Color(hex: "#0A0A0A")],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.55)
            )
            .overlay(Color(hex: "#0A0A0A").opacity(0.3))
            .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                let shareURL = URL(string: "https://podcasts.apple.com/us/podcast/id\(currentPodcast.id)")!
                Menu {
                    ShareLink(item: shareURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button { } label: {
                        Label("Disable Notifications", systemImage: "bell.slash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}

struct PodcastDetailView: View {
    let podcast: PodcastSummary
    var isActive: Bool = true
    /// When non-nil, the pager owns the background — this view writes its color here instead.
    var pagerColor: Binding<Color>? = nil
    @StateObject private var detailVM = PodcastDetailViewModel()
    @EnvironmentObject var followingStore: FollowingStore
    @EnvironmentObject var player: PlayerViewModel

    @State private var dominantColor: Color = Color(hex: "#2A1A4A")

    private var isInPager: Bool { pagerColor != nil }

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 59
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                DetailHeaderView(
                    podcast: podcast,
                    description: detailVM.feedDescription,
                    latestEpisode: detailVM.episodes.first,
                    topPadding: safeAreaTop + 44
                )

                EpisodesSection(
                    episodes: detailVM.episodes,
                    isLoading: detailVM.isLoading,
                    error: detailVM.error,
                    podcast: podcast,
                    onRetry: {
                        await detailVM.reload(podcastId: podcast.id, podcastName: podcast.name)
                    }
                )

                Color.clear.frame(height: 80)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background {
            // Only render own background when standalone (not in pager)
            if !isInPager {
                LinearGradient(
                    colors: [dominantColor.opacity(0.85), Color(hex: "#0A0A0A")],
                    startPoint: .top,
                    endPoint: .init(x: 0.5, y: 0.55)
                )
                .overlay(Color(hex: "#0A0A0A").opacity(0.3))
                .ignoresSafeArea()
            }
        }
        .onChange(of: isActive) { _, newValue in
            // Pager swipe: fire haptic the moment the new page becomes active.
            // This fires while the swipe gesture is still in progress (finger on screen).
            guard newValue else { return }
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred()
        }
        .task(id: isActive) {
            guard isActive else { return }
            async let colorTask: () = {
                if let url = podcast.artworkURL {
                    let result = await ColorExtractor.shared.extract(from: url)
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            dominantColor = result.color
                            // Forward color to pager's background
                            pagerColor?.wrappedValue = result.color
                        }
                    }
                }
            }()
            async let loadTask: () = detailVM.load(podcastId: podcast.id, podcastName: podcast.name, feedUrl: podcast.feedUrl)
            _ = await (colorTask, loadTask)
        }
    }
}

// MARK: - Header
struct DetailHeaderView: View {
    let podcast: PodcastSummary
    let description: String
    var latestEpisode: RSSEpisode? = nil
    var topPadding: CGFloat = 100

    @EnvironmentObject var followingStore: FollowingStore
    @EnvironmentObject var player: PlayerViewModel
    @State private var appeared = false
    @State private var showAbout = false

    var body: some View {
        VStack(spacing: 12) {
            // Artwork — rotation + blur + scale reveal
            CachedAsyncImage(url: podcast.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.1))
                    .overlay(ProgressView().tint(.white))
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.6), radius: 40, y: 20)
            .padding(.top, topPadding)
            .rotation3DEffect(.degrees(appeared ? 0 : 35), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .blur(radius: appeared ? 0 : 8)
            .scaleEffect(appeared ? 1.0 : 0.82)

            // Title + artist (no genre pill)
            VStack(spacing: 4) {
                Text(podcast.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(podcast.artistName)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 24)

            // Action buttons: Play Latest + heart follow (matching carousel style)
            HStack(spacing: 12) {
                let isFollowing = followingStore.isFollowing(podcast)
                let btnSize: CGFloat = 48

                // Play Latest
                Button(action: {
                    if let episode = latestEpisode {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        player.loadEpisode(episode, from: podcast)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Play Latest")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(latestEpisode != nil ? .white : .white.opacity(0.4))
                    .padding(.horizontal, 22)
                    .frame(height: btnSize)
                    .contentShape(Capsule())
                }
                .glassEffect(.regular.interactive(), in: .capsule)
                .disabled(latestEpisode == nil)

                // Heart follow button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    followingStore.toggleSummary(podcast)
                }) {
                    Image(systemName: isFollowing ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: btnSize, height: btnSize)
                        .contentShape(Circle())
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .scaleEffect(isFollowing ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isFollowing)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            // Description — truncated, tap anywhere to open full About sheet
            if !description.isEmpty {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showAbout = true
                }) {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .sheet(isPresented: $showAbout) {
                    AboutSheet(podcast: podcast, description: description)
                }
            }

            // Language / Category / Website row
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Language")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                    Text("EN")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 36)
                    .background(Color.white.opacity(0.2))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Category")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(podcast.primaryGenre ?? "—")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

                Divider()
                    .frame(height: 36)
                    .background(Color.white.opacity(0.2))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Website")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                    Text("—")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .task(id: podcast.id) {
            // Reset first so pre-rendered TabView pages re-animate when swiped to
            appeared = false
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}

// MARK: - About Sheet
struct AboutSheet: View {
    let podcast: PodcastSummary
    let description: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(podcast.name)
                            .font(.system(size: 22, weight: .bold))
                        Text(podcast.artistName)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }

                    Text(description)
                        .font(.system(size: 16))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Episodes Section
struct EpisodesSection: View {
    let episodes: [RSSEpisode]
    let isLoading: Bool
    let error: String?
    let podcast: PodcastSummary
    var onRetry: (() async -> Void)? = nil
    @EnvironmentObject var player: PlayerViewModel
    @State private var searchText = ""

    private var filteredEpisodes: [RSSEpisode] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return episodes }
        return episodes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.plainDescription.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Native UISearchBar — zero custom styling, iOS applies glass automatically
            NativeSearchBar(text: $searchText, placeholder: "Search episodes...")
                .frame(height: 56)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            if isLoading {
                EpisodeSkeletonList()
            } else if let error {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    if let onRetry {
                        Button("Retry") {
                            Task { await onRetry() }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(20)
            } else if filteredEpisodes.isEmpty && !searchText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No episodes matching \"\(searchText)\"")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredEpisodes.enumerated()), id: \.element.id) { index, episode in
                        EpisodeRow(episode: episode, podcast: podcast)
                        if index < filteredEpisodes.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.08))
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Episode Row
struct EpisodeRow: View {
    let episode: RSSEpisode
    let podcast: PodcastSummary
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var queueStore: QueueStore
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var isPressed = false
    @State private var showDetail = false

    private var downloadState: DownloadManager.DownloadState? {
        downloadManager.downloads[episode.id]
    }

    // Static formatters — created once, reused for every row render
    private static let rssParsers: [DateFormatter] = {
        ["EEE, dd MMM yyyy HH:mm:ss Z",
         "EEE, dd MMM yyyy HH:mm:ss zzz",
         "yyyy-MM-dd'T'HH:mm:ssZ"].map { fmt in
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            return df
        }
    }()
    private static let displayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "d MMM yyyy"
        return df
    }()

    /// Smart relative timestamp: "1d ago", "3h ago" for recent; "15 Mar 2026" for older
    private var smartTimestamp: String {
        var parsed: Date?
        for df in Self.rssParsers {
            if let d = df.date(from: episode.pubDate) { parsed = d; break }
        }
        guard let date = parsed else { return episode.formattedPubDate }
        let diff  = Date().timeIntervalSince(date)
        let mins  = Int(diff / 60)
        let hours = mins / 60
        let days  = hours / 24
        if mins  < 60 { return "\(max(1, mins))m ago" }
        if hours < 24 { return "\(hours)h ago" }
        if days  < 7  { return "\(days)d ago" }
        return Self.displayFormatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: 72×72 thumbnail + timestamp / title
            HStack(alignment: .top, spacing: 14) {
                CachedAsyncImage(url: episode.artworkUrl ?? podcast.artworkURL) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 5) {
                    if !smartTimestamp.isEmpty {
                        Text(smartTimestamp)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    // Title 3 = 20 pt (Apple HIG body-sized heading for cards)
                    Text(episode.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Description — full width, 14 pt
            if !episode.plainDescription.isEmpty {
                Text(episode.plainDescription)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Native glass pill action buttons
            HStack(spacing: 12) {
                // ▶ Play / ⏸ Pause pill
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    player.loadEpisode(episode, from: podcast)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: player.isCurrentEpisode(episode) && player.isPlaying
                              ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .contentTransition(.symbolEffect(.replace))
                        if !episode.displayDuration.isEmpty && episode.displayDuration != "0:00" {
                            Text(episode.displayDuration)
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .contentShape(Capsule())
                }
                .glassEffect(.regular.interactive(), in: .capsule)
                .buttonStyle(.plain)

                // ⬇ Download pill
                Button(action: {
                    if downloadManager.isDownloaded(episode.id) {
                        downloadManager.delete(episode: episode)
                    } else if case .downloading = downloadState {
                        downloadManager.cancel(episode: episode)
                    } else {
                        downloadManager.download(episode: episode)
                    }
                }) {
                    HStack(spacing: 6) {
                        if downloadManager.isDownloaded(episode.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                            Text("Downloaded")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        } else if case .downloading(let progress) = downloadState {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                                    .frame(width: 14, height: 14)
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(Color.accentColor, lineWidth: 1.5)
                                    .frame(width: 14, height: 14)
                                    .rotationEffect(.degrees(-90))
                            }
                            Text("Downloading")
                                .font(.system(size: 14, weight: .medium))
                        } else if case .failed = downloadState {
                            Image(systemName: "exclamationmark.icloud.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.red)
                            Text("Retry")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.red)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Download")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .contentShape(Capsule())
                }
                .glassEffect(.regular.interactive(), in: .capsule)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(isPressed ? Color.white.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { isPressed = false }
                showDetail = true
            }
        }
        .sheet(isPresented: $showDetail) {
            EpisodeDetailSheet(episode: episode, podcast: podcast)
        }
        .contextMenu {
            Button {
                queueStore.playNext(episode, from: podcast)
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }

            Button {
                queueStore.addToQueue(episode, from: podcast)
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }

            Divider()

            if let audioUrl = episode.audioUrl {
                ShareLink(item: audioUrl, subject: Text(episode.title)) {
                    Label("Share Episode", systemImage: "square.and.arrow.up")
                }
            }

            Divider()

            if downloadManager.isDownloaded(episode.id) {
                Button(role: .destructive) {
                    downloadManager.delete(episode: episode)
                } label: {
                    Label("Delete Download", systemImage: "trash")
                }
            } else if case .downloading = downloadState {
                Button(role: .destructive) {
                    downloadManager.cancel(episode: episode)
                } label: {
                    Label("Cancel Download", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    downloadManager.download(episode: episode)
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }
        }
    }
}

// MARK: - Episode Detail Sheet
struct EpisodeDetailSheet: View {
    let episode: RSSEpisode
    let podcast: PodcastSummary
    @EnvironmentObject var player: PlayerViewModel
    @ObservedObject private var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Artwork
                    CachedAsyncImage(url: episode.artworkUrl ?? podcast.artworkURL) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                    // Action pills
                    HStack(spacing: 12) {
                        // Play pill
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            player.loadEpisode(episode, from: podcast)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: player.isCurrentEpisode(episode) && player.isPlaying
                                      ? "pause.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .contentTransition(.symbolEffect(.replace))
                                if !episode.displayDuration.isEmpty && episode.displayDuration != "0:00" {
                                    Text(episode.displayDuration)
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .contentShape(Capsule())
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .buttonStyle(.plain)

                        // Download pill
                        Button {
                            if downloadManager.isDownloaded(episode.id) {
                                downloadManager.delete(episode: episode)
                            } else {
                                downloadManager.download(episode: episode)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if downloadManager.isDownloaded(episode.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                    Text("Downloaded")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.accentColor)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Download")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .contentShape(Capsule())
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .buttonStyle(.plain)
                    }

                    // Title
                    Text(episode.title)
                        .font(.system(size: 22, weight: .bold))

                    // Full description
                    if !episode.plainDescription.isEmpty {
                        Text(episode.plainDescription)
                            .font(.system(size: 16))
                            .lineSpacing(4)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Episode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Native Search Bar
struct NativeSearchBar: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search..."

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UISearchBar {
        let bar = UISearchBar()
        bar.placeholder = placeholder
        bar.delegate = context.coordinator
        // Zero custom styling — let iOS 26 apply its own glass material
        bar.overrideUserInterfaceStyle = .dark
        bar.backgroundImage = UIImage() // removes default gray bar background
        return bar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    class Coordinator: NSObject, UISearchBarDelegate {
        let parent: NativeSearchBar
        init(_ parent: NativeSearchBar) { self.parent = parent }

        func searchBar(_ searchBar: UISearchBar, textDidChange text: String) {
            parent.text = text
        }
        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            searchBar.setShowsCancelButton(true, animated: true)
        }
        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            searchBar.setShowsCancelButton(false, animated: true)
        }
        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            parent.text = ""
            searchBar.resignFirstResponder()
        }
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }
}

// MARK: - Episode Skeleton
struct EpisodeSkeletonList: View {
    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 14) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(shimmer ? 0.1 : 0.05))
                            .frame(width: 72, height: 72)

                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(shimmer ? 0.06 : 0.03))
                                .frame(width: 70, height: 11)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(shimmer ? 0.1 : 0.05))
                                .frame(height: 17)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(shimmer ? 0.08 : 0.04))
                                .frame(width: 160, height: 15)
                        }
                    }
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(shimmer ? 0.06 : 0.03))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(shimmer ? 0.05 : 0.02))
                        .frame(width: 240, height: 12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                if i < 4 {
                    Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

