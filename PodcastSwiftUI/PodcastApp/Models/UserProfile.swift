import Foundation

struct UserProfile: Codable {
    let userIdentifier: String   // Apple's stable user ID (never changes)
    let fullName: String?        // Only provided on first sign-in
    let email: String?           // Only provided on first sign-in
    let signInDate: Date
}
