import SwiftUI

struct FeedView: View {
    let events = MockData.nexusEvents

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(events) { event in
                        NavigationLink(value: event.id) {
                            NexusCardView(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Nexus")
            .navigationDestination(for: UUID.self) { id in
                if let event = events.first(where: { $0.id == id }) {
                    NexusDetailView(event: event)
                }
            }
        }
    }
}

#Preview {
    FeedView()
}
