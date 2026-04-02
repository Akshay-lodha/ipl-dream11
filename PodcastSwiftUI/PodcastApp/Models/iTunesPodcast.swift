import Foundation

// MARK: - Recent Releases entry (episode + its parent podcast)
struct RecentReleasesEntry: Identifiable {
    var id: String { episode.id }
    let episode: RSSEpisode
    let podcast:  TopPodcast
}

// MARK: - PodcastSummary (bridges TopPodcast ↔ iTunesPodcast for navigation)
struct PodcastSummary: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let artistName: String
    let artworkURL: URL?
    let primaryGenre: String?
    var feedUrl: String?

    /// Smaller artwork for list cells (200×200 — sufficient for 3× displays at ~66pt)
    var thumbnailURL: URL? {
        artworkURL.flatMap { url in
            URL(string: url.absoluteString
                .replacingOccurrences(of: "600x600bb", with: "200x200bb")
                .replacingOccurrences(of: "100x100bb", with: "200x200bb"))
        }
    }
}

// Carries a list of podcasts + starting index for swipeable detail pager
struct PodcastDetailDestination: Hashable {
    let podcasts: [PodcastSummary]
    let startIndex: Int
}

extension TopPodcast {
    var summary: PodcastSummary {
        PodcastSummary(id: id, name: name, artistName: artistName, artworkURL: artworkURL, primaryGenre: primaryGenre, feedUrl: feedUrl)
    }

    /// Smaller artwork for list cells
    var thumbnailURL: URL? {
        URL(string: artworkUrl100.replacingOccurrences(of: "100x100bb", with: "200x200bb"))
    }
}

extension iTunesPodcast {
    var summary: PodcastSummary {
        PodcastSummary(id: "\(collectionId)", name: collectionName, artistName: artistName, artworkURL: artworkURL, primaryGenre: primaryGenreName, feedUrl: feedUrl)
    }
}

// MARK: - RSS Feed (channel metadata + episodes)
struct RSSFeed {
    let title: String
    let description: String
    let artworkUrl: URL?
    let episodes: [RSSEpisode]
}

// MARK: - Apple Top Charts API
// https://rss.applemarketingtools.com/api/v2/us/podcasts/top/25/podcasts.json
struct TopChartsResponse: Codable {
    let feed: TopChartsFeed
}

struct TopChartsFeed: Codable {
    let results: [TopPodcast]
}

struct TopPodcast: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let artistName: String
    let artworkUrl100: String
    let genres: [PodcastGenre]?
    let url: String
    // Not in the Charts API — populated only when built from iTunes lookup
    var podcastDescription: String?
    var feedUrl: String?              // populated from iTunes, not Charts API

    var artworkURL: URL? {
        URL(string: artworkUrl100.replacingOccurrences(of: "100x100bb", with: "600x600bb"))
    }

    var primaryGenre: String? { genres?.first?.name }

    // feedUrl and podcastDescription are optional — absent from Charts API JSON but
    // safe to include in CodingKeys because Swift decodes missing optional keys as nil.
    // Including them here means they survive UserDefaults round-trips, eliminating the
    // extra iTunes lookup on every subsequent Recent Releases load.
    enum CodingKeys: String, CodingKey {
        case id, name, artistName, artworkUrl100, genres, url
        case feedUrl, podcastDescription
    }
}

extension TopPodcast {
    init(iTunes: iTunesPodcast) {
        self.id = "\(iTunes.collectionId)"
        self.name = iTunes.collectionName
        self.artistName = iTunes.artistName
        self.artworkUrl100 = iTunes.artworkUrl600 ?? iTunes.artworkUrl100 ?? ""
        self.genres = iTunes.primaryGenreName.map { [PodcastGenre(genreId: "", name: $0)] }
        self.url = iTunes.collectionViewUrl ?? ""
        self.podcastDescription = iTunes.bestDescription
        self.feedUrl = iTunes.feedUrl
    }
}

struct PodcastGenre: Codable, Hashable {
    let genreId: String
    let name: String
}

// MARK: - iTunes Search / Lookup API
struct iTunesResponse: Codable {
    let resultCount: Int
    let results: [iTunesPodcast]
}

struct iTunesPodcast: Codable, Identifiable, Hashable {
    let collectionId: Int
    let collectionName: String
    let artistName: String
    let artworkUrl600: String?
    let artworkUrl100: String?
    let feedUrl: String?
    let primaryGenreName: String?
    let trackCount: Int?
    let collectionViewUrl: String?
    let podcastDescription: String?
    let longDescription: String?

    var id: Int { collectionId }

    var artworkURL: URL? {
        (artworkUrl600 ?? artworkUrl100).flatMap { URL(string: $0) }
    }

