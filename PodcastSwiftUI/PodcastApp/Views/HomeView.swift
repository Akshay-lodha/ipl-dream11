import SwiftUI

struct HomeView: View {
    @StateObject private var homeVM = HomeViewModel()
    @StateObject private var navCoordinator = NavigationCoordinator()
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var followingStore: FollowingStore
    @Namespace private var zoomNS

    var body: some View {
        NavigationStack(path: $navCoordinator.path) {
        ZStack(alignment: .bottom) {
            Color(hex: "#0A0A0A").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Featured Carousel — specific curated podcasts (falls back to charts while loading)
                    FeaturedCarouselView(
                        podcasts: homeVM.featuredPodcasts.isEmpty ? homeVM.topPodcasts : homeVM.featuredPodcasts,
                        zoomNamespace: zoomNS
                    )

                    // Curated Folders — genre-based, populated from iTunes
                    CuratedFoldersView(folders: homeVM.folders, zoomNamespace: zoomNS)
                        .padding(.top, 28)

                    // Recent Releases — latest episodes from followed podcasts
                    RecentReleasesView(entries: homeVM.recentReleases,
                                       hasFollowedPodcasts: !followingStore.followedPodcasts.isEmpty)
                        .padding(.top, 28)

                    // You might like — recommendations
                    YouMightLikeView(podcasts: homeVM.recommendedPodcasts, zoomNamespace: zoomNS)
                        .padding(.top, 28)

                    // Pick Your Mood — mood-based episode recommendations
                    PickYourMoodView(
                        selectedMood: $homeVM.selectedMood,
                        moodEpisodes: homeVM.moodEpisodes,
                        isMoodLoading: homeVM.isMoodLoading,
                        onSelectMood: { mood in
                            Task { await homeVM.selectMood(mood) }
                        }
                    )
                    .padding(.vertical, 24)
                    .background(Color.white.opacity(0.04))
                    .padding(.top, 28)

                    // Category sections — ordered: Tech, News, Business, Design, Product, Popular in [Country], Health, Science, Culture, Education, True Crime, Entertainment
                    ForEach(PodcastCategory.all.prefix(5)) { category in
                        CategorySectionView(
                            category: category,
                            podcasts: homeVM.categoryPodcasts[category.id] ?? [],
                            zoomNamespace: zoomNS
                        )
                        .padding(.top, 28)
                    }

                    // Popular in Country — device locale based (between Product and Health)
                    CategorySectionView(
                        category: PodcastCategory(
                            id: "popular_country",
                            title: "Popular in \(homeVM.countryName)",
                            subtitle: "Top podcasts trending in your country right now",
                            genreId: 0
                        ),
                        podcasts: homeVM.popularInCountry,
                        zoomNamespace: zoomNS
                    )
                    .padding(.top, 28)

                    ForEach(PodcastCategory.all.dropFirst(5)) { category in
                        CategorySectionView(
                            category: category,
                            podcasts: homeVM.categoryPodcasts[category.id] ?? [],
                            zoomNamespace: zoomNS
                        )
                        .padding(.top, 28)
                    }

                    // Footer — marquee artwork + credits
                    HomeFooterView(podcasts: homeVM.footerPodcasts)
                    .padding(.top, 36)

                    // Error banner
                    if let error = homeVM.errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "wifi.slash")
                            Text(error)
                                .font(.system(size: 14))
                            Spacer()
                            Button("Retry") {
                                Task { await homeVM.refresh() }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }

                    Color.clear.frame(height: 100)
                }
            }
            .ignoresSafeArea(edges: .top)
            .refreshable {
                await homeVM.refresh()
            }
        }
        .navigationDestination(for: YouMightLikeDestination.self) { _ in
            YouMightLikeGridView(podcasts: homeVM.recommendedPodcasts, zoomNamespace: zoomNS)
                .navigationTransition(.zoom(sourceID: "yml_header", in: zoomNS))
        }
        .navigationDestination(for: CuratedFoldersDestination.self) { _ in
            CuratedFoldersGridView(folders: homeVM.folders, zoomNamespace: zoomNS)
                .navigationTransition(.zoom(sourceID: "curated_folders_header", in: zoomNS))
        }
        .navigationDestination(for: FolderDetailDestination.self) { dest in
            let folder = homeVM.folders.first(where: { $0.id == dest.folderId })
            let category = PodcastCategory(
                id: dest.folderId,
                title: folder?.name ?? "Folder",
                subtitle: "",
                genreId: folder?.genreId ?? 0
            )
            CategoryGridView(
                category: category,
                podcasts: folder?.podcasts ?? [],
                zoomNamespace: zoomNS
            )
            .navigationTransition(.zoom(sourceID: dest.folderId, in: zoomNS))
        }
        .navigationDestination(for: CategorySectionDestination.self) { dest in
            let podcasts: [TopPodcast] = {
                if dest.categoryId == "popular_country" { return homeVM.popularInCountry }
                return homeVM.categoryPodcasts[dest.categoryId] ?? []
            }()
            let category = PodcastCategory.all.first(where: { $0.id == dest.categoryId })
                ?? PodcastCategory(id: dest.categoryId, title: dest.title, subtitle: "", genreId: 0)
            CategoryGridView(category: category, podcasts: podcasts, zoomNamespace: zoomNS)
                .navigationTransition(.zoom(sourceID: "cs_header_\(dest.categoryId)", in: zoomNS))
        }
        .navigationDestination(for: PodcastDetailDestination.self) { dest in
            // Carousel source is the TabView container itself (single stable ID)
            PodcastDetailPagerView(podcasts: dest.podcasts, startIndex: dest.startIndex)
                .navigationTransition(.zoom(sourceID: "carousel", in: zoomNS))
        }
        .navigationDestination(for: PodcastNavDestination.self) { dest in
            PodcastDetailPagerView(podcasts: dest.podcasts, startIndex: dest.startIndex)
        }
        .task {
            await homeVM.load()
            await homeVM.loadRecentReleases(from: followingStore.followedPodcasts)
        }
        .onChange(of: followingStore.followedPodcasts.count) { _, _ in
            Task { await homeVM.loadRecentReleases(from: followingStore.followedPodcasts) }
        }
        } // NavigationStack
        .environmentObject(navCoordinator)
    }
}

