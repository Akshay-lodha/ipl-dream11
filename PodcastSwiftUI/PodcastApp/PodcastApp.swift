import SwiftUI

@main
struct PodcastApp: App {
    @StateObject private var authManager = AuthenticationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .preferredColorScheme(.dark)
                .task {
                    await authManager.checkCredentialState()
                }
        }
    }
}
