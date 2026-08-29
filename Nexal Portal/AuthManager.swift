import Foundation
import Combine

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isLoggedIn = false
    @Published var userEmail: String? = nil
    @Published var userRole: String? = nil
    @Published var isLoading = true

    private init() {
        userEmail = UserDefaults.standard.string(forKey: "pgw_user_email")
        userRole  = UserDefaults.standard.string(forKey: "pgw_user_role")
        Task { await checkSession() }
    }

    func checkSession() async {
        isLoading = true
        isLoggedIn = await APIClient.shared.checkAuth()
        isLoading = false
    }

    func login(email: String, password: String) async throws {
        let result = try await APIClient.shared.login(email: email, password: password)
        isLoggedIn = result.success
        userEmail = result.email ?? email
        userRole  = result.role
        UserDefaults.standard.set(userEmail, forKey: "pgw_user_email")
        UserDefaults.standard.set(userRole,  forKey: "pgw_user_role")
    }

    func logout() async {
        await APIClient.shared.logout()
        isLoggedIn = false
        userEmail = nil
        userRole  = nil
        UserDefaults.standard.removeObject(forKey: "pgw_user_email")
        UserDefaults.standard.removeObject(forKey: "pgw_user_role")
    }
}
