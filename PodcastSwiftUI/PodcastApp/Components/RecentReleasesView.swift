import SwiftUI

// MARK: - Section view

struct RecentReleasesView: View {
    let entries: [RecentReleasesEntry]
    var hasFollowedPodcasts: Bool = true
    @State private var navigateToDownloads = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text("Recent Releases")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Text("Fresh episodes from podcasts you follow.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            GeometryReader { geo in
                let cardW = geo.size.width - 72
                if !hasFollowedPodcasts {
                    // Empty state — user hasn't followed any podcasts yet
                    VStack(spacing: 10) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.25))
                        Text("Follow podcasts to see\nnew episodes here")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if entries.isEmpty {
                    RecentReleasesSkeleton(cardW: cardW)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(entries) { entry in
                                RecentEpisodeCard(entry: entry, cardW: cardW, navigateToDownloads: $navigateToDownloads)
                                    // Jelly / elastic motion as cards enter & leave the viewport.
                                    // .interactive ties the effect to gesture velocity so it
                                    // naturally springs — same physics iOS uses on home-screen icons.
                                    .scrollTransition(.interactive) { content, phase in
                                        content
                                            .scaleEffect(1 - abs(phase.value) * 0.04)
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
        .navigationDestination(isPresented: $navigateToDownloads) {
            DownloadsView()
        }
    }
}

// MARK: - Episode card

struct RecentEpisodeCard: View {
    let entry: RecentReleasesEntry
    let cardW: CGFloat
    @Binding var navigateToDownloads: Bool
    @EnvironmentObject var player: PlayerViewModel
    @ObservedObject private var downloads = DownloadManager.shared

    private let cardH: CGFloat = 218
    @State private var bgColor: Color = .clear
    @State private var isLightBg: Bool = false

    // The card bg is always darkened 55 % toward black so text is always white.
    // Button labels also stay white so they read on both the glass and the bg.

    var body: some View {
        Button {
            player.loadEpisode(entry.episode, from: entry.podcast.summary)
        } label: {
            VStack(alignment: .leading, spacing: 0) {

                // ── Top row: artwork + title + date ──────────────────
                HStack(alignment: .top, spacing: 12) {
                    CachedAsyncImage(url: entry.episode.artworkUrl ?? entry.podcast.artworkURL) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    }
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.episode.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(entry.episode.pubDate.timeAgo())
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // ── Description ───────────────────────────────────────
                Text(entry.episode.plainDescription)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(3)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                Spacer(minLength: 12)

                // ── Action buttons — iOS native glass ─────────────────
                HStack(spacing: 10) {
                    // Inner buttons use .simultaneousGesture so the card tap
                    // and button taps don't conflict.
                    Button {
                        player.loadEpisode(entry.episode, from: entry.podcast.summary)
                    } label: {
                        Label(entry.episode.displayDuration, systemImage: "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                    }
                    .glassEffect(isLightBg ? .regular : .regular.tint(.white.opacity(0.18)), in: .capsule)

                    Button {
                        let state = downloads.downloads[entry.episode.id]
                        switch state {
                        case .downloading:
                            downloads.cancel(episode: entry.episode)
                        case .downloaded:
                            navigateToDownloads = true
                        default:
                            downloads.download(episode: entry.episode)
                        }
                    } label: {
                        downloadButtonLabel(for: downloads.downloads[entry.episode.id])
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                    }
                    .glassEffect(isLightBg ? .regular : .regular.tint(.white.opacity(0.18)), in: .capsule)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(width: cardW, height: cardH)
            // Light artworks: mix 55% toward black (vivid → rich dark tint)
            // Dark artworks:  mix only 25% so they don't collapse to near-black
            .glassEffect(.regular.interactive().tint(bgColor.mix(with: .black, by: isLightBg ? 0.55 : 0.25)),
                         in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        // Native iOS spring press: scale down + dim on press, spring back on release
        .buttonStyle(CardPressStyle())
        .task(id: entry.podcast.id) {
            let result = await ColorExtractor.shared.extract(from: entry.podcast.artworkURL)
            withAnimation(.easeInOut(duration: 0.3)) {
                bgColor    = result.color
                isLightBg  = result.isLight
            }
        }
    }

    @ViewBuilder
    private func downloadButtonLabel(for state: DownloadManager.DownloadState?) -> some View {
        switch state {
        case .none:
            Label("Download", systemImage: "arrow.down.circle")
        case .failed:
            Label("Retry", systemImage: "arrow.clockwise")
        case .downloading(let progress):
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 14, height: 14)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)
                }
                Text("Stop")
            }
        case .downloaded:
            Label("Saved", systemImage: "checkmark.circle.fill")
        }
    }
}

// MARK: - Native card press style
// Replicates the spring-scale + brightness-dim that iOS uses on tappable surfaces.
private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Skeleton

private struct RecentReleasesSkeleton: View {
    let cardW: CGFloat
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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

// MARK: - Date helper

private enum RSSDateParsers {
    static let formatters: [DateFormatter] = {
        ["EEE, dd MMM yyyy HH:mm:ss Z",
         "EEE, dd MMM yyyy HH:mm:ss zzz",
         "yyyy-MM-dd'T'HH:mm:ssZ"].map { fmt in
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            return df
        }
    }()
}

private extension String {
    func timeAgo() -> String {
        var date: Date?
        for df in RSSDateParsers.formatters {
            if let d = df.date(from: self) { date = d; break }
        }
        guard let date else { return self }

        let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: Date())
        if let d = diff.day,    d > 0  { return d == 1  ? "1 day ago"    : "\(d) days ago" }
        if let h = diff.hour,   h > 0  { return h == 1  ? "1 hour ago"   : "\(h) hours ago" }
        if let m = diff.minute, m > 0  { return m == 1  ? "1 min ago"    : "\(m) mins ago" }
        return "Just now"
    }
}
