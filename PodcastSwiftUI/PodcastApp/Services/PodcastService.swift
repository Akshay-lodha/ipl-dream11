import Foundation

actor PodcastService {
    static let shared = PodcastService()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 20_000_000, diskCapacity: 100_000_000)
        config.timeoutIntervalForRequest = 15   // 15s timeout (default 60s is too slow)
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Top Charts (Apple Marketing Tools — no auth needed)
    func fetchTopPodcasts(limit: Int = 25) async throws -> [TopPodcast] {
        let url = URL(string: "https://rss.applemarketingtools.com/api/v2/us/podcasts/top/\(limit)/podcasts.json")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TopChartsResponse.self, from: data)
        return response.feed.results
    }

    // MARK: - Country Charts (same API, country code from device locale)
    func fetchTopPodcastsByCountry(countryCode: String, limit: Int = 30) async throws -> [TopPodcast] {
        let code = countryCode.lowercased()
        let url = URL(string: "https://rss.applemarketingtools.com/api/v2/\(code)/podcasts/top/\(limit)/podcasts.json")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TopChartsResponse.self, from: data)
        return response.feed.results
    }

    // MARK: - Genre Charts (iTunes RSS generator — supports genre filtering)
    // Uses the old-format iTunes RSS API which has reliable genre support.
    // Returns the top `limit` podcasts for the given iTunes genre ID.
    func fetchPodcastsByGenre(genreId: Int, limit: Int = 4) async throws -> [TopPodcast] {
        let urlStr = "https://itunes.apple.com/us/rss/toppodcasts/limit=\(limit)/genre=\(genreId)/json"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(iTunesGenreChart.self, from: data)
        return (response.feed.entry ?? []).compactMap { entry in
            let imageUrl = entry.imImage.last?.label ?? ""
            guard !entry.imName.label.isEmpty, !imageUrl.isEmpty else { return nil }
            return TopPodcast(
                id: entry.id.attributes.imId,
                name: entry.imName.label,
                artistName: entry.imArtist.label,
                artworkUrl100: imageUrl,
                genres: nil,
                url: "",
                podcastDescription: nil,
                feedUrl: nil
            )
        }
    }

    // MARK: - iTunes Search API (no auth needed)
    func searchPodcasts(term: String, limit: Int = 20) async throws -> [iTunesPodcast] {
        guard !term.isEmpty else { return [] }
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            .init(name: "term", value: term),
            .init(name: "media", value: "podcast"),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "country", value: "us"),
        ]
        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(iTunesResponse.self, from: data)
        return response.results
    }

    // MARK: - iTunes Lookup by ID (to get feedUrl)
    func lookupPodcast(id: String) async throws -> iTunesPodcast? {
        let url = URL(string: "https://itunes.apple.com/lookup?id=\(id)&media=podcast")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(iTunesResponse.self, from: data)
        return response.results.first
    }

    // Batch lookup — fetches up to 200 IDs in one request, preserves input order
    func fetchPodcastsByIds(_ ids: [String]) async throws -> [TopPodcast] {
        let joined = ids.joined(separator: ",")
        let url = URL(string: "https://itunes.apple.com/lookup?id=\(joined)&media=podcast&entity=podcast")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(iTunesResponse.self, from: data)
        // Preserve the curated order
        let byId = Dictionary(uniqueKeysWithValues: response.results.map { ("\($0.collectionId)", $0) })
        return ids.compactMap { byId[$0].map { TopPodcast(iTunes: $0) } }
    }

    // MARK: - Featured Podcasts (Phase 1 — fast: search + iTunes lookup only)
    // Returns quickly so cards appear with artwork/title immediately.
    func fetchFeaturedPodcasts(names: [String]) async -> [TopPodcast] {
        await withTaskGroup(of: (Int, TopPodcast?).self) { group in
            for (index, name) in names.enumerated() {
                group.addTask {
                    guard let found = try? await self.searchPodcasts(term: name, limit: 1),
                          let match = found.first else { return (index, nil) }
                    let rich = (try? await self.lookupPodcast(id: "\(match.collectionId)")) ?? match
                    return (index, TopPodcast(iTunes: rich))
                }
            }
            var results: [(Int, TopPodcast)] = []
            for await (index, podcast) in group {
                if let podcast { results.append((index, podcast)) }
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    // MARK: - Featured Podcasts (Phase 2 — enrich with RSS descriptions)
    // Called after Phase 1 so the shimmer in cards is replaced by real text.
    // Uses a range-request + early-abort parse to fetch only the channel header (~32 KB)
    // instead of downloading and parsing the full feed.
    func enrichDescriptions(_ podcasts: [TopPodcast]) async -> [TopPodcast] {
        var enriched = podcasts
        await withTaskGroup(of: (Int, String?).self) { group in
            for (index, podcast) in podcasts.enumerated() {
                guard podcast.podcastDescription?.isEmpty ?? true,
                      let feedUrl = podcast.feedUrl else { continue }
                group.addTask {
                    let desc = (try? await self.fetchDescriptionOnly(feedUrl: feedUrl)) ?? ""
                    return (index, desc.isEmpty ? nil : desc)
                }
            }
            for await (index, desc) in group {
                if let desc { enriched[index].podcastDescription = desc }
            }
        }
        return enriched
    }

    // Fetches only the first 32 KB of an RSS feed (channel header is always before
    // the first <item>) and aborts parsing as soon as the description tag is found.
    private func fetchDescriptionOnly(feedUrl: String) async throws -> String {
        guard let url = URL(string: feedUrl) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("bytes=0-32767", forHTTPHeaderField: "Range")
        let (data, _) = try await session.data(for: request)
        let desc = RSSParser.parseDescriptionOnly(data: data).trimmingCharacters(in: .whitespacesAndNewlines)
        return desc
    }

    // MARK: - RSS Feed Fetching (channel info + all episodes)
    func fetchFeed(feedUrl: String, podcastTitle: String = "") async throws -> RSSFeed {
        guard let url = URL(string: feedUrl) else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        return RSSParser.parse(data: data, podcastTitle: podcastTitle)
    }

    // MARK: - Fast Recent Episodes Fetch
    // Uses HTTP Range to download only the first 64 KB of the feed (episodes
    // are listed newest-first, so the first N items are always near the top).
    // Parsing aborts as soon as `count` items have been collected.
    func fetchRecentEpisodes(feedUrl: String, podcastTitle: String = "", count: Int = 2) async throws -> RSSFeed {
        guard let url = URL(string: feedUrl) else { throw URLError(.badURL) }
        // Try range request first (fast), fall back to full download if it fails
        var request = URLRequest(url: url)
        request.setValue("bytes=0-65535", forHTTPHeaderField: "Range")   // first 64 KB
        do {
            let (data, _) = try await session.data(for: request)
            let feed = RSSParser.parse(data: data, podcastTitle: podcastTitle, maxEpisodes: count)
            if !feed.episodes.isEmpty { return feed }
        } catch {
            // Range request failed — some servers don't support it
        }
        // Fallback: full download
        let (data, _) = try await session.data(from: url)
        return RSSParser.parse(data: data, podcastTitle: podcastTitle, maxEpisodes: count)
    }
}
