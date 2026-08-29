import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var queue: UploadQueueManager

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.pie.fill") }

            ReviewQueueView()
                .tabItem { Label("Review", systemImage: "checklist") }

            UploadView()
                .environmentObject(auth)
                .environmentObject(queue)
                .tabItem { Label("Upload", systemImage: "camera.fill") }

            ReportsView()
                .tabItem { Label("Reports", systemImage: "chart.bar.xaxis") }

            NotesView()
                .tabItem { Label("Notes", systemImage: "note.text") }

            SettingsView()
                .environmentObject(auth)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
