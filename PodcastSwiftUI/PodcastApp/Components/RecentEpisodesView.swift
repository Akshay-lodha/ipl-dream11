import SwiftUI

// Repurposed as "Top Charts" list using real TopPodcast data
struct TopChartsListView: View {
    let podcasts: [TopPodcast]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Charts")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                NavigationLink(destination: TopChartsFullView(podcasts: podcasts)) {
                    Text("See All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 20)

            if podcasts.isEmpty {
                TopChartsListSkeleton()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(podcasts.prefix(6).enumerated()), id: \.element.id) { index, podcast in
                        TopChartRow(podcast: podcast, rank: index + 1)
                        if index < 5 {
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.leading, 76)
                        }
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
            }
        }
    }
}

struct TopChartRow: View {
    let podcast: TopPodcast
    let rank: Int
    @EnvironmentObject var followingStore: FollowingStore
    @State private var isPressed = false

    var body: some View {
        // ZStack: NavigationLink in back, row content in front.
        // The Follow button (front) intercepts its own taps; other row taps reach the NavigationLink.
        ZStack {
            NavigationLink(value: podcast.summary) {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .center)

                CachedAsyncImage(url: podcast.artworkURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(ProgressView().scaleEffect(0.6))
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(podcast.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(podcast.artistName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let genre = podcast.primaryGenre {
                        Text(genre)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    followingStore.toggle(podcast)
                }) {
                    let following = followingStore.isFollowing(podcast)
                    Text(following ? "Following" : "+ Follow")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(following ? .secondary : Color.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().stroke(following ? Color.secondary : Color.accentColor, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isPressed ? Color.white.opacity(0.05) : Color.clear)
        }
    }
}

// MARK: - Skeleton
struct TopChartsListSkeleton: View {
    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(shimmer ? 0.1 : 0.05))
                        .frame(width: 24, height: 16)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(shimmer ? 0.1 : 0.05))
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(shimmer ? 0.1 : 0.05))
                            .frame(width: 140, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(shimmer ? 0.07 : 0.03))
                            .frame(width: 90, height: 12)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if i < 4 {
                    Divider().background(Color.white.opacity(0.08)).padding(.leading, 76)
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Full Top Charts (See All)
struct TopChartsFullView: View {
    let podcasts: [TopPodcast]

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(podcasts.enumerated()), id: \.element.id) { index, podcast in
                        TopChartRow(podcast: podcast, rank: index + 1)
                        if index < podcasts.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.08))
                                .padding(.leading, 76)
                        }
                    }
                    Color.clear.frame(height: 80)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Top Charts")
        .navigationBarTitleDisplayMode(.large)
    }
}
