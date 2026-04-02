import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject var followingStore: FollowingStore
    @EnvironmentObject var player: PlayerViewModel
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        if authManager.authState == .signedIn, let user = authManager.currentUser {
                            // Signed-in header
                            SignedInHeader(user: user, followingStore: followingStore)
                        } else {
                            // Signed-out header with Sign in with Apple
                            SignedOutHeader(followingStore: followingStore)
                        }

                        // Bookmarks
                        if !player.bookmarks.isEmpty {
                            BookmarksSection(player: player)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }

                        // Settings Sections
                        VStack(spacing: 20) {
                            SettingsSection(title: "Playback", items: [
                                ("goforward.30", "Skip Forward Time", "30 seconds"),
                                ("gobackward.15", "Skip Backward Time", "15 seconds"),
                                ("hare.fill", "Playback Speed", "1x"),
                                ("waveform", "Audio Quality", "High"),
                            ])

                            SettingsSection(title: "Notifications", items: [
                                ("bell.fill", "New Episodes", "On"),
                                ("clock.fill", "Episode Reminders", "Off"),
                            ])

                            StorageSection()

                            SettingsSection(title: "About", items: [
                                ("star.fill", "Rate the App", ""),
                                ("questionmark.circle.fill", "Help & Support", ""),
                                ("info.circle.fill", "Version", "1.0.0"),
                            ])

                            // Sign Out button (only when signed in)
                            if authManager.authState == .signedIn {
                                Button {
                                    authManager.signOut()
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.red.opacity(0.2))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .font(.system(size: 14))
                                                .foregroundStyle(.red)
                                        }
                                        Text("Sign Out")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.red)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)

                        Color.clear.frame(height: 100)
                    }
                }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct StatView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

struct SettingsSection: View {
    let title: String
    let items: [(String, String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: item.0)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.accentColor)
                        }

                        Text(item.1)
                            .font(.system(size: 15))
                            .foregroundStyle(.white)

                        Spacer()

                        if !item.2.isEmpty {
                            Text(item.2)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if index < items.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 58)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Storage Section (Downloads row navigates to DownloadsView)

private struct StorageSection: View {
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Storage")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Auto-Download (static row)
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.accentColor)
                    }
                    Text("Auto-Download")
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Wi-Fi Only")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.leading, 58)

                // Downloads — navigates to DownloadsView
                NavigationLink(destination: DownloadsView()) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: "internaldrive.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.accentColor)
                        }
                        Text("Downloads")
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(downloadManager.totalSizeFormatted)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Bookmarks Section

private struct BookmarksSection: View {
    @ObservedObject var player: PlayerViewModel
    @State private var selectedBookmark: PodcastBookmark?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bookmarks")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(player.bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                    Button {
                        selectedBookmark = bookmark
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.accentColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(bookmark.title)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(bookmark.podcastTitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(PodcastBookmark.formatTime(bookmark.timestamp))
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if index < player.bookmarks.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 58)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .sheet(item: $selectedBookmark) { bookmark in
            BookmarkDetailSheet(bookmark: bookmark, player: player)
        }
    }
}

// MARK: - Bookmark Detail Sheet

struct BookmarkDetailSheet: View {
    let bookmark: PodcastBookmark
    @ObservedObject var player: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    private let sectionBg = Color.white.opacity(0.08)

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Episode
                Section {
                    HStack(spacing: 14) {
                        // Artwork
                        if let url = player.artworkURL {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.1))
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(bookmark.title)
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(2)
                            Text(bookmark.podcastTitle)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(sectionBg)
                }

                // MARK: - Notes
                Section {
                    Group {
                        if bookmark.notes.isEmpty {
                            Text("No notes were saved for this bookmark.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(bookmark.notes)
                                .font(.system(size: 15))
                        }
                    }
                    .listRowBackground(sectionBg)
                } header: {
                    Text("Notes")
                }

                // MARK: - Details
                Section {
                    HStack {
                        Text("Moment")
                        Spacer()
                        Text(PodcastBookmark.formatTime(bookmark.timestamp))
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(sectionBg)

                    if bookmark.saveAudioSnippet {
                        HStack {
                            Text("Clip")
                            Spacer()
                            Text("\(bookmark.clipLength) sec clip")
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(sectionBg)
                    }
                } header: {
                    Text("Details")
                }

                // MARK: - Play Action
                Section {
                    Button {
                        player.seek(to: bookmark.timestamp)
                        if !player.isPlaying { player.togglePlayback() }
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                                .foregroundStyle(.accent)
                            Text("Play from Saved Moment")
                                .foregroundStyle(.accent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .listRowBackground(sectionBg)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Signed-In Header

private struct SignedInHeader: View {
    let user: UserProfile
    let followingStore: FollowingStore

    var body: some View {
        VStack(spacing: 16) {
            // Avatar with initial
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)

                if let initial = user.fullName?.first {
                    Text(String(initial).uppercased())
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                }
            }

            VStack(spacing: 4) {
                Text(user.fullName ?? "Podcast Listener")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                if let email = user.email {
                    Text(email)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                } else {
                    Text("podcast enthusiast")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }

            // Stats
            HStack(spacing: 0) {
                StatView(value: "—", label: "Episodes")
                Divider().frame(height: 30).background(Color.white.opacity(0.08))
                StatView(value: "\(followingStore.followedPodcasts.count)", label: "Following")
                Divider().frame(height: 30).background(Color.white.opacity(0.08))
                StatView(value: "—", label: "This Month")
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
        .padding(.bottom, 32)
    }
}

// MARK: - Signed-Out Header

private struct SignedOutHeader: View {
    let followingStore: FollowingStore

    var body: some View {
        VStack(spacing: 16) {
            // Avatar placeholder
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                Image(systemName: "person.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            VStack(spacing: 8) {
                Text("Sign in to personalize")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text("Sync your profile across devices")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            AppleSignInButton()
                .frame(height: 50)
                .padding(.horizontal, 40)

            // Stats
            HStack(spacing: 0) {
                StatView(value: "—", label: "Episodes")
                Divider().frame(height: 30).background(Color.white.opacity(0.08))
                StatView(value: "\(followingStore.followedPodcasts.count)", label: "Following")
                Divider().frame(height: 30).background(Color.white.opacity(0.08))
                StatView(value: "—", label: "This Month")
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
        .padding(.bottom, 32)
    }
}
