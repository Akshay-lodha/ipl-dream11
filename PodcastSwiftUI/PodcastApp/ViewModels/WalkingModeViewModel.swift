import Foundation
import Combine

/// Coordinates walking session, health integration, and formatted display values.
class WalkingModeViewModel: ObservableObject {
    @Published var sessionManager = WalkingSessionManager()
    let healthManager = HealthKitManager.shared

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward session manager changes — ensure main thread
        sessionManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Session Control

    func startWalk() {
        sessionManager.requestPermissions()
        sessionManager.startSession()
    }

    func togglePause() {
        if sessionManager.sessionState == .active {
            sessionManager.pauseSession()
        } else if sessionManager.sessionState == .paused {
            sessionManager.resumeSession()
        }
    }

    @MainActor
    func endWalk() async {
        let summary = sessionManager.endSession()

        // Save to HealthKit if connected
        if let summary, healthManager.isConnected {
            do {
                try await healthManager.saveWalkingWorkout(
                    startDate: summary.startDate,
                    endDate: summary.endDate,
                    steps: summary.totalSteps,
                    distance: summary.totalDistance
                )
                print("[Walking] Workout saved to HealthKit: \(summary.totalSteps) steps, \(String(format: "%.0f", summary.totalDistance))m")
            } catch {
                print("[Walking] Failed to save workout: \(error)")
            }
        }

        // Reset to idle so next walk shows splash again
        sessionManager.resetToIdle()
    }

    // MARK: - Computed Display

    var isActive: Bool { sessionManager.sessionState == .active }
    var isPaused: Bool { sessionManager.sessionState == .paused }
    var isRunning: Bool { isActive || isPaused }

    var formattedTime: String {
        let total = Int(sessionManager.elapsedTime)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: sessionManager.steps)) ?? "\(sessionManager.steps)"
    }

    var formattedDistance: String {
        let meters = sessionManager.distance
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}
