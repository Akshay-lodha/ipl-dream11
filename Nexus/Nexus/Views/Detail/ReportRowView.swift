import SwiftUI

struct ReportRowView: View {
    let report: Report
    @State private var validated = false
    @State private var markedUnclear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Author + timestamp
            HStack {
                Image(systemName: report.author.avatarSystemName)
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 1) {
                    Text(report.author.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(report.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(report.locationLabel, systemImage: "mappin")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Report text
            Text(report.text)
                .font(.subheadline)

            // Media indicators
            if !report.mediaNames.isEmpty {
                HStack(spacing: 8) {
                    ForEach(report.mediaNames.indices, id: \.self) { index in
                        Label(
                            report.mediaNames[index] == "video.fill" ? "Video" : "Photo",
                            systemImage: report.mediaNames[index]
                        )
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                    }
                }
            }

            Divider()

            // Validation actions
            HStack(spacing: 20) {
                Button {
                    validated.toggle()
                    if validated { markedUnclear = false }
                } label: {
                    Label("\(report.validationCount + (validated ? 1 : 0))",
                          systemImage: validated ? "checkmark.seal.fill" : "checkmark.seal")
                        .font(.caption)
                        .foregroundStyle(validated ? .green : .secondary)
                }

                Button {
                    markedUnclear.toggle()
                    if markedUnclear { validated = false }
                } label: {
                    Label("\(report.unclearCount + (markedUnclear ? 1 : 0))",
                          systemImage: markedUnclear ? "eye.trianglebadge.exclamationmark.fill" : "eye.trianglebadge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(markedUnclear ? .orange : .secondary)
                }

                Spacer()
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ReportRowView(report: MockData.nexusEvents[0].reports[0])
        .padding()
}
