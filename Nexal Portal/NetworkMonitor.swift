import Network
import SwiftUI
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    @Published private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}

// Banner shown at the top of any view when offline
struct OfflineBanner: View {
    @ObservedObject var network = NetworkMonitor.shared

    var body: some View {
        if !network.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                Text("No internet connection — check your network")
                    .font(.footnote)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Color.orange)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
