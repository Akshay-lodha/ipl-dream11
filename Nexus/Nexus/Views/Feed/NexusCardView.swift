import SwiftUI

struct NexusCardView: View {
    let event: NexusEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: category badge + time
            HStack {
                Label(event.category.rawValue, systemImage: event.category.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(categoryColor.gradient, in: Capsule())

                Spacer()

                Text(event.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Title
            Text(event.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            // Summary
            Text(event.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Divider()

            // Footer stats
            HStack(spacing: 16) {
                Label("\(event.reportCount)", systemImage: "doc.text.fill")
                Label("\(event.totalValidations)", systemImage: "checkmark.seal.fill")
                Label(event.locationLabel, systemImage: "mappin")

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private var categoryColor: Color {
        switch event.category {
        case .accident, .fire: return .red
        case .protest:         return .orange
        case .weather:         return .blue
        case .crime:           return .purple
        case .traffic:         return .yellow
        case .community:       return .green
        case .other:           return .gray
        }
    }
}

#Preview {
    NexusCardView(event: MockData.nexusEvents[0])
        .padding()
}
