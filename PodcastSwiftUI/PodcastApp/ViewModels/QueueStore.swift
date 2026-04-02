import Foundation

struct QueueItem: Identifiable, Equatable {
    let id = UUID()
    let episode: RSSEpisode
    let podcast: PodcastSummary
}

@MainActor
class QueueStore: ObservableObject {
    @Published var items: [QueueItem] = []

    func playNext(_ episode: RSSEpisode, from podcast: PodcastSummary) {
        items.removeAll { $0.episode.id == episode.id }
        items.insert(QueueItem(episode: episode, podcast: podcast), at: 0)
    }

    func addToQueue(_ episode: RSSEpisode, from podcast: PodcastSummary) {
        items.removeAll { $0.episode.id == episode.id }
        items.append(QueueItem(episode: episode, podcast: podcast))
    }

    func dequeue() -> QueueItem? {
        guard !items.isEmpty else { return nil }
        return items.removeFirst()
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }
}
