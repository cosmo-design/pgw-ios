import SwiftUI

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
                    Picker("Filter", selection: $filter) {
                        ForEach(filters, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: filter) { _, _ in Task { await load() } }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    PrivacyBadge()
                }
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

    var body: some View {
        NavigationStack {
            Form {
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
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
            .onAppear { populate() }
        }
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
