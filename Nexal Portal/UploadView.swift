import SwiftUI
import PhotosUI
import AVFoundation

struct UploadView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var queue: UploadQueueManager

    @State private var folders: [Folder] = []
    @State private var baseFolder = ""
    @State private var selectedFolder: Folder? = nil
    @State private var loadingFolders = false
    @State private var folderError = ""
    @State private var selectedClient = "PGW"
    let clients = ["PGW", "JGarcia"]
    // Dropbox root paths for each client (must match actual Dropbox folder names)
    let clientRoots = ["PGW": "/PGW", "JGarcia": "/JGarcia"]

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showCamera = false
    @State private var cameraPermissionDenied = false

    @State private var isUploading = false
    @State private var uploadMessage = ""
    @State private var uploadSuccess = false

    @State private var showNewFolderSheet = false
    @State private var newFolderName = ""
    @State private var creatingFolder = false
    @State private var newFolderError = ""

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Client Picker
                Section {
                    Picker("Client", selection: $selectedClient) {
                        ForEach(clients, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedClient) { _, _ in
                        selectedFolder = nil
                        Task { await loadFolders() }
                    }
                } header: {
                    Text("Client")
                }

                // MARK: Folder Picker
                Section {
                    if loadingFolders {
                        HStack {
                            ProgressView()
                            Text("Loading folders…").foregroundStyle(.secondary)
                        }
                    } else if !folderError.isEmpty {
                        Text(folderError).foregroundStyle(.red).font(.footnote)
                    } else {
                        Picker("Destination", selection: $selectedFolder) {
                            Text("Select a folder").tag(Optional<Folder>(nil))
                            if !baseFolder.isEmpty {
                                Text(baseFolder + " (root)").tag(Optional(Folder(name: "root", path: baseFolder, depth: 0)))
                            }
                            ForEach(folders) { folder in
                                Text(folder.name).tag(Optional(folder))
                            }
                        }
                        .pickerStyle(.navigationLink)

                        Button("Create New Folder…") {
                            showNewFolderSheet = true
                        }
                        .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Destination Folder")
                } footer: {
                    if let folder = selectedFolder {
                        Text(folder.path).font(.caption).foregroundStyle(.secondary)
                    }
                }

                // MARK: Photo Picker
                Section("Receipt Photos") {
                    Button {
                        let status = AVCaptureDevice.authorizationStatus(for: .video)
                        switch status {
                        case .authorized:
                            showCamera = true
                        case .notDetermined:
                            AVCaptureDevice.requestAccess(for: .video) { granted in
                                DispatchQueue.main.async {
                                    if granted { showCamera = true }
                                    else { cameraPermissionDenied = true }
                                }
                            }
                        default:
                            cameraPermissionDenied = true
                        }
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                    }
                    .alert("Camera Access Needed", isPresented: $cameraPermissionDenied) {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Enable camera access in Settings → Nexal Portal → Camera.")
                    }

                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle.angled")
                    }
                    .onChange(of: pickerItems) { _, newItems in
                        Task { await loadImages(from: newItems) }
                    }

                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedImages.indices, id: \.self) { i in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[i])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button {
                                            selectedImages.remove(at: i)
                                            pickerItems.remove(at: i)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .black.opacity(0.6))
                                        }
                                        .padding(2)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Text("\(selectedImages.count) photo\(selectedImages.count == 1 ? "" : "s") selected")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Upload Button
                Section {
                    Button {
                        Task { await uploadReceipts() }
                    } label: {
                        HStack {
                            Spacer()
                            if isUploading {
                                ProgressView().tint(.white)
                                Text("Uploading…").foregroundStyle(.white)
                            } else {
                                Image(systemName: "arrow.up.to.cloud.fill")
                                Text("Upload \(selectedImages.isEmpty ? "" : "\(selectedImages.count) ")to Dropbox")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUploading || selectedImages.isEmpty || selectedFolder == nil)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // MARK: Result message
                if !uploadMessage.isEmpty {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: uploadSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(uploadSuccess ? .green : .red)
                            Text(uploadMessage)
                                .font(.footnote)
                        }
                    }
                }

                // MARK: Offline Queue
                if !queue.pendingUploads.isEmpty {
                    Section {
                        ForEach(queue.pendingUploads) { upload in
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(upload.fileName).font(.footnote)
                                    Text(upload.folderName).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }

                        Button {
                            Task { await queue.processQueue() }
                        } label: {
                            Label("Retry Pending Uploads", systemImage: "arrow.clockwise")
                        }
                        .foregroundStyle(.orange)
                    } header: {
                        Text("Pending (\(queue.pendingUploads.count))")
                    } footer: {
                        Text("These will upload automatically when connected.")
                    }
                }
            }
            .navigationTitle("Upload Receipts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") {
                        Task { await auth.logout() }
                    }
                    .foregroundStyle(.red)
                }
            }
            .sheet(isPresented: $showNewFolderSheet) {
                newFolderSheet
            }
            .sheet(isPresented: $showCamera) {
                CameraView { image in
                    selectedImages.append(image)
                    showCamera = false
                }
            }
            .task { await loadFolders() }
            .refreshable { await loadFolders() }
        }
    }

    // MARK: - New Folder Sheet
    var newFolderSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Folder name", text: $newFolderName)
                        .autocapitalization(.words)
                } footer: {
                    Text("Will be created inside: \(selectedFolder?.path ?? baseFolder)")
                }

                if !newFolderError.isEmpty {
                    Section {
                        Text(newFolderError).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNewFolderSheet = false
                        newFolderName = ""
                        newFolderError = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createFolder() }
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty || creatingFolder)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions
    private func loadFolders() async {
        loadingFolders = true
        folderError = ""
        let base = clientRoots[selectedClient] ?? "/\(selectedClient)"
        do {
            let response = try await APIClient.shared.getFolders(base: base)
            folders = response.folders
            baseFolder = response.baseFolder
        } catch {
            folderError = error.localizedDescription
        }
        loadingFolders = false
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        selectedImages = images
    }

    private func uploadReceipts() async {
        guard let folder = selectedFolder else { return }
        isUploading = true
        uploadMessage = ""
        var successCount = 0

        for (i, image) in selectedImages.enumerated() {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let fileName = "receipt_\(formatter.string(from: Date()))_\(i+1).jpg"

            guard let data = image.jpegData(compressionQuality: 0.85) else { continue }

            do {
                _ = try await APIClient.shared.uploadReceipt(
                    imageData: data,
                    fileName: fileName,
                    folderPath: folder.path
                )
                successCount += 1
            } catch {
                // Queue for later if offline
                let pending = PendingUpload(imageData: data, folderPath: folder.path, folderName: folder.name)
                queue.enqueue(pending)
            }
        }

        isUploading = false
        let queued = selectedImages.count - successCount

        if successCount > 0 {
            uploadSuccess = true
            uploadMessage = "\(successCount) receipt\(successCount == 1 ? "" : "s") uploaded to Dropbox."
            selectedImages = []
            pickerItems = []
        }
        if queued > 0 {
            uploadSuccess = false
            uploadMessage += " \(queued) queued for retry when online."
        }
    }

    private func createFolder() async {
        creatingFolder = true
        newFolderError = ""
        let parent = selectedFolder?.path ?? baseFolder
        do {
            let folder = try await APIClient.shared.createFolder(name: newFolderName.trimmingCharacters(in: .whitespaces), parent: parent)
            folders.append(folder)
            folders.sort { $0.name < $1.name }
            selectedFolder = folder
            showNewFolderSheet = false
            newFolderName = ""
        } catch {
            newFolderError = error.localizedDescription
        }
        creatingFolder = false
    }
}