    // Best available description: prefer longDescription (richer), fall back to description
    var bestDescription: String? {
        let d = longDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = podcastDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d, !d.isEmpty { return d }
        if let s, !s.isEmpty { return s }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case collectionId, collectionName, artistName
        case artworkUrl600, artworkUrl100
        case feedUrl, primaryGenreName, trackCount, collectionViewUrl
        case podcastDescription = "description"
        case longDescription
    }
}

// MARK: - RSS Episode
struct RSSEpisode: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let description: String
    let plainDescription: String   // HTML stripped at parse time, not on every render
    let pubDate: String
    let formattedPubDate: String   // Pre-formatted at parse time
    let duration: String
    let audioUrl: URL?
    let artworkUrl: URL?
    let podcastTitle: String
    let chaptersUrl: String?

    init(id: String, title: String, description: String, plainDescription: String,
         pubDate: String, formattedPubDate: String, duration: String,
         audioUrl: URL?, artworkUrl: URL?, podcastTitle: String, chaptersUrl: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.plainDescription = plainDescription
        self.pubDate = pubDate
        self.formattedPubDate = formattedPubDate
        self.duration = duration
        self.audioUrl = audioUrl
        self.artworkUrl = artworkUrl
        self.podcastTitle = podcastTitle
        self.chaptersUrl = chaptersUrl
    }

    // Duration in seconds for mood filtering
    var durationSeconds: Int {
        if let secs = Int(duration) { return secs }
        let parts = duration.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        default: return 0
        }
    }

    // Formatted duration → "1h 29m" / "45m"
    var displayDuration: String {
        // Raw seconds (e.g. "5400")
        if let secs = Int(duration) {
            let h = secs / 3600
            let m = (secs % 3600) / 60
            return h > 0 ? "\(h)h \(m)m" : "\(m)m"
        }
        // Colon-separated: HH:MM:SS or MM:SS
        let parts = duration.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3: return parts[0] > 0 ? "\(parts[0])h \(parts[1])m" : "\(parts[1])m"
        case 2: return "\(parts[0])m"
        default: return duration
        }
    }
}

// MARK: - iTunes RSS Genre Chart Decoder
// Decodes the response from https://itunes.apple.com/us/rss/toppodcasts/limit=4/genre={id}/json
// (old-format iTunes RSS, different structure from the Apple Marketing Tools API)
struct iTunesGenreChart: Decodable {
    let feed: Feed
    struct Feed: Decodable {
        let entry: [Entry]?
    }
    struct Entry: Decodable {
        let imName:   Label
        let imArtist: Label
        let imImage:  [Label]
        let id:       EntryId
        enum CodingKeys: String, CodingKey {
            case imName   = "im:name"
            case imArtist = "im:artist"
            case imImage  = "im:image"
            case id
        }
        struct Label:   Decodable { let label: String }
        struct EntryId: Decodable {
            let attributes: Attrs
            struct Attrs: Decodable {
                let imId: String
                enum CodingKeys: String, CodingKey { case imId = "im:id" }
            }
        }
    }
}

// MARK: - Podcast Chapters
struct PodcastChapter: Codable, Identifiable {
    let startTime: Double
    let title: String
    let img: String?
    let url: String?

    var id: Double { startTime }
}

struct PodcastChaptersResponse: Codable {
    let chapters: [PodcastChapter]
}

// MARK: - Recently Played
struct RecentlyPlayedEntry: Codable, Identifiable {
    let id: String      // episode.id
    let episode: RSSEpisode
    let podcast: PodcastSummary
    let playedAt: Date
}

// MARK: - Bookmark
struct PodcastBookmark: Codable, Identifiable {
    let id: UUID
    let episodeId: String
    let episodeTitle: String
    let podcastTitle: String
    let timestamp: Double           // seconds into the episode
    let totalDuration: Double
    var title: String               // e.g. "Moment at 3:57"
    var notes: String
    var saveAudioSnippet: Bool
    var clipLength: Int             // seconds
    let createdAt: Date

    init(episodeId: String, episodeTitle: String, podcastTitle: String,
         timestamp: Double, totalDuration: Double,
         title: String? = nil, notes: String = "",
         saveAudioSnippet: Bool = true, clipLength: Int = 30) {
        self.id = UUID()
        self.episodeId = episodeId
        self.episodeTitle = episodeTitle
        self.podcastTitle = podcastTitle
        self.timestamp = timestamp
        self.totalDuration = totalDuration
        self.title = title ?? "Moment at \(PodcastBookmark.formatTime(timestamp))"
        self.notes = notes
        self.saveAudioSnippet = saveAudioSnippet
        self.clipLength = clipLength
        self.createdAt = Date()
    }

    static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    var clipEndTime: Double {
        min(timestamp + Double(clipLength), totalDuration)
    }
}
