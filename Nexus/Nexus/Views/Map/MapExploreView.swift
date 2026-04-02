import SwiftUI
import MapKit

struct MapExploreView: View {
    let events = MockData.nexusEvents
    @State private var selectedEvent: NexusEvent?
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7308, longitude: -73.9973),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position, selection: $selectedEvent) {
                    ForEach(events) { event in
                        Annotation(event.title, coordinate: event.coordinate) {
                            eventPin(for: event)
                        }
                        .tag(event)
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))

                if let event = selectedEvent {
                    NavigationLink(value: event.id) {
                        selectedEventCard(event)
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding()
                }
            }
            .animation(.easeInOut, value: selectedEvent?.id)
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                if let event = events.first(where: { $0.id == id }) {
                    NexusDetailView(event: event)
                }
            }
        }
    }

    private func eventPin(for event: NexusEvent) -> some View {
        ZStack {
            Circle()
                .fill(pinColor(for: event.category).gradient)
                .frame(width: 36, height: 36)
                .shadow(radius: 4)

            Image(systemName: event.category.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func selectedEventCard(_ event: NexusEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(event.category.rawValue, systemImage: event.category.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Text(event.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(event.title)
                .font(.headline)

            Text(event.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Label("\(event.reportCount) reports", systemImage: "doc.text.fill")
                Spacer()
                Text("Tap to view")
                Image(systemName: "chevron.right")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func pinColor(for category: NexusEvent.EventCategory) -> Color {
        switch category {
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
    MapExploreView()
}
