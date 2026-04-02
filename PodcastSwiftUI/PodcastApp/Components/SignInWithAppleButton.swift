import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            authManager.handleSignIn(result: result)
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
