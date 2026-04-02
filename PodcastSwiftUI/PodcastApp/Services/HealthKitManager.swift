import Foundation
import HealthKit

/// Singleton managing HealthKit integration for Walking Mode.
/// Persists connection preference to UserDefaults.
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private static let connectedKey = "healthKitConnected"

    @Published var isConnected: Bool {
        didSet { UserDefaults.standard.set(isConnected, forKey: Self.connectedKey) }
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private init() {
        self.isConnected = UserDefaults.standard.bool(forKey: Self.connectedKey)
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard isHealthDataAvailable else { return false }

        let typesToWrite: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning)
        ]

        let typesToRead: Set<HKObjectType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            await MainActor.run { isConnected = true }
            return true
        } catch {
            print("[HealthKit] Authorization failed: \(error)")
            return false
        }
    }

    // MARK: - Save Workout

    func saveWalkingWorkout(startDate: Date, endDate: Date, steps: Int, distance: Double) async throws {
        guard isConnected, isHealthDataAvailable else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .walking
        config.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
        try await builder.beginCollection(at: startDate)

        // Add step count sample
        if steps > 0 {
            let stepType = HKQuantityType(.stepCount)
            let stepQuantity = HKQuantity(unit: .count(), doubleValue: Double(steps))
            let stepSample = HKQuantitySample(type: stepType, quantity: stepQuantity, start: startDate, end: endDate)
            try await builder.addSamples([stepSample])
        }

        // Add distance sample
        if distance > 0 {
            let distanceType = HKQuantityType(.distanceWalkingRunning)
            let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distance)
            let distanceSample = HKQuantitySample(type: distanceType, quantity: distanceQuantity, start: startDate, end: endDate)
            try await builder.addSamples([distanceSample])
        }

        try await builder.endCollection(at: endDate)
        try await builder.finishWorkout()
    }

    // MARK: - Disconnect

    func disconnect() {
        isConnected = false
    }
}
