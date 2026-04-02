import Foundation

// MARK: - Walking Session State

enum WalkingSessionState: String {
    case idle
    case active
    case paused
    case ended
}

// MARK: - Walking Session Summary

struct WalkingSessionSummary {
    let startDate: Date
    let endDate: Date
    let totalSteps: Int
    let totalDistance: Double // meters
    let elapsedTime: TimeInterval
}
