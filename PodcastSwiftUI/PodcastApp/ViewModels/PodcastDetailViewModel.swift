import SwiftUI

// In-memory cache shared across all detail pages — avoids repeat iTunes lookups on swipe
private actor FeedUrlCache {
    static let shared = FeedUrlCache()
    private var cache: [String: String] = [:]
    func get(_ id: String) -> String? { cache[id] }
    func set(_ id: String, url: String) { cache[id] = url }
}

@MainActor
class PodcastDetailViewModel: ObservableObject {
    @Published var episodes: [RSSEpisode] = []
    @Published var feedDescription: String = ""
    @Published var episodeCount: Int?
    @Published var isLoading = false
    @Published var error: String?

    func load(podcastId: String, podcastName: String, feedUrl: String? = nil) async {
        guard episodes.isEmpty else { return }
        // If feedUrl provided, seed the cache immediately (skip iTunes lookup later)
        if let feedUrl {
            await FeedUrlCache.shared.set(podcastId, url: feedUrl)
        }
        await fetchEpisodes(podcastId: podcastId, podcastName: podcastName)
        // Silent retry once on failure — handles transient network blips
        if error != nil && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s back-off
            guard !Task.isCancelled else { return }
            error = nil
            await fetchEpisodes(podcastId: podcastId, podcastName: podcastName)
        }
    }

    func reload(podcastId: String, podcastName: String) async {
        episodes = []
        error = nil
        await fetchEpisodes(podcastId: podcastId, podcastName: podcastName)
    }

    private func fetchEpisodes(podcastId: String, podcastName: String) async {
        isLoading = true
        error = nil
        do {
            // Step 1: iTunes lookup → get feedUrl (skip if already cached)
            let feedUrl: String
            if let cached = await FeedUrlCache.shared.get(podcastId) {
                feedUrl = cached
            } else {
                guard let details = try await PodcastService.shared.lookupPodcast(id: podcastId) else {
                    error = "Podcast not found."
                    isLoading = false
                    return
                }
                episodeCount = details.trackCount
                guard let url = details.feedUrl else {
                    error = "This podcast doesn't have a public RSS feed."
                    isLoading = false
                    return
                }
                await FeedUrlCache.shared.set(podcastId, url: url)
                feedUrl = url
            }

            // Step 2: Fetch RSS feed
            let feed = try await PodcastService.shared.fetchFeed(feedUrl: feedUrl, podcastTitle: podcastName)
            feedDescription = feed.description
            episodes = feed.episodes
        } catch is CancellationError {
            // Task was cancelled (view swiped away) — silently reset, don't show error
            isLoading = false
            return
        } catch {
            self.error = "Couldn't load episodes. Check your connection."
        }
        isLoading = false
    }
}
