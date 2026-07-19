import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct TinisAuthGateView: View {
    @EnvironmentObject private var backend: TinisBackend

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [TinisColor.darkestForest, TinisColor.deepForest, TinisColor.forest],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            switch backend.phase {
            case .checking:
                ProgressView()
                    .tint(TinisColor.gold)
            case .signedOut, .needsAppleLink:
                TinisEmailSignInView()
            case let .emailSent(email):
                TinisCheckEmailView(email: email)
            case .needsInvite:
                TinisInviteView()
            case .ready, .unavailable:
                EmptyView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct TinisEmailSignInView: View {
    @EnvironmentObject private var backend: TinisBackend
    @State private var email = ""
    @State private var isSending = false
    @FocusState private var emailFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            OliveMark()
                .scaleEffect(1.05)
                .padding(.bottom, 25)
            Text("Welcome to tini’s")
                .font(.system(size: 36, weight: .light, design: .serif))
                .foregroundStyle(TinisColor.cream)
            Text("A private martini club for friends.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(TinisColor.cream.opacity(0.68))
                .padding(.top, 8)
                .padding(.bottom, 34)

            VStack(alignment: .leading, spacing: 11) {
                Text("YOUR EMAIL")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(TinisColor.gold)
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(TinisColor.ink)
                    .focused($emailFocused)
                    .padding(15)
                    .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 10))

                if let message = backend.errorMessage {
                    Text(message)
                        .font(.system(size: 12, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TinisColor.blush)
                }

                Button {
                    guard !isSending else { return }
                    isSending = true
                    Task {
                        await backend.sendMagicLink(to: email)
                        isSending = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSending { ProgressView().tint(TinisColor.ink) }
                        Text(isSending ? "Sending…" : "Email me a sign-in link")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(TinisColor.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(TinisColor.paleGold, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isSending || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(18)
            .background(TinisColor.forest.opacity(0.62), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(TinisColor.gold.opacity(0.28)))

            Text("No password needed. We’ll send a one-time link.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(TinisColor.cream.opacity(0.56))
                .padding(.top, 16)
            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { emailFocused = true }
    }
}

private struct TinisCheckEmailView: View {
    @EnvironmentObject private var backend: TinisBackend
    let email: String

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "envelope.open")
                .font(.system(size: 42, weight: .ultraLight))
                .foregroundStyle(TinisColor.gold)
            Text("Check your email")
                .font(.system(size: 34, design: .serif))
                .foregroundStyle(TinisColor.cream)
            Text("We sent a private sign-in link to\n\(email)\n\nOpen it on this device to enter the club.")
                .multilineTextAlignment(.center)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(TinisColor.cream.opacity(0.72))
                .lineSpacing(5)
            Button("Use a different email") {
                backend.useDifferentEmail()
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(TinisColor.gold)
            .padding(.top, 8)
            Spacer()
        }
        .padding(24)
    }
}

private struct TinisAppleSignInView: View {
    @EnvironmentObject private var backend: TinisBackend
    let linkExistingAccount: Bool
    @State private var currentNonce: String?
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            OliveMark()
                .scaleEffect(1.05)
                .padding(.bottom, 25)
            Text(linkExistingAccount ? "Keep your rankings" : "Welcome to tini’s")
                .font(.system(size: 36, weight: .light, design: .serif))
                .foregroundStyle(TinisColor.cream)
            Text(
                linkExistingAccount
                    ? "Connect Apple once so your existing ratings follow you to every iPhone."
                    : "A private martini club for friends."
            )
                .font(.system(size: 14, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(TinisColor.cream.opacity(0.68))
                .padding(.top, 8)
                .padding(.bottom, 34)

            VStack(spacing: 13) {
                SignInWithAppleButton(.continue) { request in
                    let nonce = Self.randomNonceString()
                    currentNonce = nonce
                    isSigningIn = true
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    completeAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .allowsHitTesting(!isSigningIn)

                if isSigningIn {
                    ProgressView("Joining the club…")
                        .font(.system(size: 12, design: .rounded))
                        .tint(TinisColor.gold)
                        .foregroundStyle(TinisColor.cream.opacity(0.72))
                } else if let message = backend.errorMessage {
                    Text(message)
                        .font(.system(size: 12, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TinisColor.blush)
                }
            }
            .padding(18)
            .background(TinisColor.forest.opacity(0.62), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(TinisColor.gold.opacity(0.28)))

            Text("No password or text message. Your Apple Account keeps your rankings connected across devices.")
                .font(.system(size: 11, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(TinisColor.cream.opacity(0.56))
                .padding(.top, 16)
                .padding(.horizontal, 18)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case let .failure(error):
            isSigningIn = false
            currentNonce = nil
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return
            }
            backend.reportSignInError("Apple sign-in was interrupted. Please try again.")
        case let .success(authorization):
            guard
                let nonce = currentNonce,
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                isSigningIn = false
                backend.reportSignInError("Apple did not return a valid sign-in. Please try again.")
                return
            }

            let displayName = credential.fullName?.formatted()
            Task {
                await backend.continueWithApple(
                    idToken: identityToken,
                    nonce: nonce,
                    displayName: displayName,
                    linkExistingAccount: linkExistingAccount
                )
                isSigningIn = false
                currentNonce = nil
            }
        }
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let characterSet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            precondition(status == errSecSuccess)

            for randomByte in randomBytes where remainingLength > 0 {
                if Int(randomByte) < characterSet.count {
                    result.append(characterSet[Int(randomByte)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
}

private struct TinisInviteView: View {
    @EnvironmentObject private var backend: TinisBackend
    @State private var displayName = ""
    @State private var code = ""
    @State private var isJoining = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case displayName
        case code
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            OliveMark()
                .padding(.bottom, 22)
            Text("One last thing")
                .font(.system(size: 34, design: .serif))
                .foregroundStyle(TinisColor.cream)
            Text("Enter the club code Veronica shared with you.")
                .font(.system(size: 14, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(TinisColor.cream.opacity(0.68))
                .padding(.top, 8)
                .padding(.bottom, 30)

            TextField("YOUR NAME", text: $displayName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(TinisColor.ink)
                .focused($focusedField, equals: .displayName)
                .padding(16)
                .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 10))

            TextField("INVITE CODE", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .tracking(3)
                .foregroundStyle(TinisColor.ink)
                .focused($focusedField, equals: .code)
                .padding(16)
                .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 12)

            if let message = backend.errorMessage {
                Text(message)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(TinisColor.blush)
                    .padding(.top, 10)
            }

            Button {
                guard !isJoining else { return }
                isJoining = true
                Task {
                    let savedName = await backend.updateDisplayName(displayName)
                    if savedName {
                        await backend.joinClub(code: code)
                    }
                    isJoining = false
                }
            } label: {
                HStack {
                    if isJoining { ProgressView().tint(TinisColor.ink) }
                    Text(isJoining ? "Joining…" : "Enter the club")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(TinisColor.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(TinisColor.paleGold, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(
                displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                isJoining
            )
            .padding(.top, 13)
            Spacer()
        }
        .padding(.horizontal, 28)
        .onAppear {
            displayName = backend.currentDisplayName ?? ""
            focusedField = displayName.isEmpty ? .displayName : .code
        }
    }
}
