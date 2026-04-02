import Foundation
import CoreLocation

struct Report: Identifiable, Hashable {
    let id: UUID
    var author: User
    var text: String
    var mediaNames: [String]       // SF Symbol names for mock; real app would use image URLs
    var coordinate: CLLocationCoordinate2D
    var locationLabel: String
    var timestamp: Date
    var validationCount: Int
    var unclearCount: Int
    var nexusID: UUID?             // the Nexus event this report belongs to

    // Hashable conformance for CLLocationCoordinate2D
    static func == (lhs: Report, rhs: Report) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
