import Foundation

struct User: Identifiable, Hashable {
    let id: UUID
    var username: String
    var displayName: String
    var avatarSystemName: String
    var reputation: Int
    var joinDate: Date
    var reportCount: Int
}
