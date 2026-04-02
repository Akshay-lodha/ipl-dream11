import SwiftUI

private let kFeedUrlCacheKey = "feedUrlCache_v1"

@MainActor
class HomeViewModel: ObservableObject {
    @Published var topPodcasts: [TopPodcast] = []
    @Published var featuredPodcasts: [TopPodcast] = []
    @Published var recommendedPodcasts: [TopPodcast] = []
    @Published var folders: [CuratedFolder] = CuratedFolder.all
    @Published var recentReleases: [RecentReleasesEntry] = []
    @Published var selectedMood: PodcastMood? = nil
    @Published var moodEpisodes: [RecentReleasesEntry] = []
    @Published var isMoodLoading: Bool = false
    @Published var categoryPodcasts: [String: [TopPodcast]] = [:]
    @Published var footerPodcasts: [TopPodcast] = []
    @Published var popularInCountry: [TopPodcast] = []
    @Published var countryName: String = Locale.current.localizedString(forRegionCode: Locale.current.region?.identifier ?? "US") ?? "Your Country"
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let featuredNames = [
        "The Vergecast",
        "99% Invisible",
        "People by WTF",
        "Waveform: The MKBHD Podcast",
        "Lenny's Podcast: Product Career Growth",
        "Darknet Diaries",
        "Decoder with Nilay Patel",
        "Unexplainable",
        "Reply All",
        "Hard Fork",
    ]

