import SwiftUI

/// Bookmark sheet matching Apple Podcasts design.
/// Uses native iOS List with grouped sections inside a NavigationStack sheet.
struct BookmarkSheet: View {
    @ObservedObject var player: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var bookmarkTitle: String = ""
    @State private var notes: String = ""
    @State private var saveAudioSnippet: Bool = true
    @State private var clipLength: Double = 30
    @State private var selectedTime: Double = 0
    private let clipRange: ClosedRange<Double> = 5...120

    private let sectionBg = Color.white.opacity(0.08)

    private var totalDuration: Double { player.totalTime }
    private var clipEndTime: Double { min(selectedTime + clipLength, totalDuration) }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Episode
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.currentEpisodeTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(2)
                        Text(player.currentPodcastTitle)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(sectionBg)
                } header: {
                    Text("Episode")
                }

                // MARK: - Timeline
                Section {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Selected Time")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text(PodcastBookmark.formatTime(selectedTime))
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                                .animation(.snappy(duration: 0.15), value: Int(selectedTime))
                        }

                        ScrubbableWaveformView(
                            selectedTime: $selectedTime,
                            totalDuration: totalDuration
                        )
                        .frame(height: 30)

                        HStack {
                            Text(PodcastBookmark.formatTime(0))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(PodcastBookmark.formatTime(totalDuration))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(sectionBg)
                } header: {
                    Text("Timeline")
                }

                // MARK: - Notes
                Section {
                    TextField("Moment title", text: $bookmarkTitle)
                        .font(.system(size: 16, weight: .medium))
                        .listRowBackground(sectionBg)

                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Add notes")
                                .foregroundStyle(.tertiary)
                                .font(.system(size: 16))
                                .padding(.top, 8)
                        }
                        TextEditor(text: $notes)
                            .font(.system(size: 16))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                    }
                    .listRowBackground(sectionBg)
                } header: {
                    Text("Notes")
                }

                // MARK: - Audio Clip
                Section {
                    Toggle("Save Audio Snippet", isOn: $saveAudioSnippet)
                        .listRowBackground(sectionBg)

                    if saveAudioSnippet {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Clip Length")
                                Spacer()
                                Text("\(Int(clipLength)) sec")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 16, design: .monospaced))
                            }

                            Slider(value: $clipLength, in: clipRange, step: 5)

                            HStack {
                                Text(PodcastBookmark.formatTime(selectedTime))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(PodcastBookmark.formatTime(clipEndTime))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(sectionBg)
                    }
                } header: {
                    Text("Audio Clip")
                } footer: {
                    if saveAudioSnippet {
                        Text("Clip from \(PodcastBookmark.formatTime(selectedTime)) to \(PodcastBookmark.formatTime(clipEndTime)) (\(Int(clipLength)) sec).")
                    }
                }

                // MARK: - Previous Bookmarks
                if !player.bookmarksForCurrentEpisode().isEmpty {
                    Section {
                        ForEach(player.bookmarksForCurrentEpisode()) { bookmark in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(bookmark.title)
                                        .font(.system(size: 16, weight: .semibold))
                                    if bookmark.saveAudioSnippet {
                                        Text("\(bookmark.clipLength) sec clip")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(PodcastBookmark.formatTime(bookmark.timestamp))
                                    .font(.system(size: 15, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .listRowBackground(sectionBg)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    player.deleteBookmark(id: bookmark.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("Previous Bookmarks")
                    }
                }

                // MARK: - Footer
                Section {
                    Text("Access bookmarks from the Profile section.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .listRowBackground(sectionBg)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let bookmark = PodcastBookmark(
                            episodeId: player.currentEpisodeId,
                            episodeTitle: player.currentEpisodeTitle,
                            podcastTitle: player.currentPodcastTitle,
                            timestamp: selectedTime,
                            totalDuration: totalDuration,
                            title: bookmarkTitle.isEmpty ? nil : bookmarkTitle,
                            notes: notes,
                            saveAudioSnippet: saveAudioSnippet,
                            clipLength: Int(clipLength)
                        )
                        player.saveBookmark(bookmark)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            selectedTime = player.currentTime
            bookmarkTitle = "Moment at \(PodcastBookmark.formatTime(selectedTime))"
        }
        .onChange(of: selectedTime) {
            bookmarkTitle = "Moment at \(PodcastBookmark.formatTime(selectedTime))"
        }
    }
}

// MARK: - Scrubbable Waveform Visualization

struct ScrubbableWaveformView: View {
    @Binding var selectedTime: Double
    let totalDuration: Double

    @State private var isScrubbing = false
    private let haptic = UISelectionFeedbackGenerator()

    private let barHeights: [CGFloat] = {
        var heights: [CGFloat] = []
        for i in 0..<80 {
            let base = sin(Double(i) * 0.3) * 0.3 + 0.4
            let variation = sin(Double(i) * 1.7) * 0.2 + cos(Double(i) * 0.7) * 0.15
            heights.append(CGFloat(min(max(base + variation, 0.1), 1.0)))
        }
        return heights
    }()

    private var progress: Double {
        totalDuration > 0 ? selectedTime / totalDuration : 0
    }

    var body: some View {
        GeometryReader { geo in
            let barCount = barHeights.count
            let spacing: CGFloat = 1.5
            let barWidth = max((geo.size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount), 1)

            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    let isPast = Double(i) / Double(barCount) <= progress

                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(isPast ? Color.primary : Color.primary.opacity(0.25))
                        .frame(width: barWidth, height: geo.size.height * barHeights[i])
                }
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isScrubbing {
                            isScrubbing = true
                            haptic.prepare()
                        }
                        let fraction = min(max(gesture.location.x / geo.size.width, 0), 1)
                        let newTime = fraction * totalDuration
                        // Haptic on each second change
                        if Int(newTime) != Int(selectedTime) {
                            haptic.selectionChanged()
                        }
                        selectedTime = newTime
                    }
                    .onEnded { _ in
                        isScrubbing = false
                    }
            )
        }
    }
}
