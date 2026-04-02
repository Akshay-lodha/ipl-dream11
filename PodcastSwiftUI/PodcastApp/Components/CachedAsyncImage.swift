import SwiftUI
import UIKit
import CryptoKit

// MARK: - Image Cache (Memory + Disk)
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    // MARK: Memory layer
    private let memory: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 200
        c.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        return c
    }()

    // MARK: Disk layer
    private let diskQueue = DispatchQueue(label: "ImageCache.disk", qos: .utility)
    private let diskURL: URL
    private let maxDiskBytes: Int = 200 * 1024 * 1024 // 200 MB

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskURL, withIntermediateDirectories: true)
        // Trim disk cache in background on launch
        diskQueue.async { [diskURL, maxDiskBytes] in
            ImageCache.trimDisk(directory: diskURL, maxBytes: maxDiskBytes)
        }
    }

    // MARK: - Public API

    /// Check memory → disk. Returns nil if not cached anywhere.
    func image(for url: URL) -> UIImage? {
        // 1. Memory hit
        if let img = memory.object(forKey: url as NSURL) { return img }
        // 2. Disk hit → promote to memory
        let path = diskPath(for: url)
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let img = UIImage(data: data) else { return nil }
        let cost = memoryCost(for: img)
        memory.setObject(img, forKey: url as NSURL, cost: cost)
        // Touch file so LRU eviction keeps it
        diskQueue.async {
            try? FileManager.default.setAttributes(
                [.modificationDate: Date()], ofItemAtPath: path.path
            )
        }
        return img
    }

    /// Store to memory + write JPEG to disk asynchronously.
    func store(_ image: UIImage, for url: URL) {
        let cost = memoryCost(for: image)
        memory.setObject(image, forKey: url as NSURL, cost: cost)
        let path = diskPath(for: url)
        diskQueue.async {
            guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
            try? jpeg.write(to: path, options: .atomic)
        }
    }

    /// Pre-download images not yet in cache. Fire-and-forget.
    func prefetch(urls: [URL]) {
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                var inflight = 0
                for url in urls {
                    if self.image(for: url) != nil { continue } // already cached
                    if inflight >= 6 { await group.next(); inflight -= 1 }
                    inflight += 1
                    group.addTask {
                        guard let (data, _) = try? await URLSession.shared.data(from: url),
                              let img = UIImage(data: data) else { return }
                        self.store(img, for: url)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func diskPath(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = hash.compactMap { String(format: "%02x", $0) }.joined()
        return diskURL.appendingPathComponent(name + ".jpg")
    }

    private func memoryCost(for image: UIImage) -> Int {
        Int(image.size.width * image.size.height * image.scale * image.scale * 4)
    }

    /// Remove oldest files until total size is under maxBytes.
    private static func trimDisk(directory: URL, maxBytes: Int) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }

        var entries: [(url: URL, date: Date, size: Int)] = files.compactMap { fileURL in
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let date = values.contentModificationDate, let size = values.fileSize else { return nil }
            return (fileURL, date, size)
        }

        let totalSize = entries.reduce(0) { $0 + $1.size }
        guard totalSize > maxBytes else { return }

        // Sort oldest first
        entries.sort { $0.date < $1.date }
        var removed = 0
        for entry in entries {
            guard totalSize - removed > maxBytes else { break }
            try? fm.removeItem(at: entry.url)
            removed += entry.size
        }
    }
}

// MARK: - CachedAsyncImage
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage? = nil

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else { return }
        if let cached = ImageCache.shared.image(for: url) {
            uiImage = cached
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return }
        ImageCache.shared.store(image, for: url)
        uiImage = image
    }
}
