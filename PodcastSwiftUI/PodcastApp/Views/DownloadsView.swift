import SwiftUI

struct DownloadsView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    @EnvironmentObject var player: PlayerViewModel

    private var episodes: [RSSEpisode] {
        downloadManager.downloadedEpisodes.values
            .sorted { $0.pubDate > $1.pubDate }
    }

    var body: some View {
        Group {
            if episodes.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - List

    private var list: some View {
        List {
            Section {
                ForEach(episodes) { episode in
                    DownloadedEpisodeRow(episode: episode)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .onDelete { indexSet in
                    for i in indexSet {
                        downloadManager.delete(episode: episodes[i])
                    }
                }
            } header: {
                Text("\(episodes.count) episode\(episodes.count == 1 ? "" : "s") · \(downloadManager.totalSizeFormatted)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
            Text("No Downloads")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            Text("Episodes you download will appear here.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Row

private struct DownloadedEpisodeRow: View {
    let episode: RSSEpisode
    @ObservedObject private var downloadManager = DownloadManager.shared
    @EnvironmentObject var player: PlayerViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            CachedAsyncImage(url: episode.artworkUrl) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(episode.podcastTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(episode.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(episode.displayDuration)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Play button
            Button {
                if let localURL = downloadManager.localURL(for: episode.id) {
                    player.loadLocalEpisode(episode, localURL: localURL)
                }
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                downloadManager.delete(episode: episode)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
