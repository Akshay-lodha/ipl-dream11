import SwiftUI
import AVFoundation
import MediaPlayer

class PlayerViewModel: ObservableObject {
    // MARK: - Published State
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var currentTime: Double = 0
    @Published var totalTime: Double = 0
    @Published var currentEpisodeTitle: String = ""
    @Published var currentPodcastTitle: String = ""
    @Published var artworkURL: URL? = nil
    @Published var artworkColor: Color = Color(red: 0.1, green: 0.1, blue: 0.12)
    @Published var hasLoadedEpisode: Bool = false
    @Published var currentEpisodeDescription: String = ""

    /// Mini player shows when actively playing OR when there's a valid recently played entry to resume.
    /// On first-ever launch (no playback history), mini player stays hidden.
    var isMiniPlayerVisible: Bool {
        if hasLoadedEpisode { return true }
        guard let entry = recentlyPlayed.first, !entry.episode.title.isEmpty else { return false }
        return true
    }

    @Published var currentEpisodeId: String = ""
    @Published var playbackRate: Double = 1.0
    @Published var sleepTimerRemaining: TimeInterval? = nil
    @Published var isLoadingLatest: Bool = false
    @Published var isScrubbing: Bool = false
    @Published var chapters: [PodcastChapter] = []
    @Published var recentlyPlayed: [RecentlyPlayedEntry] = []
    /// The currently playing podcast — used for navigating to its detail page
    @Published var currentPodcast: PodcastSummary?
    @Published var bookmarks: [PodcastBookmark] = []

    // MARK: - Walking Mode (persists across sheet dismiss)
    @Published var isWalkingMode: Bool = false
    @Published var walkSessionId: Int = 0  // increments to force view recreation
    let walkingViewModel = WalkingModeViewModel()

    // MARK: - Queue Reference
    weak var queueStore: QueueStore?

    // MARK: - Private
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var durationObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var bufferingObserver: NSKeyValueObservation?
    private var nowPlayingArtwork: MPMediaItemArtwork?
    private var sleepTimer: Timer?
    private static let positionKey = "savedPlaybackPositions"
    private static let recentlyPlayedKey = "recentlyPlayedEntries"

    // MARK: - Speed & Skip Intervals
    static let availableRates: [Double] = [0.8, 1.0, 1.2, 1.4, 1.6, 2.0, 2.5, 3.0]
    private static let rateLabels: [Double: String] = [
        0.8: "0.8×", 1.0: "1×", 1.2: "1.2×", 1.4: "1.4×", 1.6: "1.6×", 2.0: "2×", 2.5: "2.5×", 3.0: "3×"
    ]
    var playbackRateLabel: String { Self.rateLabels[playbackRate] ?? "\(playbackRate)×" }

    static let skipBackOptions: [Int] = [10, 15, 20, 30]
    static let skipForwardOptions: [Int] = [15, 30, 45, 60]

    @Published var skipBackInterval: Int {
        didSet { UserDefaults.standard.set(skipBackInterval, forKey: "skipBackInterval"); updateRemoteSkipIntervals() }
    }
    @Published var skipForwardInterval: Int {
        didSet { UserDefaults.standard.set(skipForwardInterval, forKey: "skipForwardInterval"); updateRemoteSkipIntervals() }
    }

    // MARK: - Init
    init() {
        let savedBack = UserDefaults.standard.integer(forKey: "skipBackInterval")
        self.skipBackInterval = Self.skipBackOptions.contains(savedBack) ? savedBack : 15
        let savedFwd = UserDefaults.standard.integer(forKey: "skipForwardInterval")
        self.skipForwardInterval = Self.skipForwardOptions.contains(savedFwd) ? savedFwd : 30
        activateAudioSession()
        configureRemoteControls()
        setupSystemObservers()
        loadRecentlyPlayed()
        loadBookmarks()
    }

    deinit {
        stopObservers()
        sleepTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        MPRemoteCommandCenter.shared().playCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().pauseCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().skipForwardCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().skipBackwardCommand.removeTarget(nil)
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.removeTarget(nil)
    }

