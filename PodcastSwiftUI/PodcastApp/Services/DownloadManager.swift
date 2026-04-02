import Foundation

private let kDownloadedEpisodesKey = "downloadedEpisodes_v1"

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    enum DownloadState {
        case downloading(Double)
        case downloaded(URL)
        case failed
    }

    @Published var downloads: [String: DownloadState] = [:]
    // Metadata for all completed downloads — persisted across launches
    @Published private(set) var downloadedEpisodes: [String: RSSEpisode] = [:]

    private var tasks: [String: URLSessionDownloadTask] = [:]
    private var observations: [String: NSKeyValueObservation] = [:]

    private init() {
        restoreEpisodeMetadata()
        scanExistingDownloads()
    }

    // MARK: - Persistence

    private func restoreEpisodeMetadata() {
        guard let data = UserDefaults.standard.data(forKey: kDownloadedEpisodesKey),
              let decoded = try? JSONDecoder().decode([String: RSSEpisode].self, from: data)
        else { return }
        downloadedEpisodes = decoded
    }

    private func persistEpisodeMetadata() {
        guard let data = try? JSONEncoder().encode(downloadedEpisodes) else { return }
        UserDefaults.standard.set(data, forKey: kDownloadedEpisodesKey)
    }

    // MARK: - Scanning

    private func scanExistingDownloads() {
        let dir = documentsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasPrefix("podcast-") && file.pathExtension == "mp4" {
            let name = file.deletingPathExtension().lastPathComponent
            let episodeId = String(name.dropFirst("podcast-".count))
            if FileManager.default.fileExists(atPath: file.path) {
                downloads[episodeId] = .downloaded(file)
            }
        }
        // Prune metadata for episodes whose files no longer exist
        let activeIds = Set(downloads.keys)
        downloadedEpisodes = downloadedEpisodes.filter { activeIds.contains($0.key) }
    }

    // MARK: - Public API

    func download(episode: RSSEpisode) {
        guard let audioUrl = episode.audioUrl else { return }
        guard downloads[episode.id] == nil else { return }
        DispatchQueue.main.async { self.downloads[episode.id] = .downloading(0) }

        let task = URLSession.shared.downloadTask(with: audioUrl) { [weak self] tempURL, _, error in
            let id = episode.id
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    let cancelled = (error as? URLError)?.code == .cancelled
                    if !cancelled {
                        self.downloads[id] = .failed
                    }
                    self.tasks.removeValue(forKey: id)
                    self.observations.removeValue(forKey: id)
                    return
                }
                guard let tempURL else {
                    self.downloads[id] = .failed
                    self.tasks.removeValue(forKey: id)
                    self.observations.removeValue(forKey: id)
                    return
                }
                let dest = self.fileURL(for: id)
                try? FileManager.default.removeItem(at: dest)
                do {
                    try FileManager.default.moveItem(at: tempURL, to: dest)
                    self.downloads[id] = .downloaded(dest)
                    self.downloadedEpisodes[id] = episode
                    self.persistEpisodeMetadata()
                } catch {
                    print("Move failed: \(error)")
                    self.downloads[id] = .failed
                }
                self.tasks.removeValue(forKey: id)
                self.observations.removeValue(forKey: id)
            }
        }

        observations[episode.id] = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.downloads[episode.id] = .downloading(progress.fractionCompleted)
            }
        }

        tasks[episode.id] = task
        task.resume()
    }

    func cancel(episode: RSSEpisode) {
        tasks[episode.id]?.cancel()
        tasks.removeValue(forKey: episode.id)
        observations.removeValue(forKey: episode.id)
        DispatchQueue.main.async { self.downloads.removeValue(forKey: episode.id) }
    }

    func delete(episode: RSSEpisode) {
        tasks[episode.id]?.cancel()
        tasks.removeValue(forKey: episode.id)
        let dest = fileURL(for: episode.id)
        try? FileManager.default.removeItem(at: dest)
        DispatchQueue.main.async {
            self.downloads.removeValue(forKey: episode.id)
            self.downloadedEpisodes.removeValue(forKey: episode.id)
            self.persistEpisodeMetadata()
        }
    }

    func localURL(for episodeId: String) -> URL? {
        let url = fileURL(for: episodeId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func isDownloaded(_ id: String) -> Bool {
        if case .downloaded = downloads[id] { return true }
        return false
    }

    // Formatted total size of all downloaded files
    var totalSizeFormatted: String {
        let dir = documentsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return "0 MB" }
        let total = files
            .filter { $0.lastPathComponent.hasPrefix("podcast-") }
            .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
            .reduce(0, +)
        let gb = Double(total) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(total) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    // MARK: - Private helpers

    private func fileURL(for episodeId: String) -> URL {
        let safe = episodeId
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return documentsDirectory().appendingPathComponent("podcast-\(safe).mp4")
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
