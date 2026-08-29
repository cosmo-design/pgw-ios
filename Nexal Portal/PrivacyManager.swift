import SwiftUI
import Combine

// MARK: - Global privacy toggle
// When privacyMode is true, amounts and sensitive values are replaced with ••••
class PrivacyManager: ObservableObject {
    static let shared = PrivacyManager()

    @Published var isPrivate: Bool {
        didSet { UserDefaults.standard.set(isPrivate, forKey: "privacyMode") }
    }

    private init() {
        self.isPrivate = UserDefaults.standard.bool(forKey: "privacyMode")
    }
}

// MARK: - Helper extensions
extension Double {
    /// Returns formatted currency string, or "••••••" if privacy mode is on
    func redacted(_ privacy: Bool) -> String {
        privacy ? "••••••" : String(format: "$%.2f", self)
    }
}

extension Optional where Wrapped == Double {
    func redacted(_ privacy: Bool) -> String {
        guard let v = self else { return "—" }
        return v.redacted(privacy)
    }
}

extension String {
    /// Redacts a vendor/name string if privacy mode is on
    func redactedName(_ privacy: Bool) -> String {
        privacy ? "••••••••" : self
    }
}

extension Optional where Wrapped == String {
    func redactedName(_ privacy: Bool) -> String {
        guard let v = self else { return "—" }
        return v.redactedName(privacy)
    }
}

// MARK: - Privacy badge modifier
struct PrivacyBadge: View {
    @ObservedObject var privacy = PrivacyManager.shared

    var body: some View {
        Button {
            privacy.isPrivate.toggle()
        } label: {
            Image(systemName: privacy.isPrivate ? "eye.slash.fill" : "eye.fill")
                .foregroundStyle(privacy.isPrivate ? .orange : .secondary)
        }
    }
}
