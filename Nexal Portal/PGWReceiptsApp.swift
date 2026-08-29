import SwiftUI

@main
struct PGWReceiptsApp: App {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var queue = UploadQueueManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoading {
                    // Splash while checking session
                    ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                            ProgressView()
                        }
                    }
                } else if auth.isLoggedIn {
                    MainTabView()
                        .environmentObject(auth)
                        .environmentObject(queue)
                        .onAppear {
                            Task { await queue.processQueue() }
                        }
                } else {
                    LoginView()
                        .environmentObject(auth)
                }
            }
        }
    }
}
