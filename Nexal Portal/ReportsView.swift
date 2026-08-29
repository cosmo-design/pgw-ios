import SwiftUI
import Charts

struct ReportsView: View {
    @ObservedObject var privacy = PrivacyManager.shared
    @State private var taxReport: TaxReport?
    @State private var propertyReport: PropertyReport?
    @State private var isLoading = false
    @State private var error = ""
    @State private var taxYear = 2026

    var grandTotal: Double { taxReport?.grandTotal ?? 0 }
    var transactionCount: Int { (taxReport?.accounts.reduce(0) { $0 + $1.count }) ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView().padding(40)
                } else if !error.isEmpty {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error)).padding()
                } else if taxReport != nil || propertyReport != nil {
                    VStack(spacing: 20) {
                        // Totals header
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Expenses").font(.caption).foregroundStyle(.secondary)
                                Text(grandTotal.redacted(privacy.isPrivate)).font(.largeTitle).bold()
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Tax Year").font(.caption).foregroundStyle(.secondary)
                                Text(String(taxYear))
                                    .font(.title).bold().foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)

                        // By Expense Account
                        if let accounts = taxReport?.accounts, !accounts.isEmpty {
                            byAccountSection(accounts)
                        }

                        // By Business / Property
                        if let props = propertyReport?.properties, !props.isEmpty {
                            byBusinessSection(props)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Picker("Year", selection: $taxYear) {
                        Text("2025").tag(2025)
                        Text("2026").tag(2026)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    .onChange(of: taxYear) { _, _ in Task { await load() } }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    PrivacyBadge()
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder
    func byAccountSection(_ accounts: [AccountTotal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Expense Account").font(.headline)

            Chart(accounts.prefix(10)) { item in
                BarMark(
                    x: .value("Total", item.total),
                    y: .value("Account", item.account ?? "Unknown")
                )
                .foregroundStyle(Color.indigo.gradient)
                .cornerRadius(4)
            }
            .frame(height: CGFloat(min(accounts.count, 10)) * 38 + 20)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    if !privacy.isPrivate { AxisValueLabel() }
                }
            }

            Divider()
            ForEach(accounts) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.account ?? "Unknown").font(.subheadline)
                        if let num = item.accountNumber {
                            Text("Acct \(num)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.total.redacted(privacy.isPrivate)).font(.subheadline).bold()
                        Text("\(item.count) txns").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                Divider()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    func byBusinessSection(_ businesses: [BusinessTotal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Business").font(.headline)
            ForEach(businesses) { item in
                HStack {
                    Text(item.business ?? "Unknown").font(.subheadline)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.total.redacted(privacy.isPrivate)).font(.subheadline).bold()
                        Text("\(item.count) txns").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                Divider()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    func load() async {
        isLoading = true
        error = ""
        async let tax = APIClient.shared.getTaxReport(taxYear: taxYear)
        async let prop = APIClient.shared.getPropertyReport(taxYear: taxYear)
        do {
            taxReport = try await tax
        } catch {
            self.error = error.localizedDescription
        }
        do {
            propertyReport = try await prop
        } catch {}
        isLoading = false
    }
}
