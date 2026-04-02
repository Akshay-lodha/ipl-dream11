import Foundation

struct Discussion: Identifiable {
    let id: UUID
    var nexusID: UUID
    var messages: [Message]

    struct Message: Identifiable {
        let id: UUID
        var author: User
        var text: String
        var timestamp: Date
    }
}
