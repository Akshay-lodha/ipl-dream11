import SwiftUI

struct NexusDetailView: View {
    let event: NexusEvent
    @State private var selectedSection: DetailSection = .reports

    enum DetailSection: String, CaseIterable {
        case reports = "Reports"
        case discussion = "Discussion"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Event header
                headerSection

                // Stats bar
                statsBar

                // Section picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(DetailSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Content
                switch selectedSection {
                case .reports:
                    reportsSection
                case .discussion:
                    if let discussion = event.discussions.first {
                        DiscussionView(discussion: discussion)
                    } else {
                        ContentUnavailableView("No Discussion Yet",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("Be the first to start a conversation about this event."))
                    }
                }
            }
        }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(event.category.rawValue, systemImage: event.category.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)

            Text(event.title)
                .font(.title2.weight(.bold))

            Text(event.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.red)
                Text(event.locationLabel)
                    .font(.subheadline)

                Spacer()

                Text(event.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Stats

    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(value: "\(event.reportCount)", label: "Reports", icon: "doc.text.fill")
            Divider().frame(height: 30)
            statItem(value: "\(event.totalValidations)", label: "Validations", icon: "checkmark.seal.fill")
            Divider().frame(height: 30)
            statItem(value: "\(event.discussions.first?.messages.count ?? 0)", label: "Messages", icon: "bubble.left.fill")
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.headline)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Reports

    private var reportsSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(event.reports) { report in
                ReportRowView(report: report)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        NexusDetailView(event: MockData.nexusEvents[0])
    }
}
