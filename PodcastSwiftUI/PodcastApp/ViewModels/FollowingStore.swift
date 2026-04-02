import SwiftUI
import Combine

class FollowingStore: ObservableObject {
    @Published var followedPodcasts: [TopPodcast] = []
    private var cancellable: AnyCancellable?
    private let storageKey = "followedPodcasts"

    init() {
        load()
        // Persist whenever the array changes (dropFirst skips the initial load)
        cancellable = $followedPodcasts.dropFirst().sink { [weak self] _ in self?.save() }
    }

    // MARK: - Persistence
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TopPodcast].self, from: data) else { return }
        followedPodcasts = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(followedPodcasts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - TopPodcast
    func follow(_ podcast: TopPodcast) {
        guard !isFollowing(podcast) else { return }
        withAnimation(.spring(response: 0.4)) {
            followedPodcasts.insert(podcast, at: 0)
        }
    }

    func unfollow(_ podcast: TopPodcast) {
        withAnimation(.spring(response: 0.4)) {
            followedPodcasts.removeAll { $0.id == podcast.id }
        }
    }

    func toggle(_ podcast: TopPodcast) {
        isFollowing(podcast) ? unfollow(podcast) : follow(podcast)
    }

    func isFollowing(_ podcast: TopPodcast) -> Bool {
        followedPodcasts.contains { $0.id == podcast.id }
    }

    // MARK: - PodcastSummary (from detail view)
    func toggleSummary(_ summary: PodcastSummary) {
        if followedPodcasts.contains(where: { $0.id == summary.id }) {
            withAnimation(.spring(response: 0.4)) {
                followedPodcasts.removeAll { $0.id == summary.id }
            }
        } else {
            let podcast = TopPodcast(
                id: summary.id,
                name: summary.name,
                artistName: summary.artistName,
                artworkUrl100: summary.artworkURL?.absoluteString ?? "",
                genres: summary.primaryGenre.map { [PodcastGenre(genreId: "", name: $0)] },
                url: ""
            )
            withAnimation(.spring(response: 0.4)) {
                followedPodcasts.insert(podcast, at: 0)
            }
        }
    }

    func isFollowing(_ summary: PodcastSummary) -> Bool {
        followedPodcasts.contains { $0.id == summary.id }
    }
}
