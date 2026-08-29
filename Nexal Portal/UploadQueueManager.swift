import Foundation
import Combine

// Manages a local queue of pending uploads for when the device is offline
@MainActor
class UploadQueueManager: ObservableObject {
    static let shared = UploadQueueManager()

    @Published var pendingUploads: [PendingUpload] = []
    @Published var isUploading = false

    private let queueKey = "pgw_upload_queue"
    private init() { load() }

    // MARK: - Persistence
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let decoded = try? JSONDecoder().decode([PendingUpload].self, from: data)
        else { return }
        pendingUploads = decoded
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(pendingUploads) {
            UserDefaults.standard.set(encoded, forKey: queueKey)
        }
    }

    // MARK: - Queue management
    func enqueue(_ upload: PendingUpload) {
        pendingUploads.append(upload)
        save()
    }

    func remove(_ upload: PendingUpload) {
        pendingUploads.removeAll { $0.id == upload.id }
        save()
    }

    // MARK: - Process queue
    func processQueue() async {
        guard !isUploading, !pendingUploads.isEmpty else { return }
        isUploading = true

        for upload in pendingUploads {
            do {
                _ = try await APIClient.shared.uploadReceipt(
                    imageData: upload.imageData,
                    fileName: upload.fileName,
                    folderPath: upload.folderPath
                )
                remove(upload)
            } catch {
                // Keep in queue if upload fails — will retry next time
                print("Upload failed for \(upload.fileName): \(error.localizedDescription)")
                break  // Stop processing on first failure (likely offline)
            }
        }

        isUploading = false
    }
}
