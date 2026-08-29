import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var queue: UploadQueueManager
    @ObservedObject var network = NetworkMonitor.shared
    @State private var selectedTab = 1  // To-Do active on login

    var body: some View {
        ZStack(alignment: .top) {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.pie.fill") }
                .tag(0)

            NotesView()
                .tabItem { Label("To-Do", systemImage: "checklist") }
                .tag(1)

            UploadView()
                .environmentObject(auth)
                .environmentObject(queue)
                .tabItem { Label("Upload", systemImage: "camera.fill") }
                .tag(2)

            ReviewQueueView()
                .tabItem { Label("Review", systemImage: "doc.text.magnifyingglass") }
                .tag(3)

            ReportsView()
                .tabItem { Label("Reports", systemImage: "chart.bar.xaxis") }
                .tag(4)

            SettingsView()
                .environmentObject(auth)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(5)
        }
        // Offline banner floats above all tabs
        VStack {
            OfflineBanner()
            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: network.isConnected)
        } // end ZStack
    }
}
