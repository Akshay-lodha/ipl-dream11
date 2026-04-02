import Foundation
import CoreLocation

struct MockData {

    // MARK: - Users

    static let users: [User] = [
        User(id: UUID(), username: "alex_t", displayName: "Alex Torres",
             avatarSystemName: "person.crop.circle.fill", reputation: 342,
             joinDate: date(-60), reportCount: 28),
        User(id: UUID(), username: "priya_k", displayName: "Priya Kumar",
             avatarSystemName: "person.crop.circle.fill", reputation: 215,
             joinDate: date(-45), reportCount: 16),
        User(id: UUID(), username: "marcus_w", displayName: "Marcus Williams",
             avatarSystemName: "person.crop.circle.fill", reputation: 187,
             joinDate: date(-30), reportCount: 12),
        User(id: UUID(), username: "sofia_r", displayName: "Sofia Reyes",
             avatarSystemName: "person.crop.circle.fill", reputation: 410,
             joinDate: date(-90), reportCount: 35),
        User(id: UUID(), username: "jin_h", displayName: "Jin Hayashi",
             avatarSystemName: "person.crop.circle.fill", reputation: 98,
             joinDate: date(-10), reportCount: 5),
    ]

    // MARK: - Nexus Events (with embedded reports & discussions)

    static let nexusEvents: [NexusEvent] = {
        let nexus1ID = UUID()
        let nexus2ID = UUID()
        let nexus3ID = UUID()
        let nexus4ID = UUID()

        let reports1: [Report] = [
            Report(id: UUID(), author: users[0],
                   text: "Major water main break on 5th Avenue. Road is completely flooded, cars turning around.",
                   mediaNames: ["photo.fill"], coordinate: CLLocationCoordinate2D(latitude: 40.7484, longitude: -73.9856),
                   locationLabel: "5th Ave & 34th St", timestamp: date(0, hours: -2),
                   validationCount: 12, unclearCount: 1, nexusID: nexus1ID),
            Report(id: UUID(), author: users[1],
                   text: "Water is rushing down the sidewalk here. Police have blocked off two lanes. Crews arriving now.",
                   mediaNames: ["video.fill"], coordinate: CLLocationCoordinate2D(latitude: 40.7486, longitude: -73.9852),
                   locationLabel: "5th Ave & 35th St", timestamp: date(0, hours: -1),
                   validationCount: 8, unclearCount: 0, nexusID: nexus1ID),
            Report(id: UUID(), author: users[4],
                   text: "They're diverting traffic onto Madison. Expect delays if you're heading through midtown.",
                   mediaNames: [], coordinate: CLLocationCoordinate2D(latitude: 40.7488, longitude: -73.9848),
                   locationLabel: "Madison Ave & 35th St", timestamp: Date(),
                   validationCount: 5, unclearCount: 0, nexusID: nexus1ID),
        ]

        let reports2: [Report] = [
            Report(id: UUID(), author: users[2],
                   text: "Large group gathering at City Hall for the climate march. Peaceful, lots of signs and chanting.",
                   mediaNames: ["photo.fill", "photo.fill"], coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                   locationLabel: "City Hall Park", timestamp: date(0, hours: -4),
                   validationCount: 24, unclearCount: 2, nexusID: nexus2ID),
            Report(id: UUID(), author: users[3],
                   text: "March is now moving north on Broadway. Thousands of participants. Traffic stopped on Broadway from Chambers to Canal.",
                   mediaNames: ["photo.fill"], coordinate: CLLocationCoordinate2D(latitude: 40.7158, longitude: -74.0050),
                   locationLabel: "Broadway & Chambers St", timestamp: date(0, hours: -3),
                   validationCount: 31, unclearCount: 0, nexusID: nexus2ID),
        ]

        let reports3: [Report] = [
            Report(id: UUID(), author: users[1],
                   text: "Smoke visible from the building on 8th Street. Fire trucks already on scene. Everyone seems evacuated safely.",
                   mediaNames: ["photo.fill", "video.fill"], coordinate: CLLocationCoordinate2D(latitude: 40.7308, longitude: -73.9973),
                   locationLabel: "8th St & 6th Ave", timestamp: date(-1, hours: -6),
                   validationCount: 18, unclearCount: 1, nexusID: nexus3ID),
        ]

        let reports4: [Report] = [
            Report(id: UUID(), author: users[3],
                   text: "Multi-car pileup on the BQE near Atlantic Ave. At least 4 vehicles involved. Emergency services responding.",
                   mediaNames: ["photo.fill"], coordinate: CLLocationCoordinate2D(latitude: 40.6862, longitude: -73.9776),
                   locationLabel: "BQE & Atlantic Ave", timestamp: date(0, hours: -1),
                   validationCount: 9, unclearCount: 3, nexusID: nexus4ID),
            Report(id: UUID(), author: users[0],
                   text: "Can confirm, BQE is at a standstill. Looks like tow trucks are starting to clear the scene.",
                   mediaNames: [], coordinate: CLLocationCoordinate2D(latitude: 40.6858, longitude: -73.9780),
                   locationLabel: "BQE near Atlantic", timestamp: Date(),
                   validationCount: 6, unclearCount: 0, nexusID: nexus4ID),
        ]

        let discussion1 = Discussion(id: UUID(), nexusID: nexus1ID, messages: [
            .init(id: UUID(), author: users[0], text: "Anyone know which utility company is handling this?", timestamp: date(0, hours: -1)),
            .init(id: UUID(), author: users[1], text: "Saw a DEP truck on site. Might take a few hours to fix.", timestamp: date(0, hours: 0)),
        ])

        let discussion2 = Discussion(id: UUID(), nexusID: nexus2ID, messages: [
            .init(id: UUID(), author: users[2], text: "Great turnout today! Anyone know the official count?", timestamp: date(0, hours: -2)),
            .init(id: UUID(), author: users[3], text: "Organizers are saying over 5,000 people showed up.", timestamp: date(0, hours: -1)),
            .init(id: UUID(), author: users[4], text: "Is it still going? Thinking about heading down.", timestamp: Date()),
        ])

        return [
            NexusEvent(id: nexus1ID, title: "Water Main Break on 5th Avenue",
                       summary: "A major water main break is flooding 5th Avenue between 34th and 36th Streets. Traffic diversions in effect.",
                       category: .community, coordinate: CLLocationCoordinate2D(latitude: 40.7484, longitude: -73.9856),
                       locationLabel: "Midtown Manhattan", reports: reports1, discussions: [discussion1],
                       createdAt: date(0, hours: -2), updatedAt: Date()),
            NexusEvent(id: nexus2ID, title: "Climate March at City Hall",
                       summary: "Thousands are gathering for a climate march starting at City Hall and heading north on Broadway.",
                       category: .protest, coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                       locationLabel: "Lower Manhattan", reports: reports2, discussions: [discussion2],
                       createdAt: date(0, hours: -4), updatedAt: date(0, hours: -3)),
            NexusEvent(id: nexus3ID, title: "Building Fire on 8th Street",
                       summary: "Fire reported in a building near 8th Street and 6th Avenue. Emergency services on scene. No injuries reported.",
                       category: .fire, coordinate: CLLocationCoordinate2D(latitude: 40.7308, longitude: -73.9973),
                       locationLabel: "Greenwich Village", reports: reports3, discussions: [],
                       createdAt: date(-1, hours: -6), updatedAt: date(-1, hours: -6)),
            NexusEvent(id: nexus4ID, title: "Multi-Car Accident on BQE",
                       summary: "A multi-car accident on the Brooklyn-Queens Expressway near Atlantic Avenue is causing major delays.",
                       category: .accident, coordinate: CLLocationCoordinate2D(latitude: 40.6862, longitude: -73.9776),
                       locationLabel: "Brooklyn", reports: reports4, discussions: [],
                       createdAt: date(0, hours: -1), updatedAt: Date()),
        ]
    }()

    // MARK: - Helpers

    private static func date(_ daysOffset: Int, hours: Int = 0) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours,
            to: Calendar.current.date(byAdding: .day, value: daysOffset, to: Date())!)!
    }
}
