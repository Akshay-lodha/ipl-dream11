import SwiftUI

struct SearchView: View {
    @StateObject private var searchVM = SearchViewModel()
    @State private var searchText = ""

    let categories = [
        ("Technology",  "cpu.fill",                    Color(hex: "#5B2D8E")),
        ("News",        "newspaper.fill",               Color(hex: "#C0392B")),
        ("True Crime",  "magnifyingglass",              Color(hex: "#1A1A2E")),
        ("Comedy",      "face.smiling.fill",            Color(hex: "#F59E0B")),
        ("Business",    "chart.line.uptrend.xyaxis",    Color(hex: "#10B981")),
        ("Science",     "atom",                         Color(hex: "#2563EB")),
        ("History",     "book.fill",                    Color(hex: "#92400E")),
        ("Health",      "heart.fill",                   Color(hex: "#EC4899")),
        ("Sports",      "sportscourt.fill",             Color(hex: "#059669")),
        ("Education",   "graduationcap.fill",           Color(hex: "#7C3AED")),
        ("Arts",        "paintpalette.fill",            Color(hex: "#DB2777")),
        ("Society",     "person.3.fill",                Color(hex: "#0891B2")),
    ]

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        if searchText.isEmpty {
                            // Browse categories grid
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Browse Categories")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)

                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                                    spacing: 12
                                ) {
                                    ForEach(categories, id: \.0) { cat in
                                        CategoryTile(title: cat.0, icon: cat.1, color: cat.2) {
                                            searchText = cat.0
                                            searchVM.search(term: cat.0)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)

                                Color.clear.frame(height: 100)
                            }
                        } else {
                            // Search results
                            LazyVStack(spacing: 0) {
                                if searchVM.isSearching {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 60)
                                } else if searchVM.results.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.secondary)
                                        Text("No results for \"\(searchText)\"")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 60)
                                } else {
                                    ForEach(Array(searchVM.results.enumerated()), id: \.element.id) { index, podcast in
                                        SearchResultRow(podcast: podcast)
                                        if index < searchVM.results.count - 1 {
                                            Divider()
                                                .background(Color.white.opacity(0.06))
                                                .padding(.leading, 76)
                                        }
                                    }
                                }
                                Color.clear.frame(height: 100)
                            }
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                    } header: {
                        // Pinned search bar — stays at top while scrolling
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)

                            TextField("Podcasts, episodes, topics", text: $searchText)
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()
                                .onChange(of: searchText) { _, newValue in
                                    searchVM.search(term: newValue)
                                }

                            if searchVM.isSearching {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    searchVM.search(term: "")
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .padding(.top, 4)
                        .background(Color(hex: "#0A0A0A"))
                    }
                }
            }
        }
        .navigationTitle("Search")
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

// MARK: - Search Result Row
struct SearchResultRow: View {
    let podcast: iTunesPodcast
    @EnvironmentObject var followingStore: FollowingStore
    @EnvironmentObject var navCoordinator: NavigationCoordinator

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            navCoordinator.navigate(to: podcast.summary)
        } label: {
            HStack(spacing: 12) {
                CachedAsyncImage(url: podcast.artworkURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(podcast.collectionName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(podcast.artistName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    if let genre = podcast.primaryGenreName {
                        Text(genre)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Tile
struct CategoryTile: View {
    let title: String
    let icon: String
    let color: Color
    var onTap: (() -> Void)? = nil
    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 90)

            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.2))
                .offset(x: 80, y: -8)
                .rotationEffect(.degrees(12))

            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(14)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { isPressed = false }
                onTap?()
            }
        }
    }
}
