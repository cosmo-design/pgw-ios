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
    @State private var taxYear = 2026
    let clients = ["PGW", "JGarcia"]
    let availableYears = [2025, 2026]

    /// Dropbox base path for the selected client + year, e.g. /PGW/2026
    var currentBase: String { "/\(selectedClient)/\(taxYear)" }

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showCamera = false
    @State private var cameraPermissionDenied = false

    @State private var isUploading = false
    @State private var uploadMessage = ""
    @State private var uploadSuccess = false
    @State private var duplicateWarning: DuplicateWarning?
    @State private var pendingForceImage: (UIImage, String)?   // image + fileName to re-upload forced

    @State private var showNewFolderSheet = false
    @State private var newFolderName = ""
    @State private var creatingFolder = false
    @State private var newFolderError = ""

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Client + Year Header
                Section {
                    // Year badge — prominent
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tax Year").font(.caption).foregroundStyle(.secondary)
                            Text(String(taxYear))
                                .font(.title2).bold().foregroundStyle(.blue)
                        }
                        Spacer()
                        Picker("Year", selection: $taxYear) {
                            ForEach(availableYears, id: \.self) { Text(String($0)) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 130)
                        .onChange(of: taxYear) { _, _ in
                            selectedFolder = nil
                            Task { await loadFolders() }
                        }
                    }
                    .padding(.vertical, 4)

                    Picker("Client", selection: $selectedClient) {
                        ForEach(clients, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedClient) { _, _ in
                        selectedFolder = nil
                        Task { await loadFolders() }
                    }

                    // Show resolved Dropbox path
                    Text("Uploading to: \(currentBase)")
                        .font(.caption).foregroundStyle(.secondary)
                } header: {
                    Text("Upload Destination")
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
            .alert(
                "Possible Duplicate",
                isPresented: Binding(get: { duplicateWarning != nil }, set: { if !$0 { duplicateWarning = nil } }),
                presenting: duplicateWarning
            ) { warning in
                Button("Upload Anyway", role: .destructive) {
                    if let (img, name) = pendingForceImage {
                        Task { await forceUpload(image: img, fileName: name) }
                    }
                    duplicateWarning = nil
                }
                Button("Cancel", role: .cancel) {
                    duplicateWarning = nil
                    pendingForceImage = nil
                }
            } message: { warning in
                Text(warning.message)
            }
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
        do {
            let response = try await APIClient.shared.getFolders(base: currentBase)
            folders = response.folders
            baseFolder = response.baseFolder
            // Auto-select the root year folder so user can upload without picking a subfolder
            if selectedFolder == nil {
                selectedFolder = Folder(name: "(\(taxYear) root)", path: currentBase, depth: 0)
            }
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
            } catch APIError.duplicateWarning(let warning) {
                // Pause and let the user decide — store pending image for forced re-upload
                pendingForceImage = (image, fileName)
                duplicateWarning = warning
                isUploading = false
                return  // Stop the batch; user can re-upload remaining after deciding
            } catch {
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

    private func forceUpload(image: UIImage, fileName: String) async {
        guard let folder = selectedFolder,
              let data = image.jpegData(compressionQuality: 0.85) else { return }
        isUploading = true
        do {
            _ = try await APIClient.shared.uploadReceipt(
                imageData: data,
                fileName: fileName,
                folderPath: folder.path,
                force: true
            )
            uploadSuccess = true
            uploadMessage = "Receipt uploaded (duplicate override)."
            selectedImages.removeAll { $0 === image }
        } catch {
            uploadSuccess = false
            uploadMessage = error.localizedDescription
        }
        pendingForceImage = nil
        isUploading = false
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
