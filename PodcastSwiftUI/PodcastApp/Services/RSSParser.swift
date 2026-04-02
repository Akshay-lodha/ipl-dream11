import Foundation

final class RSSParser: NSObject, XMLParserDelegate {
    private var episodes: [RSSEpisode] = []
    private var podcastTitle: String = ""
    private var channelDescription: String = ""
    private var channelArtworkUrl: URL?

    // Current item state
    private var inItem = false
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var currentDuration = ""
    private var currentGuid = ""
    private var currentAudioUrl: URL?
    private var currentArtworkUrl: URL?
    private var currentChaptersUrl: String?
    private var buffer = ""
    private var channelTitleSet = false

    // When true, abort parsing as soon as the channel description is found
    private var descriptionOnlyMode = false
    // Abort after collecting this many episodes (0 = unlimited)
    private var maxEpisodes = 0
    // Stored so didEndElement can abort mid-feed
    private weak var activeParser: XMLParser?

    /// Lightweight parse: stops at the first <item> tag — channel header only.
    static func parseDescriptionOnly(data: Data) -> String {
        let delegate = RSSParser()
        delegate.descriptionOnlyMode = true
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.channelDescription
    }

    /// Fast parse: downloads stop after `maxEpisodes` items are collected.
    static func parse(data: Data, podcastTitle: String = "", maxEpisodes: Int = 0) -> RSSFeed {
        let delegate = RSSParser()
        delegate.podcastTitle = podcastTitle
        delegate.maxEpisodes  = maxEpisodes
        let parser = XMLParser(data: data)
        delegate.activeParser = parser
        parser.delegate = delegate
        parser.parse()
        return RSSFeed(
            title: delegate.podcastTitle.isEmpty ? podcastTitle : delegate.podcastTitle,
            description: delegate.channelDescription,
            artworkUrl: delegate.channelArtworkUrl,
            episodes: delegate.episodes
        )
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        buffer = ""

        if elementName == "item" {
            // In description-only mode we have everything we need — stop immediately
            if descriptionOnlyMode { parser.abortParsing(); return }
            inItem = true
            currentTitle = ""
            currentDescription = ""
            currentPubDate = ""
            currentDuration = ""
            currentGuid = ""
            currentAudioUrl = nil
            currentArtworkUrl = nil
            currentChaptersUrl = nil
        }

        if elementName == "enclosure" {
            if let urlStr = attributeDict["url"] {
                currentAudioUrl = URL(string: urlStr)
            }
        }

        if elementName == "itunes:image" {
            if let href = attributeDict["href"] {
                let url = URL(string: href)
                if inItem { currentArtworkUrl = url }
                else { channelArtworkUrl = url }
            }
        }

        // podcast:chapters — when shouldProcessNamespaces is off (default),
        // elementName contains the full prefixed tag name e.g. "podcast:chapters"
        if inItem && (elementName == "podcast:chapters" || qName == "podcast:chapters" || elementName == "chapters") {
            if let href = attributeDict["href"] {
                currentChaptersUrl = href
                print("[RSSParser] Found chapters URL: \(href)")
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if inItem {
            switch elementName {
            case "title":               currentTitle = trimmed
            case "description", "itunes:summary":
                if currentDescription.isEmpty { currentDescription = trimmed }
            case "pubDate":             currentPubDate = trimmed
            case "itunes:duration":     currentDuration = trimmed
            case "guid":                currentGuid = trimmed
            default: break
            }
        } else {
            switch elementName {
            case "title":
                if !channelTitleSet && !trimmed.isEmpty {
                    podcastTitle = trimmed
                    channelTitleSet = true
                }
            case "description", "itunes:summary":
                if channelDescription.isEmpty && !trimmed.isEmpty {
                    channelDescription = trimmed
                }
            default: break
            }
        }

        if elementName == "item" {
            let artwork = currentArtworkUrl ?? channelArtworkUrl
            let guid = currentGuid.isEmpty ? UUID().uuidString : currentGuid
            let episode = RSSEpisode(
                id: guid,
                title: currentTitle,
                description: currentDescription,
                plainDescription: RSSParser.stripHTML(currentDescription),
                pubDate: currentPubDate,
                formattedPubDate: RSSParser.formatDate(currentPubDate),
                duration: currentDuration,
                audioUrl: currentAudioUrl,
                artworkUrl: artwork,
                podcastTitle: podcastTitle,
                chaptersUrl: currentChaptersUrl
            )
            if !episode.title.isEmpty {
                episodes.append(episode)
                // Stop immediately once we have enough episodes
                if maxEpisodes > 0 && episodes.count >= maxEpisodes {
                    activeParser?.abortParsing()
                }
            }
            inItem = false
        }

        buffer = ""
    }

    // MARK: - Static Helpers (called once at parse time, not on every render)
    static func stripHTML(_ html: String) -> String {
        guard !html.isEmpty else { return html }
        // Fast path: no HTML tags present
        if !html.contains("<") { return html }
        guard let data = html.data(using: .utf8) else { return html }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return (try? NSAttributedString(data: data, options: options, documentAttributes: nil).string) ?? html
    }

    static func formatDate(_ raw: String) -> String {
        guard !raw.isEmpty else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "yyyy-MM-dd'T'HH:mm:ssZ"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                let out = DateFormatter()
                out.dateFormat = "MMM d, yyyy"
                return out.string(from: date)
            }
        }
        return raw
    }
}
