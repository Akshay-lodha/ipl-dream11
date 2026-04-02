import SwiftUI
import UserNotifications
import AuthenticationServices

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#2D0B6E"), Color.accentColor, Color(hex: "#1A0A3A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < 3 {
                        Button("Skip") {
                            isPresented = false
                            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    } else {
                        Color.clear.frame(height: 16 + 20)
                    }
                }

                TabView(selection: $currentPage) {
                    // Page 1: Welcome
                    OnboardingPage1()
                        .tag(0)

                    // Page 2: Discover
                    OnboardingPage2()
                        .tag(1)

                    // Page 3: Sign in with Apple
                    OnboardingSignInPage(currentPage: $currentPage)
                        .tag(2)

                    // Page 4: Notifications
                    OnboardingPage3(isPresented: $isPresented)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut, value: currentPage)
            }
        }
    }
}

// MARK: - Page 1: Welcome
struct OnboardingPage1: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 80))
                .foregroundStyle(.white)
                .shadow(color: Color.accentColor, radius: 20)

            VStack(spacing: 12) {
                Text("Welcome to Waves")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Your personal podcast companion.\nDiscover, follow, and listen — all in one place.")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 2: Discover
struct OnboardingPage2: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1 + Double(i) * 0.05))
                        .frame(width: 140 + CGFloat(i) * 20, height: 140 + CGFloat(i) * 20)
                        .rotationEffect(.degrees(Double(i) * 8 - 8))
                }
                Image(systemName: "headphones")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
            }
            .frame(height: 200)

            VStack(spacing: 12) {
                Text("Discover Top Podcasts")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Browse top charts, search by category,\nand follow your favorite shows.")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 3: Sign in with Apple
struct OnboardingSignInPage: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white)
                .shadow(color: Color.accentColor, radius: 20)

            VStack(spacing: 12) {
                Text("Your Account")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Sign in to personalize your profile\nand sync your preferences.")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authManager.handleSignIn(result: result)
                    // Advance to next page after sign-in
                    withAnimation { currentPage = 3 }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button(action: {
                    withAnimation { currentPage = 3 }
                }) {
                    Text("Continue without signing in")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Page 4: Notifications
struct OnboardingPage3: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white)
                .symbolRenderingMode(.multicolor)
                .shadow(color: Color.accentColor, radius: 20)

            VStack(spacing: 12) {
                Text("Stay Updated")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Get notified when new episodes drop\nfrom your followed podcasts.")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button(action: {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                }) {
                    Text("Enable Notifications")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.accentColor)
                        )
                }

                Button(action: {
                    isPresented = false
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                }) {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.15))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3), lineWidth: 1))
                        )
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}
