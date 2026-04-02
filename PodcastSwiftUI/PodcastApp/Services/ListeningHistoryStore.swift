import Foundation

private let kListeningHistoryKey = "listeningHistory_v1"

/// Lightweight record of a podcast the user has played.
struct ListenedPodcast: Codable {
    let podcastId: String
    let podcastName: String
    let genre: String?      // primaryGenre from PodcastSummary
    let playedAt: Date
}

/// Persists a play-history log and exposes helpers for recommendation logic.
final class ListeningHistoryStore {
    static let shared = ListeningHistoryStore()
    private init() { restore() }

    private(set) var history: [ListenedPodcast] = []

    // MARK: - Record

    func record(_ podcast: PodcastSummary) {
        // Avoid duplicate entries within the same session (same podcast played twice)
        if history.last?.podcastId == podcast.id { return }
        let entry = ListenedPodcast(
            podcastId:   podcast.id,
            podcastName: podcast.name,
            genre:       podcast.primaryGenre,
            playedAt:    Date()
        )
        history.append(entry)
        // Keep last 200 plays
        if history.count > 200 { history.removeFirst(history.count - 200) }
        persist()
    }

    // MARK: - Recommendation helpers

    /// Genres ranked by play frequency (most played first).
    var rankedGenres: [String] {
        var counts: [String: Int] = [:]
        for entry in history {
            guard let g = entry.genre else { continue }
            counts[g, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    /// IDs of all podcasts that appear in the history.
    var playedPodcastIds: Set<String> {
        Set(history.map(\.podcastId))
    }

    var hasHistory: Bool { !history.isEmpty }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: kListeningHistoryKey)
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: kListeningHistoryKey),
              let decoded = try? JSONDecoder().decode([ListenedPodcast].self, from: data)
        else { return }
        history = decoded
    }
}
