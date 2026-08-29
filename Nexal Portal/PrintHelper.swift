import UIKit
import SwiftUI

struct PrintHelper {

    // MARK: - Print Reports
    static func printReports(taxReport: TaxReport?, propertyReport: PropertyReport?, taxYear: Int, isPrivate: Bool) {
        let html = buildReportsHTML(taxReport: taxReport, propertyReport: propertyReport, taxYear: taxYear, isPrivate: isPrivate)
        presentPrint(html: html, jobName: "Expense Report \(taxYear)")
    }

    // MARK: - Print To-Do List
    static func printNotes(notes: [ClientNote]) {
        let html = buildNotesHTML(notes: notes)
        presentPrint(html: html, jobName: "To-Do List")
    }

    // MARK: - Present print controller
    private static func presentPrint(html: String, jobName: String) {
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        formatter.perPageContentInsets = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)

        let ctrl = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = jobName
        info.outputType = .general
        ctrl.printInfo = info
        ctrl.printFormatter = formatter

        ctrl.present(animated: true)
    }

    // MARK: - Reports HTML
    private static func buildReportsHTML(taxReport: TaxReport?, propertyReport: PropertyReport?, taxYear: Int, isPrivate: Bool) -> String {
        func fmt(_ v: Double) -> String {
            isPrivate ? "••••••" : NumberFormatter.currency.string(from: NSNumber(value: v)) ?? "$\(v)"
        }

        var rows = ""
        if let accounts = taxReport?.accounts {
            for a in accounts {
                rows += "<tr><td>\(a.account ?? "Unknown")</td><td>\(a.accountNumber.map { "Acct \($0)" } ?? "")</td><td class='num'>\(fmt(a.total))</td><td class='num'>\(a.count)</td></tr>"
            }
        }

        var bizRows = ""
        if let props = propertyReport?.properties {
            for p in props {
                bizRows += "<tr><td>\(p.business ?? "Unknown")</td><td class='num'>\(fmt(p.total))</td><td class='num'>\(p.count)</td></tr>"
            }
        }

        let grandTotal = fmt(taxReport?.grandTotal ?? 0)

        return """
        <!DOCTYPE html><html><head><meta charset='utf-8'>
        <style>
          body { font-family: -apple-system, Helvetica, Arial, sans-serif; font-size: 13px; color: #111; }
          h1 { font-size: 20px; margin-bottom: 4px; }
          .sub { color: #666; font-size: 12px; margin-bottom: 20px; }
          .total { font-size: 18px; font-weight: bold; margin-bottom: 24px; }
          h2 { font-size: 14px; border-bottom: 1px solid #ddd; padding-bottom: 4px; margin-top: 24px; }
          table { width: 100%; border-collapse: collapse; margin-top: 8px; }
          th { text-align: left; font-size: 11px; color: #555; border-bottom: 1px solid #ccc; padding: 4px 6px; }
          td { padding: 5px 6px; border-bottom: 1px solid #eee; font-size: 12px; }
          .num { text-align: right; }
          .footer { margin-top: 32px; font-size: 10px; color: #999; }
        </style></head><body>
        <h1>Nexus Analytics — Expense Report</h1>
        <div class='sub'>Tax Year \(taxYear)</div>
        <div class='total'>Total Expenses: \(grandTotal)</div>

        <h2>By Expense Account</h2>
        <table>
          <tr><th>Account</th><th>Number</th><th class='num'>Total</th><th class='num'>Txns</th></tr>
          \(rows)
        </table>

        <h2>By Business / Property</h2>
        <table>
          <tr><th>Business</th><th class='num'>Total</th><th class='num'>Txns</th></tr>
          \(bizRows)
        </table>

        <div class='footer'>Printed \(Date().formatted(date: .long, time: .shortened)) · Nexus Analytics LLC</div>
        </body></html>
        """
    }

    // MARK: - Notes HTML
    private static func buildNotesHTML(notes: [ClientNote]) -> String {
        let pending = notes.filter { !$0.done }.sorted { priorityOrder($0) < priorityOrder($1) }
        let done    = notes.filter { $0.done }

        func rows(_ list: [ClientNote]) -> String {
            list.map { n in
                let check = n.done ? "☑" : (n.priority == "high" ? "❗" : "☐")
                let style = n.done ? "color:#999;text-decoration:line-through;" : ""
                let body  = n.body.map { b in b.isEmpty ? "" : "<br><span class='body'>\(b)</span>" } ?? ""
                return "<tr><td class='chk'>\(check)</td><td style='\(style)'>\(n.title)\(body)</td><td class='pri'>\(n.priority)</td></tr>"
            }.joined()
        }

        return """
        <!DOCTYPE html><html><head><meta charset='utf-8'>
        <style>
          body { font-family: -apple-system, Helvetica, Arial, sans-serif; font-size: 13px; color: #111; }
          h1 { font-size: 20px; margin-bottom: 4px; }
          .sub { color: #666; font-size: 12px; margin-bottom: 20px; }
          h2 { font-size: 14px; border-bottom: 1px solid #ddd; padding-bottom: 4px; margin-top: 24px; }
          table { width: 100%; border-collapse: collapse; margin-top: 8px; }
          th { text-align: left; font-size: 11px; color: #555; border-bottom: 1px solid #ccc; padding: 4px 6px; }
          td { padding: 6px 6px; border-bottom: 1px solid #eee; font-size: 12px; vertical-align: top; }
          .chk { width: 24px; font-size: 15px; }
          .pri { width: 60px; color: #888; font-size: 11px; text-align: right; }
          .body { color: #666; font-size: 11px; }
          .footer { margin-top: 32px; font-size: 10px; color: #999; }
        </style></head><body>
        <h1>Nexus Analytics — To-Do List</h1>
        <div class='sub'>Printed \(Date().formatted(date: .long, time: .shortened))</div>

        <h2>Open (\(pending.count))</h2>
        <table>
          <tr><th></th><th>Task</th><th>Priority</th></tr>
          \(rows(pending))
        </table>

        \(done.isEmpty ? "" : """
        <h2>Completed (\(done.count))</h2>
        <table>
          <tr><th></th><th>Task</th><th>Priority</th></tr>
          \(rows(done))
        </table>
        """)

        <div class='footer'>Nexus Analytics LLC</div>
        </body></html>
        """
    }

    private static func priorityOrder(_ n: ClientNote) -> Int {
        switch n.priority { case "high": return 0; case "normal": return 1; default: return 2 }
    }
}

// MARK: - NumberFormatter extension
extension NumberFormatter {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.locale = Locale(identifier: "en_US")
        return f
    }()
}
