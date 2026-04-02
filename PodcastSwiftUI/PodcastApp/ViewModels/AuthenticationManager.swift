import AuthenticationServices
import SwiftUI

enum AuthState {
    case unknown
    case signedIn
    case signedOut
}

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var authState: AuthState = .unknown

    private static let keychainService = "com.akshaylodha.waves.auth"
    private static let keychainAccount = "userProfile"

    init() {
        // Load any saved user from Keychain
        currentUser = Self.loadFromKeychain()
        authState = currentUser != nil ? .signedIn : .signedOut
    }

    // MARK: - Public API

    /// Call on app launch to verify Apple credential is still valid
    func checkCredentialState() async {
        guard let userIdentifier = currentUser?.userIdentifier else {
            authState = .signedOut
            return
        }

        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: userIdentifier)
            switch state {
            case .authorized:
                authState = .signedIn
            case .revoked, .notFound:
                // User revoked access or credential not found — sign out
                signOut()
            case .transferred:
                // App was transferred to a new team — treat as signed out
                signOut()
            @unknown default:
                break
            }
        } catch {
            // Network error checking state — keep current state, don't sign out
            print("[Auth] Failed to check credential state: \(error)")
        }
    }

    /// Handle successful Sign in with Apple result
    func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }

            // Build full name from components (only available on first sign-in)
            let fullName: String? = {
                guard let nameComponents = credential.fullName else { return nil }
                let parts = [nameComponents.givenName, nameComponents.familyName].compactMap { $0 }
                return parts.isEmpty ? nil : parts.joined(separator: " ")
            }()

            // If we already have a user with this ID, preserve existing name/email
            // (Apple only sends them on the FIRST authorization)
            let existingUser = Self.loadFromKeychain()
            let user = UserProfile(
                userIdentifier: credential.user,
                fullName: fullName ?? existingUser?.fullName,
                email: credential.email ?? existingUser?.email,
                signInDate: existingUser?.signInDate ?? Date()
            )

            Self.saveToKeychain(user: user)
            currentUser = user
            authState = .signedIn

        case .failure(let error):
            // ASAuthorizationError.canceled means user dismissed the sheet — not a real error
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            print("[Auth] Sign in failed: \(error.localizedDescription)")
        }
    }

    /// Sign out — clear stored credentials
    func signOut() {
        Self.deleteFromKeychain()
        currentUser = nil
        authState = .signedOut
    }

    // MARK: - Keychain Helpers

    private static func saveToKeychain(user: UserProfile) {
        guard let data = try? JSONEncoder().encode(user) else { return }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("[Auth] Keychain save failed: \(status)")
        }
    }

    private static func loadFromKeychain() -> UserProfile? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    private static func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
