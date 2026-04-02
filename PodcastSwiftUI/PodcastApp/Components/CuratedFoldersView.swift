import SwiftUI
import CoreMotion

// MARK: - Motion Manager

final class MotionManager: ObservableObject {
    static let shared = MotionManager()
    private init() {}

    @Published var x: CGFloat = 0
    @Published var y: CGFloat = 0

    private let manager  = CMMotionManager()
    private var refCount = 0

    func start() {
        refCount += 1
        guard refCount == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let clamp: (Double) -> CGFloat = { CGFloat(max(-1, min(1, $0 / (Double.pi / 8)))) }
            let alpha: CGFloat = 0.12 // low-pass filter — smooths initial IMU spikes
            let rawX = clamp(data.attitude.roll)
            let rawY = clamp(data.attitude.pitch)
            self.x += alpha * (rawX - self.x)
            self.y += alpha * (rawY - self.y)
        }
    }

    func stop() {
        refCount = max(0, refCount - 1)
        if refCount == 0 { manager.stopDeviceMotionUpdates() }
    }
}

// MARK: - Folder Pocket Shape
// Fills the bottom of the card flush to all edges.
// The top edge is a gentle convex arch (peaks in the centre)
// which gives the classic folder-pocket silhouette.

struct FolderPocketShape: Shape, InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let cornerRadius: CGFloat = max(0, 24 - insetAmount)
        let dipDepth: CGFloat = 20
        let dipWidth: CGFloat = r.width * 0.5

        var path = Path()

        // Bottom-left
        path.move(to: CGPoint(x: r.minX, y: r.maxY - cornerRadius))
        path.addQuadCurve(
            to:      CGPoint(x: r.minX + cornerRadius, y: r.maxY),
            control: CGPoint(x: r.minX, y: r.maxY)
        )
        // Bottom edge
        path.addLine(to: CGPoint(x: r.maxX - cornerRadius, y: r.maxY))
        // Bottom-right
        path.addQuadCurve(
            to:      CGPoint(x: r.maxX, y: r.maxY - cornerRadius),
            control: CGPoint(x: r.maxX, y: r.maxY)
        )
        // Right side
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + cornerRadius))
        // Top-right
        path.addQuadCurve(
            to:      CGPoint(x: r.maxX - cornerRadius, y: r.minY),
            control: CGPoint(x: r.maxX, y: r.minY)
        )
        // Folder dip — concave curve in the top edge
        let midX = r.midX
        path.addLine(to: CGPoint(x: midX + dipWidth / 2, y: r.minY))
        path.addQuadCurve(
            to:      CGPoint(x: midX - dipWidth / 2, y: r.minY),
            control: CGPoint(x: midX, y: r.minY + dipDepth)
        )
        // Top-left
        path.addLine(to: CGPoint(x: r.minX + cornerRadius, y: r.minY))
        path.addQuadCurve(
            to:      CGPoint(x: r.minX, y: r.minY + cornerRadius),
            control: CGPoint(x: r.minX, y: r.minY)
        )

        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> FolderPocketShape {
        var s = self
        s.insetAmount += amount
        return s
    }
}

// MARK: - Section View

struct CuratedFoldersView: View {
    let folders: [CuratedFolder]
    var zoomNamespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: CuratedFoldersDestination()) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text("Curated folders")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Text("Handpicked podcasts, curated in folders.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: "curated_folders_header", in: zoomNamespace)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(folders) { folder in
                        FolderCardView(folder: folder, zoomNamespace: zoomNamespace)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - All Folders Grid Page

struct CuratedFoldersGridView: View {
    let folders: [CuratedFolder]
    var zoomNamespace: Namespace.ID

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        GeometryReader { geo in
            let cardWidth = (geo.size.width - 20 * 2 - 16) / 2

            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(folders) { folder in
                            FolderCardView(folder: folder, cardWidth: cardWidth, zoomNamespace: zoomNamespace)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Curated Folders")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Folder Card

struct FolderCardView: View {
    let folder: CuratedFolder
    var cardWidth: CGFloat = 165
    var zoomNamespace: Namespace.ID
    @ObservedObject private var motion = MotionManager.shared
    @EnvironmentObject private var navCoordinator: NavigationCoordinator

    private var scale:        CGFloat { cardWidth / 165 }
    private var cardW:        CGFloat { cardWidth }
    private var cardH:        CGFloat { 205 * scale }
    private var artworkSize:  CGFloat { 112 * scale }
    private var artworkRadius: CGFloat { 14 * scale }
    private var pocketH:      CGFloat { 80 * scale }

    // 3-layer stacking  back → front
    private let rotations:   [Double]              = [-14,  11,  -4]
    private var baseOffsets: [(CGFloat, CGFloat)]  { [(-30 * scale, -22 * scale), (22 * scale, -14 * scale), (0, 4 * scale)] }
    private let scales:      [CGFloat]             = [0.80, 0.90, 1.00]
    private var depths:      [CGFloat]             { [4 * scale, 10 * scale, 17 * scale] }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            navCoordinator.navigate(to: FolderDetailDestination(folderId: folder.id))
        } label: {
        ZStack(alignment: .bottom) {

            // ── Card background — native glass ────────────────────
            Color.clear

            // ── Artwork fan ───────────────────────────────────────
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let hasPodcast = !folder.isLoading && i < folder.podcasts.count
                    if hasPodcast {
                        artworkTile(i, podcast: folder.podcasts[i])
                    } else {
                        skeletonTile(i)
                    }
                }
            }
            .frame(width: cardW, height: cardH)

            // ── Glass folder pocket + text ───────────────────────
            ZStack(alignment: .bottomLeading) {
                FolderPocketShape()
                    .fill(.clear)
                    .glassEffect(.regular, in: FolderPocketShape())

                VStack(alignment: .leading, spacing: 3) {
                    Text(folder.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("10 podcasts")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 14 * scale)
                .padding(.bottom, 16 * scale)
            }
            .frame(width: cardW, height: pocketH)
        }
        .frame(width: cardW, height: cardH)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        .onAppear    { motion.start() }
        .onDisappear { motion.stop()  }
        } // Button
        .buttonStyle(.plain)
        .matchedTransitionSource(id: folder.id, in: zoomNamespace)
    }

    // MARK: - Artwork tile

    @ViewBuilder
    private func artworkTile(_ i: Int, podcast: TopPodcast) -> some View {
        CachedAsyncImage(url: podcast.artworkURL) { img in
            img.resizable().scaledToFill()
        } placeholder: {
            skeletonTile(i)
        }
        .frame(width: artworkSize, height: artworkSize)
        .clipShape(RoundedRectangle(cornerRadius: artworkRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: artworkRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.21), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
        .rotationEffect(.degrees(rotations[i]))
        .scaleEffect(scales[i])
        .offset(
            x: baseOffsets[i].0 + motion.x * depths[i],
            y: baseOffsets[i].1 + motion.y * depths[i]
        )
    }

    // MARK: - Skeleton tile

    @ViewBuilder
    private func skeletonTile(_ i: Int) -> some View {
        RoundedRectangle(cornerRadius: artworkRadius, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .frame(width: artworkSize, height: artworkSize)
            .rotationEffect(.degrees(rotations[i]))
            .scaleEffect(scales[i])
            .offset(x: baseOffsets[i].0, y: baseOffsets[i].1)
    }
}
