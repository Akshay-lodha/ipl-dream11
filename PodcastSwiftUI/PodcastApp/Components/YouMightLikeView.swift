import SwiftUI

// MARK: - Section View

struct YouMightLikeView: View {
    let podcasts: [TopPodcast]
    var zoomNamespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header — taps navigate to full grid
            NavigationLink(value: YouMightLikeDestination()) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text("You might like")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Text("Based on your listening.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: "yml_header", in: zoomNamespace)
            .padding(.horizontal, 20)

            if podcasts.isEmpty {
                YouMightLikeSkeleton()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(podcasts.enumerated()), id: \.element.id) { index, podcast in
                            YouMightLikeCard(podcast: podcast, allPodcasts: podcasts, cardIndex: index, zoomNamespace: zoomNamespace, sourceIDPrefix: "yml_h")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Full Grid Page

struct YouMightLikeGridView: View {
    let podcasts: [TopPodcast]
    var zoomNamespace: Namespace.ID

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(Array(podcasts.enumerated()), id: \.element.id) { index, podcast in
                        YouMightLikeCard(podcast: podcast, allPodcasts: podcasts, cardIndex: index, zoomNamespace: zoomNamespace, sourceIDPrefix: "yml_g")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("You Might Like")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Card

struct YouMightLikeCard: View {
    let podcast: TopPodcast
    let allPodcasts: [TopPodcast]
    let cardIndex: Int
    var zoomNamespace: Namespace.ID
    var sourceIDPrefix: String = "yml"

    @EnvironmentObject private var navCoordinator: NavigationCoordinator

    private let artworkSize: CGFloat = 176
    private let padding: CGFloat = 10
    private var cardW: CGFloat { artworkSize + padding * 2 }
    private var sourceID: String { "\(sourceIDPrefix)_\(podcast.id)" }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            navCoordinator.navigate(to: PodcastNavDestination(podcasts: allPodcasts.map(\.summary), startIndex: cardIndex, zoomSourceID: sourceID))
        } label: {
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    // Artwork — padded with its own corner radius
                    CachedAsyncImage(url: podcast.artworkURL) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                    }
                    .frame(width: artworkSize, height: artworkSize)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.top, padding)
                    .padding(.horizontal, padding)

                    // Text below artwork
                    VStack(alignment: .leading, spacing: 3) {
                        Text(podcast.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(podcast.artistName)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
            }
            .frame(width: cardW)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .hoverEffect(.highlight)
    }
}

// MARK: - Skeleton

private struct YouMightLikeSkeleton: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 175, height: 175)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 120, height: 14)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 80, height: 12)
                    }
                    .frame(width: 175)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
}
