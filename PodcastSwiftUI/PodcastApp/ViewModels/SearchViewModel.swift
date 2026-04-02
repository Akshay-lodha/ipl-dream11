import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var results: [iTunesPodcast] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private var searchTask: Task<Void, Never>?

    func search(term: String) {
        searchTask?.cancel()
        guard !term.isEmpty else {
            results = []
            isSearching = false
            return
        }

        searchTask = Task {
            // Debounce: wait 350ms before firing
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }

            isSearching = true
            errorMessage = nil
            do {
                results = try await PodcastService.shared.searchPodcasts(term: term)
            } catch {
                if !Task.isCancelled {
                    errorMessage = "Search failed. Try again."
                }
            }
            isSearching = false
        }
    }
}
