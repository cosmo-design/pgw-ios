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
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue)
                        .padding(.bottom, 4)
                    Text("Nexus Analytics LLC")
                        .font(.largeTitle).bold()
                    Text("Client Portal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
