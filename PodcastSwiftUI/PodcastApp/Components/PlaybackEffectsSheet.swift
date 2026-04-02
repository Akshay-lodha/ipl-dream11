import SwiftUI

/// Native iOS 26 "Playback Effects" bottom sheet.
/// Uses Liquid Glass automatically via partial-height detents.
struct PlaybackEffectsSheet: View {
    @ObservedObject var player: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    private let sectionBg = Color.white.opacity(0.08)

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Playback Speed
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(PlayerViewModel.availableRates, id: \.self) { rate in
                                let isSelected = player.playbackRate == rate
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        player.setPlaybackRate(rate)
                                    }
                                } label: {
                                    Text(rateLabel(rate))
                                        .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                                        .foregroundStyle(isSelected ? .white : .secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? Color.white.opacity(0.2) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                    .listRowBackground(sectionBg)
                } header: {
                    Text("Playback Speed")
                }

                // MARK: - Skip Buttons
                Section {
                    Picker("Skip Back", selection: $player.skipBackInterval) {
                        ForEach(PlayerViewModel.skipBackOptions, id: \.self) { secs in
                            Text("\(secs)s").tag(secs)
                        }
                    }
                    .listRowBackground(sectionBg)

                    Picker("Skip Forward", selection: $player.skipForwardInterval) {
                        ForEach(PlayerViewModel.skipForwardOptions, id: \.self) { secs in
                            Text("\(secs)s").tag(secs)
                        }
                    }
                    .listRowBackground(sectionBg)
                } header: {
                    Text("Skip Buttons")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Playback Effects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func rateLabel(_ rate: Double) -> String {
        if rate == floor(rate) {
            return String(format: "%.0fx", rate)
        } else {
            return String(format: "%.1fx", rate)
        }
    }
}
