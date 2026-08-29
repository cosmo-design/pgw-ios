import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header — Nexus Analytics logo
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 72, height: 72)
                        Circle().fill(Color.blue).frame(width: 16, height: 16)
                        // top node
                        Circle().fill(Color(red: 0.30, green: 0.43, blue: 0.98)).frame(width: 10, height: 10)
                            .offset(y: -28)
                        // bottom-right node
                        Circle().fill(Color(red: 0.30, green: 0.43, blue: 0.98)).frame(width: 10, height: 10)
                            .offset(x: 24, y: 14)
                        // bottom-left node
                        Circle().fill(Color(red: 0.30, green: 0.43, blue: 0.98)).frame(width: 10, height: 10)
                            .offset(x: -24, y: 14)
                        // lines drawn as thin rectangles rotated
                        Rectangle().fill(Color.blue).frame(width: 1.5, height: 20)
                            .offset(y: -18)
                        Rectangle().fill(Color.blue).frame(width: 1.5, height: 20)
                            .rotationEffect(.degrees(60))
                            .offset(x: 12, y: 6)
                        Rectangle().fill(Color.blue).frame(width: 1.5, height: 20)
                            .rotationEffect(.degrees(-60))
                            .offset(x: -12, y: 6)
                    }
                    .frame(width: 80, height: 80)
                    .padding(.bottom, 4)

                    HStack(spacing: 0) {
                        Text("NEXUS ").font(.system(size: 26, weight: .heavy)).foregroundStyle(Color(red: 0.06, green: 0.11, blue: 0.30))
                        Text("ANALYTICS").font(.system(size: 26, weight: .heavy)).foregroundStyle(.blue)
                    }
                    Text("LLC · CLIENT PORTAL")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .kerning(2)
                }
                .padding(.top, 80)
                .padding(.bottom, 48)

                // Form
                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.systemBackground))

                        Divider().padding(.leading)

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color(.systemBackground))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await signIn() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    Button("Forgot Password?") {
                        if let url = URL(string: "\(API_BASE)/forgot-password") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onSubmit { Task { await signIn() } }
    }

    private func signIn() async {
        isLoading = true
        errorMessage = ""
        do {
            try await auth.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
