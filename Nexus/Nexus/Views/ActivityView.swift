import SwiftUI

struct ActivityView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    activityRow(
                        icon: "checkmark.seal.fill",
                        iconColor: .green,
                        title: "Your report was validated",
                        detail: "Water Main Break on 5th Avenue",
                        time: "2h ago"
                    )
                    activityRow(
                        icon: "bubble.left.fill",
                        iconColor: .blue,
                        title: "New discussion reply",
                        detail: "Climate March at City Hall",
                        time: "3h ago"
                    )
                    activityRow(
                        icon: "link",
                        iconColor: .orange,
                        title: "Report linked to Nexus",
                        detail: "Multi-Car Accident on BQE",
                        time: "5h ago"
                    )
                }

                Section("Earlier") {
                    activityRow(
                        icon: "person.fill.badge.plus",
                        iconColor: .purple,
                        title: "Reputation +10",
                        detail: "Your report received 10 validations",
                        time: "Yesterday"
                    )
                    activityRow(
                        icon: "flame.fill",
                        iconColor: .red,
                        title: "Nearby event alert",
                        detail: "Building Fire on 8th Street",
                        time: "Yesterday"
                    )
                }
            }
            .navigationTitle("Activity")
        }
    }

    private func activityRow(icon: String, iconColor: Color, title: String, detail: String, time: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ActivityView()
}