    func load() async {
        guard topPodcasts.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        // Phase 1: charts + featured metadata run concurrently (fast)
        async let charts  = PodcastService.shared.fetchTopPodcasts(limit: 30)
        async let quick   = PodcastService.shared.fetchFeaturedPodcasts(names: featuredNames)
        do {
            topPodcasts = try await charts
            recommendedPodcasts = Self.buildRecommendations(from: topPodcasts, followed: [])
        } catch {
            errorMessage = "Couldn't load podcasts. Check your connection."
        }
        featuredPodcasts = await quick   // cards appear — description shows shimmer
        isLoading = false

        // Folder artwork + description enrichment + default mood + categories run in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in await self.loadFolders() }
            group.addTask { @MainActor in await self.loadCategories() }
            group.addTask { @MainActor in await self.loadPopularInCountry() }
            group.addTask { @MainActor in
                guard !self.featuredPodcasts.isEmpty else { return }
                self.featuredPodcasts = await PodcastService.shared.enrichDescriptions(self.featuredPodcasts)
            }
            group.addTask { @MainActor in
                // Auto-select Commute as the default mood
                if let commute = PodcastMood.all.first {
                    await self.selectMood(commute)
                }
            }
        }
    }

    // Fetches up to 10 top podcasts per genre folder concurrently.
    // Results stream in as they complete — SwiftUI re-renders each folder card as data arrives.
    func loadFolders() async {
        // Snapshot genre IDs — safe to pass into non-isolated child tasks
        let genreWork: [(Int, Int)] = folders.enumerated().map { ($0.offset, $0.element.genreId) }
        await withTaskGroup(of: (Int, [TopPodcast]).self) { group in
            for (index, genreId) in genreWork {
                group.addTask {
                    let podcasts = (try? await PodcastService.shared.fetchPodcastsByGenre(
                        genreId: genreId, limit: 10
                    )) ?? []
                    return (index, podcasts)
                }
            }
            for await (index, podcasts) in group {
                folders[index].podcasts = podcasts
                folders[index].isLoading = false
            }
        }
    }

    // MARK: - Popular in Country (device locale → Apple Marketing Tools country chart)

    func loadPopularInCountry() async {
        let code = Locale.current.region?.identifier ?? "US"
        popularInCountry = (try? await PodcastService.shared.fetchTopPodcastsByCountry(
            countryCode: code, limit: 30
        )) ?? []
    }

    // MARK: - Category Sections (11 genre-based sections, 30 podcasts each)

    func loadCategories() async {
        await withTaskGroup(of: (String, [TopPodcast]).self) { group in
            for category in PodcastCategory.all {
                group.addTask {
                    // Curated list → batch iTunes lookup (preserves order, no genre ambiguity)
                    if let ids = category.curatedIds {
                        let podcasts = (try? await PodcastService.shared.fetchPodcastsByIds(ids)) ?? []
                        return (category.id, podcasts)
                    }
                    // Genre-based fetch
                    let podcasts = (try? await PodcastService.shared.fetchPodcastsByGenre(
                        genreId: category.genreId, limit: 30
                    )) ?? []
                    return (category.id, podcasts)
                }
            }
            for await (id, podcasts) in group {
                categoryPodcasts[id] = podcasts
            }
        }
        // Compute once here — not inline in the view body on every render
        footerPodcasts = Array(categoryPodcasts.values.flatMap { $0 }.shuffled().prefix(40))
    }

    // MARK: - feedUrl cache
    // feedUrl is excluded from TopPodcast.CodingKeys so it never survives
    // UserDefaults persistence. We keep a separate [podcastId: feedUrl] cache
    // so the iTunes lookup only fires once per podcast — ever.

    private nonisolated static func cachedFeedUrl(for id: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: kFeedUrlCacheKey) as? [String: String])?[id]
    }

    private nonisolated static func persistFeedUrl(_ url: String, for id: String) {
        var cache = (UserDefaults.standard.dictionary(forKey: kFeedUrlCacheKey) as? [String: String]) ?? [:]
        guard cache[id] != url else { return }
        cache[id] = url
        UserDefaults.standard.set(cache, forKey: kFeedUrlCacheKey)
    }

    // Fetches the latest episode from each followed podcast concurrently.
    // feedUrls are resolved from: (1) podcast struct, (2) local cache, (3) iTunes lookup.
    // After a lookup the result is cached so future launches skip it entirely.
    func loadRecentReleases(from followed: [TopPodcast]) async {
        recommendedPodcasts = Self.buildRecommendations(from: topPodcasts, followed: followed)
        guard !followed.isEmpty else {
            print("[RecentReleases] No followed podcasts — skipping")
            return
        }
        print("[RecentReleases] Loading from \(followed.count) followed podcasts")

        // Run feed fetches OFF the main actor so they execute concurrently
        let entries = await Self.fetchRecentEntries(followed: followed)
        recentReleases = entries.sorted {
            parsePubDate($0.episode.pubDate) > parsePubDate($1.episode.pubDate)
        }
    }

    private static let pubDateParsers: [DateFormatter] = {
        ["EEE, dd MMM yyyy HH:mm:ss Z",
         "EEE, dd MMM yyyy HH:mm:ss zzz",
         "yyyy-MM-dd'T'HH:mm:ssZ"].map { fmt in
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            return df
        }
    }()

    private func parsePubDate(_ raw: String) -> Date {
        for df in Self.pubDateParsers {
            if let d = df.date(from: raw) { return d }
        }
        return .distantPast
    }

    // MARK: - Recommendations

    /// Fetches recent episodes concurrently off the main actor
    private nonisolated static func fetchRecentEntries(
        followed: [TopPodcast]
    ) async -> [RecentReleasesEntry] {
        await withTaskGroup(of: [RecentReleasesEntry].self) { group in
            for podcast in followed {
                group.addTask {
                    var feedUrl = podcast.feedUrl ?? Self.cachedFeedUrl(for: podcast.id)
                    if feedUrl == nil {
                        feedUrl = (try? await PodcastService.shared.lookupPodcast(id: podcast.id))?.feedUrl
                        if let url = feedUrl { Self.persistFeedUrl(url, for: podcast.id) }
                    }
                    guard let feedUrl else {
                        print("[RecentReleases] No feedUrl for \(podcast.name)")
                        return []
                    }
                    do {
                        let feed = try await PodcastService.shared.fetchRecentEpisodes(
                            feedUrl: feedUrl, podcastTitle: podcast.name, count: 2
                        )
                        let episodes = feed.episodes.prefix(2).map {
                            RecentReleasesEntry(episode: $0, podcast: podcast)
                        }
                        print("[RecentReleases] Got \(episodes.count) episodes from \(podcast.name)")
                        return episodes
                    } catch {
                        print("[RecentReleases] Failed for \(podcast.name): \(error.localizedDescription)")
                        return []
                    }
                }
            }
            var all: [RecentReleasesEntry] = []
            for await batch in group { all.append(contentsOf: batch) }
            return all
        }
    }

    /// Builds a ranked list of up to 10 podcasts the user hasn't played yet.
    /// Primary:  match by genres from play history (most-played genre first).
    /// Fallback: match by genres from followed podcasts.
    static func buildRecommendations(from allPodcasts: [TopPodcast],
                                     followed: [TopPodcast] = []) -> [TopPodcast] {
        let history = ListeningHistoryStore.shared
        let played  = history.playedPodcastIds
        let followedIds = Set(followed.map(\.id))
        let unplayed = allPodcasts.filter { !played.contains($0.id) && !followedIds.contains($0.id) }

        let genres: [String]
        if history.hasHistory {
            genres = history.rankedGenres
        } else {
            // Fallback: rank genres by how many followed podcasts belong to each
            var counts: [String: Int] = [:]
            for p in followed {
                guard let g = p.primaryGenre else { continue }
                counts[g, default: 0] += 1
            }
            genres = counts.sorted { $0.value > $1.value }.map(\.key)
        }

        guard !genres.isEmpty else { return Array(unplayed.prefix(24)) }

        func score(_ p: TopPodcast) -> Int {
            guard let g = p.primaryGenre, let idx = genres.firstIndex(of: g) else { return Int.max }
            return idx
        }

        return Array(unplayed.sorted { score($0) < score($1) }.prefix(24))
    }

    // MARK: - Mood Episodes

    /// Fetches top podcasts from the mood's genres, then finds one episode per podcast
    /// that fits the mood's duration window. Shows up to 8 results.
    func selectMood(_ mood: PodcastMood) async {
        selectedMood = mood
        moodEpisodes = []
        isMoodLoading = true
        defer { isMoodLoading = false }

        // Fetch candidates from all mood genres concurrently
        var candidates: [TopPodcast] = []
        await withTaskGroup(of: [TopPodcast].self) { group in
            for genreId in mood.genreIds {
                group.addTask {
                    (try? await PodcastService.shared.fetchPodcastsByGenre(genreId: genreId, limit: 8)) ?? []
                }
            }
            for await batch in group { candidates.append(contentsOf: batch) }
        }

        // Deduplicate
        var seen = Set<String>()
        candidates = candidates.filter { seen.insert($0.id).inserted }

        // Fetch episodes and filter by duration
        var entries: [RecentReleasesEntry] = []
        await withTaskGroup(of: RecentReleasesEntry?.self) { group in
            for podcast in candidates.prefix(14) {
                group.addTask {
                    var feedUrl = podcast.feedUrl ?? Self.cachedFeedUrl(for: podcast.id)
                    if feedUrl == nil {
                        feedUrl = (try? await PodcastService.shared.lookupPodcast(id: podcast.id))?.feedUrl
                        if let url = feedUrl { Self.persistFeedUrl(url, for: podcast.id) }
                    }
                    guard let feedUrl,
                          let feed = try? await PodcastService.shared.fetchRecentEpisodes(
                              feedUrl: feedUrl, podcastTitle: podcast.name, count: 5
                          ) else { return nil }

                    for ep in feed.episodes {
                        let dur = ep.durationSeconds
                        if let min = mood.minSeconds, dur < min { continue }
                        if let max = mood.maxSeconds, dur > max { continue }
                        return RecentReleasesEntry(episode: ep, podcast: podcast)
                    }
                    return nil
                }
            }
            for await entry in group {
                if let e = entry { entries.append(e) }
            }
        }
        moodEpisodes = Array(entries.prefix(8))
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        async let charts  = PodcastService.shared.fetchTopPodcasts(limit: 30)
        async let quick   = PodcastService.shared.fetchFeaturedPodcasts(names: featuredNames)
        do {
            topPodcasts = try await charts
            recommendedPodcasts = Self.buildRecommendations(from: topPodcasts, followed: [])
        } catch {
            errorMessage = "Couldn't refresh podcasts."
        }
        featuredPodcasts = await quick
        isLoading = false

        guard !featuredPodcasts.isEmpty else { return }
        featuredPodcasts = await PodcastService.shared.enrichDescriptions(featuredPodcasts)
    }
}
