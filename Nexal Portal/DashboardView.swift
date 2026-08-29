import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var privacy = PrivacyManager.shared
    @State private var summary: DashboardSummary?
    @State private var chartData: ChartData?
    @State private var isLoading = false
    @State private var error = ""
    @State private var taxYear = 2026

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView().padding(40)
                } else if !error.isEmpty {
                    ContentUnavailableView("Failed to load", systemImage: "exclamationmark.triangle", description: Text(error))
                        .padding()
                } else {
                    VStack(spacing: 20) {
                        // Year label
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
                        }

                        // Summary cards
                        if let s = summary {
                            summaryCards(s)
                        }
                        // By business chart
                        if let cd = chartData, !cd.businessTotals.isEmpty {
                            businessChart(cd.businessTotals)
                        }
                        // By expense account chart
                        if let cd = chartData, !cd.accountTotals.isEmpty {
                            accountChart(Array(cd.accountTotals.prefix(8)))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Dashboard")
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

    // MARK: - Summary Cards
    @ViewBuilder
    func summaryCards(_ s: DashboardSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Total Expenses", value: s.grandTotal.redacted(privacy.isPrivate), icon: "dollarsign.circle.fill", color: .blue)
            StatCard(title: "Transactions", value: "\(s.transactionCount)", icon: "doc.fill", color: .indigo)
            StatCard(title: "Reviewed", value: "\(s.reviewedCount) / \(s.transactionCount)", icon: "checkmark.circle.fill", color: .green)
            StatCard(title: "Avg Confidence", value: s.averageConfidence.map { "\(Int($0 * 100))%" } ?? "—", icon: "chart.bar.fill", color: .orange)
        }
    }

    // MARK: - Business Chart
    @ViewBuilder
    func businessChart(_ totals: [ChartCategory]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By Business").font(.headline)
            Chart(totals) { item in
                SectorMark(
                    angle: .value("Total", item.total),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("Business", item.name ?? "Unknown"))
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartLegend(.hidden)

            // Legend list with amounts
            VStack(spacing: 6) {
                ForEach(totals) { item in
                    HStack {
                        Text(item.name ?? "Unknown").font(.caption).lineLimit(1)
                        Spacer()
                        Text(item.total.redacted(privacy.isPrivate)).font(.caption).bold()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Account Chart
    @ViewBuilder
    func accountChart(_ totals: [ChartCategory]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By Expense Account").font(.headline)
            Chart(totals) { item in
                BarMark(
                    x: .value("Amount", item.total),
                    y: .value("Account", item.name ?? "Unknown")
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(4)
            }
            .frame(height: CGFloat(totals.count) * 36 + 20)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisTick()
                    if !privacy.isPrivate {
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Load
    func load() async {
        isLoading = true
        error = ""
        do {
            async let s = APIClient.shared.getDashboardSummary(taxYear: taxYear)
            async let c = APIClient.shared.getChartData(taxYear: taxYear)
            let (sv, cv) = try await (s, c)
            summary = sv
            chartData = cv
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Spacer()
            }
            Text(value).font(.title2).bold().lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
