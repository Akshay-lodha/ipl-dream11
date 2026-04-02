import SwiftUI
import CoreImage
import UIKit

struct FeaturedCarouselView: View {
    let podcasts: [TopPodcast]
    var zoomNamespace: Namespace.ID
    @State private var currentIndex: Int = 0

    var body: some View {
        if podcasts.isEmpty {
            CarouselSkeleton()
        } else {
            let summaries = podcasts.prefix(10).map { $0.summary }
            TabView(selection: $currentIndex) {
                ForEach(Array(podcasts.prefix(10).enumerated()), id: \.element.id) { index, podcast in
                    FeaturedPodcastCard(
                        podcast: podcast,
                        allSummaries: Array(summaries),
                        cardIndex: index,
                        zoomNamespace: zoomNamespace
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 590)
            .matchedTransitionSource(id: "carousel", in: zoomNamespace)
            .overlay(alignment: .bottom) {
                HStack(spacing: 6) {
                    ForEach(0..<min(podcasts.count, 10), id: \.self) { index in
                        Capsule()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.35))
                            .frame(width: index == currentIndex ? 20 : 7, height: 7)
                            .animation(.spring(response: 0.3), value: currentIndex)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Individual Card
struct FeaturedPodcastCard: View {
    let podcast: TopPodcast
    let allSummaries: [PodcastSummary]
    let cardIndex: Int
    var zoomNamespace: Namespace.ID
    @EnvironmentObject var followingStore: FollowingStore
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var navCoordinator: NavigationCoordinator

    @State private var artworkScale: CGFloat = 1.0
    @State private var shimmerPhase: CGFloat = -0.5   // sweeps from -0.5 → 1.5
    @State private var bgColor: Color = Color(hex: "#1A1A2E")
    @State private var isLightBg: Bool = false

    private var statusBarHeight: CGFloat {
        let h = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 0
        return max(h, 59)
    }

    // Adaptive colors based on background luminance
    private var primaryText: Color    { isLightBg ? Color(hex: "#111111") : .white }
    private var secondaryText: Color  { isLightBg ? Color(hex: "#333333").opacity(0.7) : .white.opacity(0.7) }
    private var labelText: Color      { isLightBg ? Color(hex: "#111111").opacity(0.7) : .white.opacity(0.75) }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            navCoordinator.navigate(to: PodcastDetailDestination(podcasts: allSummaries, startIndex: cardIndex))
        } label: {
        GeometryReader { geo in
            let globalMinX = geo.frame(in: .global).minX
            let artworkParallax = -(globalMinX * 0.25)

            ZStack {

                // Dominant color background — extracted from artwork via Core Image
                bgColor
                    .ignoresSafeArea(edges: .top)

                // Lighter at top, darker at bottom
                LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.clear],
                    startPoint: .top, endPoint: .center
                )
                .ignoresSafeArea(edges: .top)
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.28)],
                    startPoint: .center, endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 0) {
                    // Header label
                    HStack(spacing: 6) {
                        Image("Left")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("TOP PICKS FOR YOU")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(1.5)
                        Image("Right")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                    }
                    .foregroundStyle(labelText)
                    .padding(.top, statusBarHeight + 16)
                    .padding(.bottom, 20)

                    // Artwork — parallax + shimmer
                    CachedAsyncImage(url: podcast.artworkURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.1))
                            .overlay(ProgressView().tint(.white))
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.32), .clear],
                            startPoint: UnitPoint(x: shimmerPhase - 0.5,
                                                  y: shimmerPhase - 0.5),
                            endPoint:   UnitPoint(x: shimmerPhase + 0.5,
                                                  y: shimmerPhase + 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
                    .scaleEffect(artworkScale)
                    .offset(x: artworkParallax)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                            artworkScale = 1.03
                        }
                    }

