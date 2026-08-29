import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @ObservedObject var privacy = PrivacyManager.shared
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Privacy
                Section {
                    Toggle(isOn: $privacy.isPrivate) {
                        Label("Privacy Mode", systemImage: privacy.isPrivate ? "eye.slash.fill" : "eye.fill")
                    }
                    .tint(.orange)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("When enabled, all dollar amounts and vendor names are hidden. Useful when viewing the app in public.")
                }

                // MARK: Account
                Section("Account") {
                    LabeledContent("Email") {
                        Text(auth.userEmail ?? "—").foregroundStyle(.secondary)
                    }
                    LabeledContent("Role") {
                        Text(auth.userRole ?? "—").foregroundStyle(.secondary).textCase(.uppercase)
                    }
                    LabeledContent("Portal") {
                        Text("app.nexalworks.com").foregroundStyle(.secondary)
                    }
                }

                // MARK: About
                Section("App") {
                    LabeledContent("Version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Build") {
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Logout
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Sign out of your account?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { await auth.logout() }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
