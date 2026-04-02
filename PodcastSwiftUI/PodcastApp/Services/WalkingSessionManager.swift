import Foundation
import CoreMotion
import CoreLocation

/// Manages pedometer, location, and timer for a walking session.
class WalkingSessionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Published State
    @Published var steps: Int = 0
    @Published var distance: Double = 0 // meters
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var sessionState: WalkingSessionState = .idle

    // MARK: - Private
    private let pedometer = CMPedometer()
    private let locationManager = CLLocationManager()
    private var timer: Timer?
    private var sessionStartDate: Date?

    // Pause/resume tracking
    private var pausedSteps: Int = 0
    private var pausedDistance: Double = 0
    private var pausedElapsedTime: TimeInterval = 0
    private var lastResumeDate: Date?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
    }

    // MARK: - Permissions

    func requestPermissions() {
        locationManager.requestWhenInUseAuthorization()
    }

    var isPedometerAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    // MARK: - Session Control

    func startSession() {
        guard sessionState == .idle else { return }

        sessionStartDate = Date()
        lastResumeDate = sessionStartDate
        steps = 0
        distance = 0
        elapsedTime = 0
        pausedSteps = 0
        pausedDistance = 0
        pausedElapsedTime = 0
        sessionState = .active

        startPedometer(from: sessionStartDate!)
        startTimer()
        locationManager.startUpdatingLocation()
    }

    func pauseSession() {
        guard sessionState == .active else { return }

        sessionState = .paused
        pausedSteps = steps
        pausedDistance = distance
        pausedElapsedTime = elapsedTime

        pedometer.stopUpdates()
        stopTimer()
    }

    func resumeSession() {
        guard sessionState == .paused else { return }

        sessionState = .active
        lastResumeDate = Date()

        startPedometer(from: lastResumeDate!)
        startTimer()
    }

    func endSession() -> WalkingSessionSummary? {
        guard sessionState == .active || sessionState == .paused else { return nil }

        let endDate = Date()
        let summary = WalkingSessionSummary(
            startDate: sessionStartDate ?? endDate,
            endDate: endDate,
            totalSteps: steps,
            totalDistance: distance,
            elapsedTime: elapsedTime
        )

        sessionState = .ended
        pedometer.stopUpdates()
        stopTimer()
        locationManager.stopUpdatingLocation()

        return summary
    }

    /// Reset state so the next session can start fresh with splash.
    func resetToIdle() {
        sessionState = .idle
        steps = 0
        distance = 0
        elapsedTime = 0
    }

    // MARK: - Pedometer

    private func startPedometer(from date: Date) {
        guard isPedometerAvailable else { return }

        pedometer.startUpdates(from: date) { [weak self] data, error in
            guard let self, let data else {
                if let error { print("[Pedometer] Error: \(error)") }
                return
            }
            DispatchQueue.main.async {
                self.steps = self.pausedSteps + data.numberOfSteps.intValue
                if let d = data.distance {
                    self.distance = self.pausedDistance + d.doubleValue
                }
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.sessionState == .active else { return }
            self.elapsedTime += 1
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = location.coordinate
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if sessionState == .active {
                manager.startUpdatingLocation()
            }
        default:
            break
        }
    }
}
