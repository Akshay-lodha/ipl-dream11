import SwiftUI

// MARK: - Home Footer

struct HomeFooterView: View {
    let podcasts: [TopPodcast]

    private var row1: [TopPodcast] {
        stride(from: 0, to: podcasts.count, by: 2).map { podcasts[$0] }
    }
    private var row2: [TopPodcast] {
        stride(from: 1, to: podcasts.count, by: 2).map { podcasts[$0] }
    }

    var body: some View {
        VStack(spacing: 20) {

            // ── Text ─────────────────────────────────────────────────
            VStack(spacing: 6) {
                Text("Explore, Listen, and Enjoy.")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text("Built with love by Akshay Lodha")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            // ── Marquee rows ─────────────────────────────────────────
            VStack(spacing: 12) {
                MarqueeRow(podcasts: row1, direction: .left,  fadeWidth: 90,  speed: 18)
                MarqueeRow(podcasts: row2, direction: .right, fadeWidth: 110, speed: 14)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear,                              location: 0.0),
                        .init(color: Color(hex: "#0A0A0A").opacity(0.7),  location: 0.55),
                        .init(color: Color(hex: "#0A0A0A"),               location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 56)
                .allowsHitTesting(false)
            }
        }
        .padding(.vertical, 24)
    }
}

// MARK: - Marquee Row (TimelineView — offset computed from wall clock, never stops)

private enum ScrollDirection { case left, right }

private struct MarqueeRow: View {
    let podcasts: [TopPodcast]
    let direction: ScrollDirection
    var fadeWidth: CGFloat = 90
    var speed: Double = 40          // points per second

    private let artworkSize: CGFloat = 88
    private let spacing: CGFloat    = 14

    private var items: [TopPodcast] { podcasts + podcasts + podcasts }
    private var itemWidth: CGFloat  { artworkSize + spacing }
    private var loopWidth: Double   { Double(podcasts.count) * Double(itemWidth) }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: artworkSize)
            .overlay(alignment: .leading) {
                if podcasts.isEmpty {
                    // Stable skeleton — height never changes before data arrives
                    HStack(spacing: spacing) {
                        ForEach(0..<8, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.11))
                                .frame(width: artworkSize, height: artworkSize)
                        }
                    }
                } else {
                    // TimelineView drives offset from wall clock — immune to SwiftUI
                    // animation cancellation, LazyVStack recreation, or scroll events.
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { tl in
                        let elapsed = tl.date.timeIntervalSinceReferenceDate
                        let raw     = (elapsed * speed).truncatingRemainder(dividingBy: loopWidth)
                        let offset  = direction == .left
                            ? -CGFloat(raw)
                            : -(CGFloat(loopWidth) - CGFloat(raw))

                        HStack(spacing: spacing) {
                            ForEach(Array(items.enumerated()), id: \.offset) { _, podcast in
                                CachedAsyncImage(url: podcast.artworkURL) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.11))
                                }
                                .frame(width: artworkSize, height: artworkSize)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(.white.opacity(0.20), lineWidth: 1)
                                )
                            }
                        }
                        .offset(x: offset)
                    }
                }
            }
            .clipped()
            .overlay(alignment: .leading) {
                HStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#0A0A0A"),                location: 0.00),
                            .init(color: Color(hex: "#0A0A0A").opacity(0.95),  location: 0.15),
                            .init(color: Color(hex: "#0A0A0A").opacity(0.80),  location: 0.35),
                            .init(color: Color(hex: "#0A0A0A").opacity(0.50),  location: 0.60),
                            .init(color: Color(hex: "#0A0A0A").opacity(0.18),  location: 0.82),
                            .init(color: .clear,                               location: 1.00),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: fadeWidth)
                    Spacer()
                    LinearGradient(
                        stops: [
                            .init(color: .clear,                               location: 0.00),
                            .init(color: Color(hex: "#0A0A0A").opacity(0.18),  location: 0.18),
                            .init(color: Color(hex: "#0A0A0A").opacity(0.50),  location: 0.40),
                            .init(color: Color(hex: "#0A0A0A").opacity(0.80),  location: 0.65),
                            .init(color: Color(hex: "#0A0A0A").opacity(0.95),  location: 0.85),
                            .init(color: Color(hex: "#0A0A0A"),                location: 1.00),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: fadeWidth)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
    }
}
