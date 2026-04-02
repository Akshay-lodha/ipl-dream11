import SwiftUI

struct FollowingView: View {
    @EnvironmentObject var followingStore: FollowingStore
    @EnvironmentObject var navCoordinator: NavigationCoordinator
    @State private var sortOrder: SortOrder = .recentlyAdded

    enum SortOrder: String, CaseIterable {
        case recentlyAdded = "Recently Added"
        case name = "Name"
        case artist = "Artist"
    }

    private var sortedPodcasts: [TopPodcast] {
        switch sortOrder {
        case .recentlyAdded: return followingStore.followedPodcasts
        case .name: return followingStore.followedPodcasts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .artist: return followingStore.followedPodcasts.sorted { $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if followingStore.followedPodcasts.isEmpty {
                EmptyFollowingView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    // MARK: - Quick Access Bubbles
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Quick Access")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(followingStore.followedPodcasts) { podcast in
                                    FollowingBubble(podcast: podcast)
                                        .onTapGesture {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            navCoordinator.navigate(to: podcast.summary)
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 4)

                    // MARK: - Sort + Count Bar
                    HStack {
                        Text("\(followingStore.followedPodcasts.count) Podcast\(followingStore.followedPodcasts.count == 1 ? "" : "s")")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)

                        Spacer()

                        Menu {
                            Picker("Sort", selection: $sortOrder) {
                                ForEach(SortOrder.allCases, id: \.self) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(sortOrder.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .contentShape(Capsule())
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .padding(.horizontal, 20)

                    // MARK: - Podcast Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 18) {
                        ForEach(sortedPodcasts) { podcast in
                            FollowingGridCard(podcast: podcast)
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    navCoordinator.navigate(to: podcast.summary)
                                }
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                                    removal: .scale(scale: 0.85).combined(with: .opacity)
                                ))
                        }
                    }
                    .padding(.horizontal, 16)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: sortedPodcasts.map(\.id))

                    Color.clear.frame(height: 100)
                }
            }
        }
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: PodcastSummary.self) { summary in
            PodcastDetailView(podcast: summary)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        let shareURL = URL(string: "https://podcasts.apple.com/us/podcast/id\(summary.id)")!
                        Menu {
                            ShareLink(item: shareURL) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            Button { } label: {
                                Label("Disable Notifications", systemImage: "bell.slash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
        }
    }
}

// MARK: - Empty State
struct EmptyFollowingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.tertiary)

            VStack(spacing: 8) {
                Text("No podcasts yet")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("Follow podcasts from the home screen\nor search to discover new ones.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

// MARK: - Bubble (horizontal quick access)
struct FollowingBubble: View {
    let podcast: TopPodcast

    var body: some View {
        VStack(spacing: 8) {
            CachedAsyncImage(url: podcast.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.white.opacity(0.08))
            }
            .frame(width: 68, height: 68)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            Text(podcast.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .frame(width: 74)
        }
    }
}

// MARK: - Grid Card (matches YouMightLikeCard style, flexible width)
struct FollowingGridCard: View {
    let podcast: TopPodcast
    @EnvironmentObject var followingStore: FollowingStore

    private let innerPadding: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Artwork — padded inside the glass card, matching YouMightLikeCard
            CachedAsyncImage(url: podcast.artworkURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topTrailing) {
                // Unfollow heart overlay
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    followingStore.unfollow(podcast)
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .padding(6)
            }
            .padding(.top, innerPadding)
            .padding(.horizontal, innerPadding)

            // Text below artwork — same fonts as YouMightLikeCard
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
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .hoverEffect(.highlight)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
