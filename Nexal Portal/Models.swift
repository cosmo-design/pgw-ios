import Foundation

// MARK: - API Base URL
let API_BASE = "https://app.nexalworks.com"

// MARK: - Folder
struct Folder: Identifiable, Codable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let depth: Int
}

struct FoldersResponse: Codable {
    let baseFolder: String
    let folders: [Folder]
    enum CodingKeys: String, CodingKey {
        case baseFolder = "base_folder"
        case folders
    }
}

// MARK: - Auth
struct LoginResponse: Codable {
    let success: Bool
    let email: String?
    let role: String?
    let mustChangePassword: Bool?
    enum CodingKeys: String, CodingKey {
        case success, email, role
        case mustChangePassword = "must_change_password"
    }
}

// MARK: - Upload
struct UploadResult: Codable {
    let success: Bool
    let receiptId: Int?
    let dropboxPath: String?
    let fileName: String?
    let status: String?
    enum CodingKeys: String, CodingKey {
        case success
        case receiptId = "receipt_id"
        case dropboxPath = "dropbox_path"
        case fileName = "file_name"
        case status
    }
}

struct PendingUpload: Codable, Identifiable {
    let id: UUID
    let imageData: Data
    let folderPath: String
    let folderName: String
    let fileName: String
    let createdAt: Date

    init(imageData: Data, folderPath: String, folderName: String) {
        self.id = UUID()
        self.imageData = imageData
        self.folderPath = folderPath
        self.folderName = folderName
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        self.fileName = "receipt_\(formatter.string(from: Date())).jpg"
        self.createdAt = Date()
    }
}

// MARK: - Dashboard
struct DashboardSummary: Codable {
    let grandTotal: Double
    let transactionCount: Int
    let categoryCount: Int
    let accountCount: Int
    let reviewedCount: Int
    let averageConfidence: Double?
    let statusCounts: [String: Int]

    enum CodingKeys: String, CodingKey {
        case grandTotal = "grand_total"
        case transactionCount = "transaction_count"
        case categoryCount = "category_count"
        case accountCount = "account_count"
        case reviewedCount = "reviewed_count"
        case averageConfidence = "avg_confidence"
        case statusCounts = "processing_status"
    }
}

struct ChartCategory: Codable, Identifiable {
    var id: String { name ?? "unknown" }
    let name: String?
    let count: Int
    let total: Double
}

struct ChartData: Codable {
    let businessTotals: [ChartCategory]
    let accountTotals: [ChartCategory]
    enum CodingKeys: String, CodingKey {
        case businessTotals = "business_totals"
        case accountTotals = "account_totals"
    }
}

// MARK: - Review Queue
struct ReviewItem: Codable, Identifiable {
    let id: Int
    let vendorName: String?
    let transactionDate: String?
    let amount: Double?
    let businessCategory: String?
    let expenseAccount: String?
    let accountNumber: Int?
    let confidenceScore: Double?
    let reviewed: Bool?
    let notes: String?
    let fileName: String?
    let dropboxPath: String?
    let receiptId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case vendorName = "vendor_name"
        case transactionDate = "transaction_date"
        case amount
        case businessCategory = "business_category"
        case expenseAccount = "expense_account"
        case accountNumber = "account_number"
        case confidenceScore = "confidence_score"
        case reviewed
        case notes
        case fileName = "file_name"
        case dropboxPath = "dropbox_path"
        case receiptId = "receipt_id"
    }
}

struct ReviewQueue: Codable {
    let items: [ReviewItem]
    let total: Int
    let pages: Int
}

struct ReviewOptions: Codable {
    let businessCategories: [String]
    let expenseAccounts: [String]
    enum CodingKeys: String, CodingKey {
        case businessCategories = "business_categories"
        case expenseAccounts = "expense_accounts"
    }
}

// MARK: - Reports
// Matches GET /api/reports/tax-summary
struct TaxReport: Codable {
    let taxYear: Int
    let grandTotal: Double
    let accounts: [AccountTotal]

    enum CodingKeys: String, CodingKey {
        case taxYear = "tax_year"
        case grandTotal = "grand_total"
        case accounts
    }
}

// Matches GET /api/reports/by-property
struct PropertyReport: Codable {
    let taxYear: Int
    let grandTotal: Double
    let properties: [BusinessTotal]

    enum CodingKeys: String, CodingKey {
        case taxYear = "tax_year"
        case grandTotal = "grand_total"
        case properties
    }
}

struct AccountTotal: Codable, Identifiable {
    var id: String { account ?? "unknown" }
    let account: String?
    let accountNumber: Int?
    let total: Double
    let count: Int
    enum CodingKeys: String, CodingKey {
        case account = "expense_account"
        case accountNumber = "account_number"
        case total, count
    }
}

struct BusinessTotal: Codable, Identifiable {
    var id: String { business ?? "unknown" }
    let business: String?
    let total: Double
    let count: Int
    enum CodingKeys: String, CodingKey {
        case business = "business_category"
        case total, count
    }
}

// MARK: - Notes
struct ClientNote: Codable, Identifiable {
    let id: Int
    let title: String
    let body: String?
    let done: Bool
    let priority: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, body, done, priority
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct NotesResponse: Codable {
    let client: String
    let notes: [ClientNote]
}

struct NoteCreateRequest: Codable {
    let client: String
    let title: String
    let body: String?
    let priority: String
}

struct NoteUpdateRequest: Codable {
    let title: String?
    let body: String?
    let done: Bool?
    let priority: String?
}
