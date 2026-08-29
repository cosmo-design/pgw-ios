import SwiftUI
import PDFKit

struct ReviewQueueView: View {
    @ObservedObject var privacy = PrivacyManager.shared
    @State private var items: [ReviewItem] = []
    @State private var isLoading = false
    @State private var error = ""
    @State private var filter = "problems"
    @State private var taxYear = 2026
    @State private var selectedItem: ReviewItem?

    let filters = ["problems", "unreviewed", "all", "reviewed"]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && items.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !error.isEmpty {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if items.isEmpty {
                    ContentUnavailableView("No Items", systemImage: "tray", description: Text("Nothing in the \(filter) queue"))
                } else {
                    List(items) { item in
                        ReviewRow(item: item, privacy: privacy.isPrivate)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedItem = item }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    Task { await markReviewed(item, reviewed: !(item.reviewed ?? false)) }
                                } label: {
                                    Label(item.reviewed == true ? "Unmark" : "Reviewed",
                                          systemImage: item.reviewed == true ? "xmark.circle" : "checkmark.circle")
                                }
                                .tint(item.reviewed == true ? .orange : .green)
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Review Queue")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 10) {
                        Picker("Filter", selection: $filter) {
                            ForEach(filters, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: filter) { _, _ in Task { await load() } }

                        Picker("Year", selection: $taxYear) {
                            Text("2025").tag(2025)
                            Text("2026").tag(2026)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        .onChange(of: taxYear) { _, _ in Task { await load() } }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    PrivacyBadge()
                }
            }
            .safeAreaInset(edge: .top) {
                // Year banner — same style as Dashboard / Reports
                HStack {
                    Text("Tax Year")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(String(taxYear))
                        .font(.caption).fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                    Spacer()
                    Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
            }
            .task { await load() }
            .refreshable { await load() }
            .sheet(item: $selectedItem) { item in
                ReviewDetailView(item: item, onUpdate: { Task { await load() } })
            }
        }
    }

