import SwiftUI
import MapKit

/// Walking Mode content — embedded inside the player sheet.
struct WalkingModeView: View {
    @ObservedObject var player: PlayerViewModel
    @ObservedObject var viewModel: WalkingModeViewModel
    var onDismiss: () -> Void

    @State private var showSplash = true
    @State private var showHealthSheet = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var userLocationOffScreen = false
    @State private var iconPulse: Bool = false
    @State private var mapReady = false                // hides map until tiles are loaded

    @State private var zoomAnimationStarted = false   // prevents double-triggering the intro zoom
    @State private var initialAnimationDone = false    // prevents intro zoom from triggering offscreen check
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var userIsInteracting = false       // suppresses auto-follow during panning

    private let defaultZoomDistance: Double = 2000
    private let wideZoomDistance: Double = 8000

    var body: some View {
        ZStack {
            if showSplash {
                WalkingSplashView {
                    viewModel.startWalk()
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .onAppear { resetState() }
        .onChange(of: player.walkSessionId) { _, _ in resetState() }
    }

    /// Reset all state for a fresh walking session
    private func resetState() {
        showSplash = !viewModel.isRunning
        iconPulse = true
        userLocationOffScreen = false
        userIsInteracting = false
        mapReady = false
        zoomAnimationStarted = false
        initialAnimationDone = false
        visibleRegion = nil
    }

    // MARK: - Zoom animation (wide → close)
    private func startZoomAnimation(to coord: CLLocationCoordinate2D) {
        guard !zoomAnimationStarted else { return }
        zoomAnimationStarted = true

        // Step 1: Snap to wide view (no animation) — map is still hidden (opacity 0)
        cameraPosition = .camera(MapCamera(
            centerCoordinate: coord,
            distance: wideZoomDistance
        ))

        // Step 2: Wait for tiles to render, then reveal + animate zoom
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Reveal the map with a fade
            withAnimation(.easeIn(duration: 0.3)) { mapReady = true }
            withAnimation(.easeOut(duration: 0.9)) {
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: coord,
                    distance: defaultZoomDistance
                ))
            }
            // Step 3: After animation completes, enable user-interaction detection
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                initialAnimationDone = true
            }
        }
    }

    // MARK: - Follow user location (after intro animation)
    private func followUser(to coord: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.8)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: coord,
                distance: defaultZoomDistance
            ))
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // MARK: Map section — hidden until initial tiles are loaded
            mapSection
                .opacity(mapReady ? 1 : 0)

            // MARK: - Bottom section (solid black)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        viewModel.togglePause()
                    } label: {
                        Label(
                            viewModel.isPaused ? "Resume Walk" : "Pause Walk",
                            systemImage: viewModel.isPaused ? "play.fill" : "pause.fill"
                        )
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)

                    Button {
                        Task {
                            await viewModel.endWalk()
                            onDismiss()
                        }
                    } label: {
                        Label("End Session", systemImage: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)

                HStack(spacing: 12) {
                    if let url = player.artworkURL {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(player.currentEpisodeTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(player.currentPodcastTitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                PodcastScrubberView(
                    currentTime: $player.currentTime,
                    totalTime: player.totalTime,
                    isScrubbing: $player.isScrubbing,
                    formattedCurrentTime: player.formattedCurrentTime,
                    formattedRemainingTime: player.formattedRemainingTime,
                    chapters: player.chapters,
                    onSeek: { player.seek(to: $0) }
                )
                .padding(.bottom, 20)

                HStack(spacing: 40) {
                    Button { player.skipBackward() } label: {
                        Image(systemName: "gobackward.\(player.skipBackInterval)")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }

                    Button { player.togglePlayback() } label: {
                        if player.isBuffering {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.3)
                                .frame(width: 56, height: 56)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 56, height: 56)
                        }
                    }

                    Button { player.skipForward() } label: {
                        Image(systemName: "goforward.\(player.skipForwardInterval)")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color.black)
        }
        .background(Color.black)
        .sheet(isPresented: $showHealthSheet) {
            HealthIntegrationSheet(healthManager: viewModel.healthManager)
        }
    }

    // MARK: - Map Section

    private var mapSection: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
        .mapControlVisibility(.hidden)
        .colorScheme(.dark)
        .onMapCameraChange(frequency: .continuous) { _ in
            // User is actively panning/zooming — suppress auto-follow
            if initialAnimationDone { userIsInteracting = true }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            guard initialAnimationDone else { return }
            visibleRegion = context.region
            updateLocationVisibility()
            // Re-enable auto-follow after 3 seconds of no interaction
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                userIsInteracting = false
            }
        }
        // Reliably wait for location then trigger zoom animation
        .task {
            // Poll until location is available (works whether already set or arriving later)
            while viewModel.sessionManager.currentLocation == nil {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
            }
            // Give map time to finish initial tile rendering before zoom animation
            try? await Task.sleep(for: .milliseconds(600))
            if Task.isCancelled { return }
            if let coord = viewModel.sessionManager.currentLocation {
                startZoomAnimation(to: coord)
            }
        }
        // Follow location updates after zoom animation completes
        .onReceive(viewModel.sessionManager.$currentLocation) { newLoc in
            guard let coord = newLoc else { return }
            // Only auto-follow when user isn't actively panning and location is on-screen
            if initialAnimationDone && !userLocationOffScreen && !userIsInteracting {
                followUser(to: coord)
            }
            if initialAnimationDone {
                updateLocationVisibility()
            }
        }
        // Gradients — fully pass-through
        .overlay(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.3), location: 0.3),
                    .init(color: .black.opacity(0.7), location: 0.6),
                    .init(color: .black, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.8), location: 0),
                    .init(color: .black.opacity(0.5), location: 0.5),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false)
        }
        // Toolbar — only covers its content area at the top
        .overlay(alignment: .top) {
            HStack {
                Button { onDismiss() } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white)
                .glassEffect(.regular.interactive(), in: .circle)

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 16, weight: .semibold))
                        .symbolEffect(.pulse.wholeSymbol, isActive: iconPulse)
                    Text("Walking Mode")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(.white)
                .allowsHitTesting(false)

                Spacer()

                Button { showHealthSheet = true } label: {
                    Image(systemName: "heart.text.square.fill")
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white)
                .glassEffect(.regular.interactive(), in: .circle)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        // Re-center button — only shows when user location is off screen
        .overlay(alignment: .bottomTrailing) {
            if userLocationOffScreen {
                Button {
                    if let coord = viewModel.sessionManager.currentLocation {
                        userIsInteracting = false
                        followUser(to: coord)
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16))
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white)
                .glassEffect(.regular.interactive(), in: .circle)
                .padding(.trailing, 16)
                .padding(.bottom, 100)
                .transition(.opacity)
            }
        }
        // Bottom stats — only covers the stats area at the bottom
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                // Health badge — only show when NOT connected (prompt user to connect)
                if !viewModel.healthManager.isConnected {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Apple Health Disconnected")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 8)
                }

                // Stats
                HStack(spacing: 0) {
                    statItem(icon: "clock.fill", label: "Time", value: viewModel.formattedTime)
                    Divider().frame(height: 40).background(Color.white.opacity(0.15))
                    statItem(icon: "figure.walk", label: "Steps", value: viewModel.formattedSteps)
                    Divider().frame(height: 40).background(Color.white.opacity(0.15))
                    statItem(icon: "location.fill", label: "Distance", value: viewModel.formattedDistance)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Location visibility check

    private func updateLocationVisibility() {
        guard let region = visibleRegion,
              let userCoord = viewModel.sessionManager.currentLocation else { return }

        let latDelta = region.span.latitudeDelta / 2.0
        let lonDelta = region.span.longitudeDelta / 2.0
        let center = region.center

        let isVisible =
            userCoord.latitude >= center.latitude - latDelta &&
            userCoord.latitude <= center.latitude + latDelta &&
            userCoord.longitude >= center.longitude - lonDelta &&
            userCoord.longitude <= center.longitude + lonDelta

        withAnimation {
            userLocationOffScreen = !isVisible
        }
    }

    // MARK: - Helpers

    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }
}