    // MARK: - Audio Session
    @discardableResult
    private func activateAudioSession() -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            return true
        } catch {
            print("AVAudioSession error: \(error)")
            return false
        }
    }

    // MARK: - System Notifications
    private func setupSystemObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self, selector: #selector(savePositionOnBackground),
            name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        DispatchQueue.main.async {
            switch type {
            case .began:
                self.isPlaying = false
                self.updateNowPlayingInfo()
            case .ended:
                let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                if AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) { self.play() }
            @unknown default: break
            }
        }
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .oldDeviceUnavailable else { return }
        DispatchQueue.main.async { self.pause() }
    }

    @objc private func savePositionOnBackground() { savePosition() }

    // MARK: - Remote Controls
    private func configureRemoteControls() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayback(); return .success }
        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: skipForwardInterval)]
        center.skipForwardCommand.addTarget { [weak self] _ in self?.skipForward(); return .success }
        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBackInterval)]
        center.skipBackwardCommand.addTarget { [weak self] _ in self?.skipBackward(); return .success }
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime); return .success
        }
    }

    // MARK: - Load Episode

    /// Play a downloaded episode directly from a local file URL.
    func loadLocalEpisode(_ episode: RSSEpisode, localURL: URL) {
        if currentEpisodeId == episode.id { togglePlayback(); return }
        savePosition()
        stopObservers()
        player?.pause()
        currentEpisodeId    = episode.id
        currentEpisodeTitle = episode.title
        currentPodcastTitle = episode.podcastTitle
        artworkURL          = episode.artworkUrl
        let savedTime = loadSavedPosition(for: episode.id)
        currentTime  = (savedTime != nil && savedTime! > 5) ? savedTime! : 0
        totalTime    = 0
        isBuffering  = true
        hasLoadedEpisode = true
        chapters     = []
        let item = AVPlayerItem(url: localURL)
        if player == nil {
            player = AVPlayer(playerItem: item)
            player?.automaticallyWaitsToMinimizeStalling = true
        } else {
            player?.replaceCurrentItem(with: item)
        }
        setupObservers()
        activateAudioSession()
        player?.play()
        if playbackRate != 1.0 { player?.rate = Float(playbackRate) }
        isPlaying = true
        updateNowPlayingInfo()
        if let savedTime, savedTime > 5 {
            player?.seek(to: CMTime(seconds: savedTime, preferredTimescale: 600),
                         toleranceBefore: CMTime(seconds: 1, preferredTimescale: 600),
                         toleranceAfter:  CMTime(seconds: 1, preferredTimescale: 600))
        }
    }

    func loadEpisode(_ episode: RSSEpisode, from podcast: PodcastSummary, autoPlay: Bool = true) {
        if currentEpisodeId == episode.id { togglePlayback(); return }

        // Use local file if available
        let audioUrl: URL
        if let localURL = DownloadManager.shared.localURL(for: episode.id) {
            audioUrl = localURL
        } else if let remoteURL = episode.audioUrl {
            audioUrl = remoteURL
        } else {
            return
        }

        savePosition()
        stopObservers()
        player?.pause()

        currentEpisodeId    = episode.id
        currentEpisodeTitle = episode.title
        currentPodcastTitle = podcast.name
        currentPodcast      = podcast
        currentEpisodeDescription = episode.plainDescription
        artworkURL = episode.artworkUrl ?? podcast.artworkURL
        ListeningHistoryStore.shared.record(podcast)
        // Set saved position immediately so the UI never flashes 0:00
        let savedTime = loadSavedPosition(for: episode.id)
        currentTime = (savedTime != nil && savedTime! > 5) ? savedTime! : 0
        totalTime   = 0
        isBuffering = true
        hasLoadedEpisode = true
        chapters = []

        let item = AVPlayerItem(url: audioUrl)
        if player == nil {
            player = AVPlayer(playerItem: item)
            player?.automaticallyWaitsToMinimizeStalling = true
        } else {
            player?.replaceCurrentItem(with: item)
        }

        setupObservers()
        activateAudioSession()
        if autoPlay {
            player?.play()
            if playbackRate != 1.0 { player?.rate = Float(playbackRate) }
            isPlaying = true
        } else {
            isPlaying = false
            isBuffering = false
        }
        updateNowPlayingInfo()

        // Seek AVPlayer to saved position
        if let savedTime, savedTime > 5 {
            player?.seek(to: CMTime(seconds: savedTime, preferredTimescale: 600),
                         toleranceBefore: CMTime(seconds: 1, preferredTimescale: 600),
                         toleranceAfter:  CMTime(seconds: 1, preferredTimescale: 600))
        }

        fetchNowPlayingArtwork(url: episode.artworkUrl ?? podcast.artworkURL)

        // Extract dominant color for player background
        Task {
            let result = await ColorExtractor.shared.extract(from: episode.artworkUrl ?? podcast.artworkURL)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.artworkColor = result.color
                }
            }
        }

        // Fetch chapters: prefer podcast:chapters URL, fall back to description timestamps
        if let chaptersUrlStr = episode.chaptersUrl {
            Task { await fetchChapters(from: chaptersUrlStr) }
        } else {
            let parsed = Self.parseChaptersFromDescription(episode.description)
            if !parsed.isEmpty {
                print("[Chapters] Parsed \(parsed.count) chapters from description")
                chapters = parsed
            }
        }

        // Add to recently played
        addToRecentlyPlayed(episode: episode, podcast: podcast)
    }

    // MARK: - Recently Played
    private func addToRecentlyPlayed(episode: RSSEpisode, podcast: PodcastSummary) {
        recentlyPlayed.removeAll { $0.id == episode.id }
        let entry = RecentlyPlayedEntry(id: episode.id, episode: episode, podcast: podcast, playedAt: Date())
        recentlyPlayed.insert(entry, at: 0)
        if recentlyPlayed.count > 20 { recentlyPlayed = Array(recentlyPlayed.prefix(20)) }
        saveRecentlyPlayed()
    }

    private func saveRecentlyPlayed() {
        if let data = try? JSONEncoder().encode(recentlyPlayed) {
            UserDefaults.standard.set(data, forKey: Self.recentlyPlayedKey)
        }
    }

    private func loadRecentlyPlayed() {
        guard let data = UserDefaults.standard.data(forKey: Self.recentlyPlayedKey),
              let decoded = try? JSONDecoder().decode([RecentlyPlayedEntry].self, from: data) else { return }
        recentlyPlayed = decoded
    }

    // MARK: - Chapters
    func fetchChapters(from urlString: String) async {
        print("[Chapters] Fetching from: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("[Chapters] Invalid URL")
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(PodcastChaptersResponse.self, from: data)
            print("[Chapters] Loaded \(response.chapters.count) chapters")
            await MainActor.run { self.chapters = response.chapters }
        } catch {
            print("[Chapters] Failed: \(error)")
        }
    }

    /// Parse chapter timestamps from episode description text.
    /// Matches common patterns: (00:00) Title, 00:00 - Title, [00:00] Title, 00:00 Title
    /// Supports both MM:SS and HH:MM:SS formats.
    static func parseChaptersFromDescription(_ text: String) -> [PodcastChapter] {
        // Strip HTML tags for clean matching
        let plain = text.replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression)
        // Match timestamps like (00:00), [00:00], 00:00 followed by a title
        let pattern = #"[\(\[]?(\d{1,2}:\d{2}(?::\d{2})?)[\)\]]?\s*[-–—:]?\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return [] }

        let nsString = plain as NSString
        let results = regex.matches(in: plain, range: NSRange(location: 0, length: nsString.length))

        var chapters: [PodcastChapter] = []
        for match in results {
            guard match.numberOfRanges >= 3 else { continue }
            let timeStr = nsString.substring(with: match.range(at: 1))
            let title = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)

            guard !title.isEmpty else { continue }

            // Parse time components
            let parts = timeStr.split(separator: ":").compactMap { Double($0) }
            let seconds: Double
            if parts.count == 3 {
                seconds = parts[0] * 3600 + parts[1] * 60 + parts[2]
            } else if parts.count == 2 {
                seconds = parts[0] * 60 + parts[1]
            } else { continue }

            chapters.append(PodcastChapter(startTime: seconds, title: title, img: nil, url: nil))
        }

        // Only return if we found a reasonable number (3+) to avoid false positives
        guard chapters.count >= 3 else { return [] }
        // Sort by start time and deduplicate
        return chapters.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Playback Controls
    func togglePlayback() { isPlaying ? pause() : play() }

    func play() {
        activateAudioSession()
        player?.play()
        if playbackRate != 1.0 { player?.rate = Float(playbackRate) }
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        savePosition()
    }

    func skipForward(seconds: Double? = nil) { seek(to: min(currentTime + (seconds ?? Double(skipForwardInterval)), totalTime)) }
    func skipBackward(seconds: Double? = nil) { seek(to: max(currentTime - (seconds ?? Double(skipBackInterval)), 0)) }

    func seek(to seconds: Double) {
        // Update time immediately so the UI feels instant
        currentTime = seconds

        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        // Use ±0.5s tolerance for fast seeking (frame-accurate .zero is very slow for podcasts)
        let tolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateNowPlayingInfo()
            }
        }
    }

    // MARK: - Speed Control
    func cyclePlaybackRate() {
        let rates = Self.availableRates
        let current = rates.firstIndex(of: playbackRate) ?? 1
        playbackRate = rates[(current + 1) % rates.count]
        if isPlaying { player?.rate = Float(playbackRate) }
        updateNowPlayingInfo()
    }

    func setPlaybackRate(_ rate: Double) {
        playbackRate = rate
        if isPlaying { player?.rate = Float(rate) }
        updateNowPlayingInfo()
    }

    private func updateRemoteSkipIntervals() {
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: skipForwardInterval)]
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBackInterval)]
    }

    // MARK: - Sleep Timer
    func setSleepTimer(minutes: Double?) {
        sleepTimer?.invalidate()
        sleepTimer = nil
        guard let m = minutes else { sleepTimerRemaining = nil; return }
        sleepTimerRemaining = m * 60
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let remaining = self.sleepTimerRemaining else { return }
            if remaining <= 1 {
                self.sleepTimerRemaining = nil
                self.sleepTimer?.invalidate()
                self.sleepTimer = nil
                self.pause()
            } else {
                self.sleepTimerRemaining = remaining - 1
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        sleepTimer = timer
    }

    var sleepTimerLabel: String {
        guard let remaining = sleepTimerRemaining else { return "" }
        let m = Int(remaining) / 60
        let s = Int(remaining) % 60
        return m > 0 ? (s > 0 ? "\(m)m \(s)s" : "\(m)m") : "\(s)s"
    }

    // MARK: - Bookmarks
    private static let bookmarksKey = "podcastBookmarks"

    func saveBookmark(_ bookmark: PodcastBookmark) {
        bookmarks.insert(bookmark, at: 0)
        persistBookmarks()
    }

    func deleteBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        persistBookmarks()
    }

    func bookmarksForCurrentEpisode() -> [PodcastBookmark] {
        bookmarks.filter { $0.episodeId == currentEpisodeId }
    }

    private func persistBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: Self.bookmarksKey)
        }
    }

    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarksKey),
              let decoded = try? JSONDecoder().decode([PodcastBookmark].self, from: data) else { return }
        bookmarks = decoded
    }

    // MARK: - Play Latest
    func playLatest(podcast: PodcastSummary) async {
        await MainActor.run { isLoadingLatest = true }
        do {
            guard let detail = try await PodcastService.shared.lookupPodcast(id: podcast.id),
                  let feedUrl = detail.feedUrl else {
                await MainActor.run { isLoadingLatest = false }; return
            }
            let feed = try await PodcastService.shared.fetchFeed(feedUrl: feedUrl, podcastTitle: podcast.name)
            guard let episode = feed.episodes.first else {
                await MainActor.run { isLoadingLatest = false }; return
            }
            await MainActor.run { isLoadingLatest = false; loadEpisode(episode, from: podcast) }
        } catch {
            await MainActor.run { isLoadingLatest = false }
        }
    }

    // MARK: - Position Persistence
    private func savePosition() {
        guard !currentEpisodeId.isEmpty, currentTime > 5 else { return }
        var positions = UserDefaults.standard.dictionary(forKey: Self.positionKey) as? [String: Double] ?? [:]
        positions[currentEpisodeId] = currentTime
        UserDefaults.standard.set(positions, forKey: Self.positionKey)
    }

    private func loadSavedPosition(for id: String) -> Double? {
        (UserDefaults.standard.dictionary(forKey: Self.positionKey) as? [String: Double])?[id]
    }

    private func clearPosition(for id: String) {
        var positions = UserDefaults.standard.dictionary(forKey: Self.positionKey) as? [String: Double] ?? [:]
        positions.removeValue(forKey: id)
        UserDefaults.standard.set(positions, forKey: Self.positionKey)
    }

    // MARK: - KVO + Time Observer
    private func setupObservers() {
        guard let player else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let secs = CMTimeGetSeconds(time)
            if secs.isFinite {
                if !self.isScrubbing { self.currentTime = secs }
                if Int(secs) % 10 == 0 && secs > 5 { self.savePosition() }
            }
        }

        durationObserver = player.currentItem?.observe(\.duration, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                let d = CMTimeGetSeconds(item.duration)
                if d.isFinite && d > 0 { self?.totalTime = d; self?.updateNowPlayingInfo() }
            }
        }

        statusObserver = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async { self?.isBuffering = (item.status == .unknown) }
        }

        rateObserver = player.observe(\.rate, options: [.new]) { [weak self] p, _ in
            DispatchQueue.main.async { self?.isBuffering = (p.rate == 0 && self?.isPlaying == true) }
        }

        bufferingObserver = player.currentItem?.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async { self?.isBuffering = !item.isPlaybackLikelyToKeepUp }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }

    private func stopObservers() {
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
        durationObserver?.invalidate(); durationObserver = nil
        statusObserver?.invalidate();   statusObserver = nil
        rateObserver?.invalidate();     rateObserver = nil
        bufferingObserver?.invalidate(); bufferingObserver = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    @objc private func playerDidFinish() {
        DispatchQueue.main.async {
            self.clearPosition(for: self.currentEpisodeId)
            self.isPlaying = false
            self.currentTime = 0
            self.player?.seek(to: .zero)
            self.updateNowPlayingInfo()

            // Auto-advance queue
            if let queueStore = self.queueStore, let next = queueStore.dequeue() {
                self.loadEpisode(next.episode, from: next.podcast)
            }
        }
    }

    // MARK: - Now Playing Info
    private func fetchNowPlayingArtwork(url: URL?) {
        guard let url else { updateNowPlayingInfo(); return }
        Task {
            // Use ImageCache to avoid re-downloading artwork
            let image: UIImage
            if let cached = ImageCache.shared.image(for: url) {
                image = cached
            } else if let (data, _) = try? await URLSession.shared.data(from: url),
                      let downloaded = UIImage(data: data) {
                ImageCache.shared.store(downloaded, for: url)
                image = downloaded
            } else {
                await MainActor.run { self.updateNowPlayingInfo() }
                return
            }
            await MainActor.run {
                self.nowPlayingArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.updateNowPlayingInfo()
            }
        }
    }

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle:                    currentEpisodeTitle,
            MPMediaItemPropertyArtist:                   currentPodcastTitle,
            MPMediaItemPropertyPlaybackDuration:         totalTime,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate:        isPlaying ? playbackRate : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: playbackRate,
        ]
        if let artwork = nowPlayingArtwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Computed
    var formattedCurrentTime: String { format(currentTime) }
    var formattedTotalTime:   String { format(totalTime) }
    var formattedRemainingTime: String {
        let remaining = max(totalTime - currentTime, 0)
        return "-" + format(remaining)
    }
    var progress: Double { totalTime > 0 ? min(currentTime / totalTime, 1.0) : 0 }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    func isCurrentEpisode(_ episode: RSSEpisode) -> Bool { currentEpisodeId == episode.id }
}
