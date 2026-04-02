import SwiftUI

// MARK: - Section (horizontal scroll strip)

struct CategorySectionView: View {
    let category: PodcastCategory
    let podcasts: [TopPodcast]   // up to 30
    var zoomNamespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Header ───────────────────────────────────────────────
            NavigationLink(value: CategorySectionDestination(categoryId: category.id, title: category.title)) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text(category.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Text(category.subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: "cs_header_\(category.id)", in: zoomNamespace)
            .padding(.horizontal, 20)

            // ── Cards ─────────────────────────────────────────────────
            if podcasts.isEmpty {
                CategorySectionSkeleton()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(podcasts.enumerated()), id: \.element.id) { index, podcast in
                            YouMightLikeCard(podcast: podcast, allPodcasts: podcasts, cardIndex: index, zoomNamespace: zoomNamespace, sourceIDPrefix: "cs_\(category.id)")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Grid Page

struct CategoryGridView: View {
    let category: PodcastCategory
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
                        YouMightLikeCard(podcast: podcast, allPodcasts: podcasts, cardIndex: index, zoomNamespace: zoomNamespace, sourceIDPrefix: "cg_\(category.id)")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Skeleton

private struct CategorySectionSkeleton: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 196, height: 230)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
}