                    // Name
                    Text(podcast.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        .padding(.bottom, 4)

                    // Artist
                    Text(podcast.artistName)
                        .font(.system(size: 14))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                        .padding(.bottom, 20)

                    // Buttons: [Play Latest — hug width] [♥]
                    let isFollowing = followingStore.isFollowing(podcast)
                    let heartSize: CGFloat = 48

                    HStack(spacing: 12) {
                        Button {
                            Task { await player.playLatest(podcast: podcast.summary) }
                        } label: {
                            HStack(spacing: 6) {
                                if player.isLoadingLatest {
                                    ProgressView().tint(.white)
                                        .frame(width: 60)
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Play Latest")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .frame(height: heartSize)
                            .contentShape(Capsule())
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .disabled(player.isLoadingLatest)

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            followingStore.toggle(podcast)
                        } label: {
                            Image(systemName: isFollowing ? "heart.fill" : "heart")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: heartSize, height: heartSize)
                                .contentShape(Circle())
                        }
                        .glassEffect(.regular.interactive(), in: .circle)
                        .scaleEffect(isFollowing ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isFollowing)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Description — real text or native capsule skeleton
                    if let desc = podcast.podcastDescription {
                        Text(desc)
                            .font(.system(size: 15))
                            .foregroundStyle(primaryText.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 20)
                            .transition(.opacity.animation(.easeIn(duration: 0.3)))
                    } else {
                        // Native capsule skeleton lines
                        VStack(spacing: 8) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(maxWidth: .infinity)
                                .frame(height: 13)
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(maxWidth: .infinity)
                                .frame(height: 13)
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 140)
                                .frame(height: 13)
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 20)
                    }

                    Spacer(minLength: 0)
                }
                .frame(width: geo.size.width)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        // Extract dominant color once per podcast
        .task(id: podcast.id) {
            let result = await ColorExtractor.shared.extract(from: podcast.artworkURL)
            withAnimation(.easeInOut(duration: 0.4)) {
                bgColor = result.color
                isLightBg = result.isLight
            }
        }
        // Shimmer re-fires every time this card scrolls into view.
        // .onAppear on the GeometryReader fires reliably on every page swipe in a TabView.
        // We reset shimmerPhase without animation, wait one frame, then animate — so the
        // "off screen top-left" starting position actually renders before the sweep begins.
        .onAppear {
            Task { @MainActor in
                shimmerPhase = -0.5
                try? await Task.sleep(nanoseconds: 16_000_000) // ~1 frame @ 60 fps
                withAnimation(.linear(duration: 1.2)) {
                    shimmerPhase = 1.5
                }
            }
        }
        } // Button
        .buttonStyle(.plain)
    }
}

// MARK: - Dominant Color Extractor
/// Extracts average color from an image URL using Core Image, boosts saturation,
/// and determines if the background is light (so text can switch to dark).
actor ColorExtractor {
    static let shared = ColorExtractor()

    struct Result {
        let color: Color
        let isLight: Bool
    }

    private var cache: [URL: Result] = [:]
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

    func extract(from url: URL?) async -> Result {
        let fallback = Result(color: Color(hex: "#1A1A2E"), isLight: false)
        guard let url else { return fallback }
        if let cached = cache[url] { return cached }

        // Use ImageCache to avoid re-downloading artwork
        let uiImage: UIImage
        if let cached = ImageCache.shared.image(for: url) {
            uiImage = cached
        } else if let (data, _) = try? await URLSession.shared.data(from: url),
                  let downloaded = UIImage(data: data) {
            ImageCache.shared.store(downloaded, for: url)
            uiImage = downloaded
        } else {
            return fallback
        }

        guard let result = average(image: uiImage) else { return fallback }
        cache[url] = result
        return result
    }

    private func average(image: UIImage) -> Result? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
        ])
        guard let output = filter?.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &bitmap, rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        let r = CGFloat(bitmap[0]) / 255
        let g = CGFloat(bitmap[1]) / 255
        let b = CGFloat(bitmap[2]) / 255

        // Boost saturation so the averaged color is vivid, not muddy
        let raw = UIColor(red: r, green: g, blue: b, alpha: 1)
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        raw.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        let boostedSat = min(sat * 1.6, 1.0)
        let boostedBri = min(max(bri, 0.25), 0.88)
        let vivid = UIColor(hue: hue, saturation: boostedSat, brightness: boostedBri, alpha: 1)

        // WCAG relative luminance to decide dark vs light text
        let rL = r <= 0.04045 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let gL = g <= 0.04045 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let bL = b <= 0.04045 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        let luminance = 0.2126 * rL + 0.7152 * gL + 0.0722 * bL

        return Result(color: Color(vivid), isLight: luminance > 0.35)
    }
}

// MARK: - Loading Skeleton
struct CarouselSkeleton: View {
    @State private var shimmer = false

    var body: some View {
        ZStack {
            Color(hex: "#1A0A30")
            VStack(spacing: 20) {
                Spacer()
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(shimmer ? 0.12 : 0.06))
                    .frame(width: 180, height: 180)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(shimmer ? 0.12 : 0.06))
                    .frame(width: 160, height: 22)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(shimmer ? 0.08 : 0.04))
                    .frame(width: 100, height: 16)
                HStack(spacing: 12) {
                    Capsule().fill(Color.white.opacity(shimmer ? 0.1 : 0.05)).frame(height: 50)
                    Capsule().fill(Color.white.opacity(shimmer ? 0.1 : 0.05)).frame(height: 50)
                }
                .padding(.horizontal, 24)
                Spacer()
            }
        }
        .frame(height: 520)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}
