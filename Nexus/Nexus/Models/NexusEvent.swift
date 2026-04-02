import Foundation
import CoreLocation

struct NexusEvent: Identifiable {
    let id: UUID
    var title: String
    var summary: String
    var category: EventCategory
    var coordinate: CLLocationCoordinate2D
    var locationLabel: String
    var reports: [Report]
    var discussions: [Discussion]
    var createdAt: Date
    var updatedAt: Date

    var reportCount: Int { reports.count }
    var totalValidations: Int { reports.reduce(0) { $0 + $1.validationCount } }

    enum EventCategory: String, CaseIterable, Identifiable {
        case accident = "Accident"
        case protest = "Protest"
        case fire = "Fire"
        case weather = "Weather"
        case crime = "Crime"
        case traffic = "Traffic"
        case community = "Community"
        case other = "Other"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .accident:  return "car.fill"
            case .protest:   return "megaphone.fill"
            case .fire:      return "flame.fill"
            case .weather:   return "cloud.bolt.rain.fill"
            case .crime:     return "exclamationmark.shield.fill"
            case .traffic:   return "road.lanes"
            case .community: return "person.3.fill"
            case .other:     return "questionmark.circle.fill"
            }
        }

        var color: String {
            switch self {
            case .accident:  return "red"
            case .protest:   return "orange"
            case .fire:      return "red"
            case .weather:   return "blue"
            case .crime:     return "purple"
            case .traffic:   return "yellow"
            case .community: return "green"
            case .other:     return "gray"
            }
        }
    }
}
