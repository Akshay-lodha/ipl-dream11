import SwiftUI

/// Centralised, debounced navigation controller.
/// Prevents double-push from rapid taps — the root cause of zoom-transition
/// source views getting stuck invisible.
@MainActor
final class NavigationCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    /// Minimum interval (seconds) between successive navigations.
    private let debounceInterval: CFAbsoluteTime = 0.5
    private var lastNavTime: CFAbsoluteTime = 0

    func navigate<V: Hashable>(to value: V) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastNavTime > debounceInterval else { return }
        lastNavTime = now
        path.append(value)
    }
}
