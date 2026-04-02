import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var player = PlayerViewModel()
    @StateObject private var followingStore = FollowingStore()
    @StateObject private var queueStore = QueueStore()
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @State private var showFullPlayer = false
    @State private var selectedTab: String = "podcasts"
    @StateObject private var followingNav = NavigationCoordinator()
    @StateObject private var searchNav = NavigationCoordinator()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Podcasts", systemImage: "dot.radiowaves.left.and.right", value: "podcasts") {
                // HomeView manages its own NavigationStack
                HomeView()
            }
            Tab("Following", systemImage: "heart.fill", value: "following") {
                NavigationStack(path: $followingNav.path) {
                    FollowingView()
                }
                .environmentObject(followingNav)
            }
            Tab(value: "search", role: .search) {
                NavigationStack(path: $searchNav.path) {
                    SearchView()
                }
                .environmentObject(searchNav)
            }
            Tab("Profile", systemImage: "person.fill", value: "profile") {
                NavigationStack {
                    ProfileView()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .safeAreaInset(edge: .bottom) {
            if player.isMiniPlayerVisible {
                MiniPlayerView(player: player, showFullPlayer: $showFullPlayer)
                    .environmentObject(queueStore)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: player.isMiniPlayerVisible)
        .environmentObject(followingStore)
        .environmentObject(player)
        .environmentObject(queueStore)
        .environmentObject(downloadManager)
        .preferredColorScheme(.dark)
        .onAppear { player.queueStore = queueStore }
        .sheet(isPresented: $showFullPlayer) {
            FullPlayerView(player: player)
                .environmentObject(queueStore)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await checkForNewEpisodes() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToPodcastFromPlayer)) { notification in
            guard let podcast = notification.object as? PodcastSummary else { return }
            selectedTab = "following"
            // Small delay so the tab switch completes before pushing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                followingNav.navigate(to: podcast)
            }
        }
    }

    // MARK: - New Episode Notifications
    private func checkForNewEpisodes() async {
        let lastCheckKey = "lastNotificationCheck"
        let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
        let now = Date().timeIntervalSince1970
        guard now - lastCheck > 3600 else { return }
        UserDefaults.standard.set(now, forKey: lastCheckKey)

        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard status == .authorized else { return }

        let podcasts = followingStore.followedPodcasts
        for podcast in podcasts {
            let lastCheckedKey = "lastChecked-\(podcast.id)"
            let lastCheckedDate = UserDefaults.standard.object(forKey: lastCheckedKey) as? Date

            guard let summaryId = Int(podcast.id) else { continue }
            guard let detail = try? await PodcastService.shared.lookupPodcast(id: podcast.id),
                  let feedUrl = detail.feedUrl else { continue }
            guard let feed = try? await PodcastService.shared.fetchFeed(feedUrl: feedUrl, podcastTitle: podcast.name),
                  let latest = feed.episodes.first else { continue }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            var latestDate: Date?
            for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "yyyy-MM-dd'T'HH:mm:ssZ"] {
                formatter.dateFormat = format
                if let d = formatter.date(from: latest.pubDate) { latestDate = d; break }
            }

            if let latestDate, let lastCheckedDate {
                if latestDate > lastCheckedDate {
                    let content = UNMutableNotificationContent()
                    content.title = podcast.name
                    content.body = "New episode: \(latest.title)"
                    content.sound = .default
                    let request = UNNotificationRequest(
                        identifier: "new-episode-\(podcast.id)-\(latest.id)",
                        content: content,
                        trigger: nil
                    )
                    try? await UNUserNotificationCenter.current().add(request)
                }
            }

            UserDefaults.standard.set(latestDate ?? Date(), forKey: lastCheckedKey)
            _ = summaryId
        }
    }
}
