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
            case .signedOut:
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
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($emailFocused)
                    .foregroundStyle(TinisColor.ink)
                    .padding(15)
                    .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 10))

                if let message = backend.errorMessage {
                    Text(message)
                        .font(.system(size: 12, design: .rounded))
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
                    HStack {
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
                .disabled(isSending)
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
            Text("We sent a private sign-in link to\n\(email)")
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

private struct TinisInviteView: View {
    @EnvironmentObject private var backend: TinisBackend
    @State private var code = ""
    @State private var isJoining = false
    @FocusState private var codeFocused: Bool

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

            TextField("INVITE CODE", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .tracking(3)
                .foregroundStyle(TinisColor.ink)
                .focused($codeFocused)
                .padding(16)
                .background(TinisColor.cream, in: RoundedRectangle(cornerRadius: 10))

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
                    await backend.joinClub(code: code)
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
            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isJoining)
            .padding(.top, 13)
            Spacer()
        }
        .padding(.horizontal, 28)
        .onAppear { codeFocused = true }
    }
}