    func load() async {
        isLoading = true
        error = ""
        do {
            let queue = try await APIClient.shared.getReviewQueue(filter: filter, taxYear: taxYear)
            items = queue.items
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func markReviewed(_ item: ReviewItem, reviewed: Bool) async {
        do {
            try await APIClient.shared.markReviewed(item.id, reviewed: reviewed)
            await load()
        } catch {}
    }
}

// MARK: - Review Row
struct ReviewRow: View {
    let item: ReviewItem
    let privacy: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Confidence dot
            Circle()
                .fill(confidenceColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.vendorName.redactedName(privacy))
                    .font(.headline).lineLimit(1)
                HStack(spacing: 8) {
                    Text(item.transactionDate ?? "No date").font(.caption).foregroundStyle(.secondary)
                    Text(item.expenseAccount ?? "Uncategorized").font(.caption).foregroundStyle(.secondary)
                }
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                        .padding(.top, 1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(item.amount.redacted(privacy)).font(.subheadline).bold()
                if item.reviewed == true {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }

    var confidenceColor: Color {
        let c = item.confidenceScore ?? 0
        if c >= 0.9 { return .green }
        if c >= 0.6 { return .orange }
        return .red
    }
}

// MARK: - Review Detail
struct ReviewDetailView: View {
    let item: ReviewItem
    let onUpdate: () -> Void
    @Environment(\.dismiss) var dismiss
    @ObservedObject var privacy = PrivacyManager.shared

    @State private var vendorName: String = ""
    @State private var date: String = ""
    @State private var amount: String = ""
    @State private var expenseAccount: String = ""
    @State private var businessCategory: String = ""
    @State private var notes: String = ""
    @State private var reviewed: Bool = false
    @State private var isSaving = false
    @State private var error = ""

    // Image
    @State private var imageData: Data?
    @State private var isLoadingImage = false
    @State private var imageError = ""
    @State private var rotationDegrees: Double = 0
    @State private var showFullImage = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Receipt Image
                Section("Receipt") {
                    if isLoadingImage {
                        HStack { Spacer(); ProgressView(); Spacer() }.padding()
                    } else if let data = imageData {
                        receiptImageView(data: data)
                    } else if !imageError.isEmpty {
                        Text(imageError).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("No image on file").font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Transaction") {
                    LabeledContent("File") { Text(item.fileName ?? "—").foregroundStyle(.secondary).font(.caption) }
                    TextField("Vendor", text: $vendorName)
                    TextField("Date (YYYY-MM-DD)", text: $date)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                }
                Section("Category") {
                    TextField("Expense Account", text: $expenseAccount)
                    TextField("Business Category", text: $businessCategory)
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                Section {
                    Toggle("Reviewed", isOn: $reviewed)
                }
                if !error.isEmpty {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaving)
                }
            }
            .onAppear {
                populate()
                Task { await loadImage() }
            }
            .sheet(isPresented: $showFullImage) {
                if let data = imageData {
                    FullReceiptImageView(data: data)
                }
            }
        }
    }

    @ViewBuilder
    func receiptImageView(data: Data) -> some View {
        VStack(spacing: 8) {
            if let uiImage = uiImage(from: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(rotationDegrees))
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture { showFullImage = true }
            } else {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                Text("PDF — tap to view").font(.caption).foregroundStyle(.secondary)
                    .onTapGesture { showFullImage = true }
            }

            HStack(spacing: 20) {
                Button {
                    withAnimation { rotationDegrees -= 90 }
                } label: {
                    Label("Rotate Left", systemImage: "rotate.left")
                        .font(.caption)
                }
                Button {
                    withAnimation { rotationDegrees += 90 }
                } label: {
                    Label("Rotate Right", systemImage: "rotate.right")
                        .font(.caption)
                }
                Spacer()
                Button {
                    showFullImage = true
                } label: {
                    Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
        }
    }

    func uiImage(from data: Data) -> UIImage? {
        if let img = UIImage(data: data) { return img }
        // Try PDF first page
        guard let provider = CGDataProvider(data: data as CFData),
              let pdf = CGPDFDocument(provider),
              let page = pdf.page(at: 1) else { return nil }
        let rect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(rect)
            ctx.cgContext.translateBy(x: 0, y: rect.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            ctx.cgContext.drawPDFPage(page)
        }
    }

    func loadImage() async {
        isLoadingImage = true
        imageError = ""
        do {
            imageData = try await APIClient.shared.getReceiptImage(txnId: item.id)
        } catch {
            imageError = "Could not load image"
        }
        isLoadingImage = false
    }

    func populate() {
        vendorName = item.vendorName ?? ""
        date = item.transactionDate ?? ""
        amount = item.amount.map { String(format: "%.2f", $0) } ?? ""
        expenseAccount = item.expenseAccount ?? ""
        businessCategory = item.businessCategory ?? ""
        notes = item.notes ?? ""
        reviewed = item.reviewed ?? false
    }

    func save() async {
        isSaving = true
        var payload: [String: Any] = ["reviewed": reviewed]
        if !vendorName.isEmpty { payload["vendor_name"] = vendorName }
        if !date.isEmpty { payload["transaction_date"] = date }
        if let a = Double(amount) { payload["amount"] = a }
        if !expenseAccount.isEmpty { payload["expense_account"] = expenseAccount }
        if !businessCategory.isEmpty { payload["business_category"] = businessCategory }
        if !notes.isEmpty { payload["notes"] = notes }
        do {
            try await APIClient.shared.updateTransaction(item.id, payload: payload)
            onUpdate()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Full Screen Image
struct FullReceiptImageView: View {
    let data: Data
    @Environment(\.dismiss) var dismiss
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                if let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(.degrees(rotation))
                        .scaleEffect(scale)
                        .gesture(MagnificationGesture().onChanged { scale = $0 }.onEnded { _ in
                            withAnimation { scale = max(1, scale) }
                        })
                } else if let pdfImg = pdfFirstPage(data) {
                    Image(uiImage: pdfImg)
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(.degrees(rotation))
                }
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button { withAnimation { rotation -= 90 } } label: {
                            Image(systemName: "rotate.left")
                        }
                        Button { withAnimation { rotation += 90 } } label: {
                            Image(systemName: "rotate.right")
                        }
                    }
                }
            }
        }
    }

    func pdfFirstPage(_ data: Data) -> UIImage? {
        guard let provider = CGDataProvider(data: data as CFData),
              let pdf = CGPDFDocument(provider),
              let page = pdf.page(at: 1) else { return nil }
        let rect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { ctx in
            UIColor.white.setFill(); ctx.fill(rect)
            ctx.cgContext.translateBy(x: 0, y: rect.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            ctx.cgContext.drawPDFPage(page)
        }
    }
}
