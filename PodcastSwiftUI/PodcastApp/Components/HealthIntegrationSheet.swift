import SwiftUI

/// Bottom sheet for Apple Health integration settings.
struct HealthIntegrationSheet: View {
    @ObservedObject var healthManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    private let sectionBg = Color.white.opacity(0.08)

    var body: some View {
        NavigationStack {
            List {
                // Header section
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.red)
                            .padding(.top, 8)

                        Text("Health Integration")
                            .font(.system(size: 22, weight: .bold))

                        Text("Walking Mode can save completed walking workouts to Apple Health when you enable Health integration.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                // Info section
                Section {
                    infoRow(icon: "arrow.up.circle", text: "Writes to Apple Health: Completed Walking Workout")
                    infoRow(icon: "figure.walk", text: "Source data: Waves Walking Mode session metrics")
                    infoRow(icon: "checkmark.shield", text: "Includes steps, distance, and duration")
                }
                .listRowBackground(sectionBg)

                // Action section
                Section {
                    if healthManager.isConnected {
                        Button {
                            healthManager.disconnect()
                        } label: {
                            Label("Disconnect from Health", systemImage: "heart.text.square.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.extraLarge)
                        .listRowBackground(Color.clear)
                    } else {
                        Button {
                            Task {
                                await healthManager.requestAuthorization()
                            }
                        } label: {
                            Label("Connect to Health", systemImage: "heart.text.square.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.extraLarge)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}
