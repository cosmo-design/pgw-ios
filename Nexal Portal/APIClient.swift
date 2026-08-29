import Foundation
import UIKit

// MARK: - API errors
enum APIError: LocalizedError {
    case invalidURL, notAuthenticated, decodingError
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid URL"
        case .notAuthenticated:    return "Not logged in"
        case .decodingError:       return "Unexpected server response"
        case .serverError(let m):  return m
        }
    }
}

// MARK: - Shared session
class APIClient {
    static let shared = APIClient()

    let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpShouldSetCookies = true
        cfg.httpCookieAcceptPolicy = .always
        return URLSession(configuration: cfg)
    }()

    private init() {}

    // MARK: - Auth
    func login(email: String, password: String) async throws -> LoginResponse {
        let url = try url("/api/auth/login")
        var req = post(url)
        req.httpBody = try JSONEncoder().encode(["email": email, "password": password])
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.serverError("No response") }
        if http.statusCode == 401 { throw APIError.serverError("Invalid email or password") }
        if http.statusCode != 200 { throw serverError(data, fallback: "Login failed") }
        return try decode(data)
    }

    func checkAuth() async -> Bool {
        guard let url = URL(string: "\(API_BASE)/api/auth/me") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (_, resp) = (try? await session.data(for: req)) ?? (Data(), nil)
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }

    func logout() async {
        if let url = URL(string: "\(API_BASE)/api/auth/logout") {
            var req = URLRequest(url: url); req.httpMethod = "POST"
            _ = try? await session.data(for: req)
        }
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
    }

    // MARK: - Dashboard
    func getDashboardSummary(taxYear: Int = 2026) async throws -> DashboardSummary {
        let url = try url("/api/dashboard/summary", query: ["tax_year": "\(taxYear)"])
        let (data, _) = try await session.data(from: url)
        return try decode(data)
    }

    func getChartData(taxYear: Int = 2026) async throws -> ChartData {
        let url = try url("/api/dashboard/chart-data", query: ["tax_year": "\(taxYear)"])
        let (data, _) = try await session.data(from: url)
        return try decode(data)
    }

    // MARK: - Review Queue
    func getReviewQueue(filter: String = "all", page: Int = 1, limit: Int = 50, taxYear: Int = 2026) async throws -> ReviewQueue {
        let url = try url("/api/review/queue", query: [
            "filter": filter, "page": "\(page)", "limit": "\(limit)", "tax_year": "\(taxYear)"
        ])
        let (data, _) = try await session.data(from: url)
        return try decode(data)
    }

    func updateTransaction(_ txnId: Int, payload: [String: Any]) async throws {
        let url = try url("/api/review/transaction/\(txnId)")
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.serverError("Update failed")
        }
    }

    func markReviewed(_ txnId: Int, reviewed: Bool) async throws {
        try await updateTransaction(txnId, payload: ["reviewed": reviewed])
    }

    func getReviewOptions() async throws -> ReviewOptions {
        let url = try url("/api/review/options")
        let (data, _) = try await session.data(from: url)
        return try decode(data)
    }

    // MARK: - Reports
    func getTaxReport(taxYear: Int = 2026) async throws -> TaxReport {
        let url = try url("/api/reports/tax-summary", query: ["tax_year": "\(taxYear)"])
        let (data, _) = try await session.data(from: url)
        return try decode(data)
    }

    func getPropertyReport(taxYear: Int = 2026) async throws -> PropertyReport {
        let url = try url("/api/reports/by-property", query: ["tax_year": "\(taxYear)"])
        let (data, _) = try await session.data(from: url)
        return try decode(data)
    }

    // MARK: - Notes
    func getNotes(client: String = "PGW") async throws -> [ClientNote] {
        let url = try url("/api/notes", query: ["client": client, "include_done": "true"])
        let (data, _) = try await session.data(from: url)
        let response: NotesResponse = try decode(data)
        return response.notes
    }

    func createNote(title: String, body: String?, priority: String, client: String = "PGW") async throws -> ClientNote {
        let url = try url("/api/notes")
        var req = post(url)
        req.httpBody = try JSONEncoder().encode(NoteCreateRequest(client: client, title: title, body: body, priority: priority))
        let (data, _) = try await session.data(for: req)
        return try decode(data)
    }

    func updateNote(_ id: Int, title: String? = nil, body: String? = nil, done: Bool? = nil, priority: String? = nil) async throws {
        let url = try url("/api/notes/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(NoteUpdateRequest(title: title, body: body, done: done, priority: priority))
        _ = try await session.data(for: req)
    }

    func deleteNote(_ id: Int) async throws {
        let url = try url("/api/notes/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        _ = try await session.data(for: req)
    }

    // MARK: - Uploads
    func getFolders(base: String = "") async throws -> FoldersResponse {
        var comps = URLComponents(string: "\(API_BASE)/api/uploads/folders")!
        comps.queryItems = [URLQueryItem(name: "base", value: base)]
        let (data, resp) = try await session.data(from: comps.url!)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.serverError("Failed to load folders") }
        return try decode(data)
    }

    func createFolder(name: String, parent: String) async throws -> Folder {
        let url = try url("/api/uploads/folder")
        var req = post(url)
        req.httpBody = try JSONEncoder().encode(["name": name, "parent": parent])
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.serverError("No response") }
        if http.statusCode == 409 { throw APIError.serverError("Folder already exists") }
        if let dict = try? JSONDecoder().decode([String: String].self, from: data),
           let path = dict["path"], let folderName = dict["name"] {
            return Folder(name: folderName, path: path, depth: 1)
        }
        throw APIError.decodingError
    }

    func uploadReceipt(imageData: Data, fileName: String, folderPath: String) async throws -> UploadResult {
        let url = try url("/api/uploads/receipt")
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = buildMultipart(boundary: boundary, imageData: imageData, fileName: fileName, folderPath: folderPath)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.serverError("No response") }
        if http.statusCode == 409 { throw APIError.serverError("Duplicate receipt — already uploaded") }
        if http.statusCode != 200 { throw serverError(data, fallback: "Upload failed") }
        return try decode(data)
    }

    // MARK: - Helpers
    private func url(_ path: String, query: [String: String] = [:]) throws -> URL {
        var comps = URLComponents(string: "\(API_BASE)\(path)")!
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps.url else { throw APIError.invalidURL }
        return url
    }

    private func post(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(T.self, from: data) else {
            throw APIError.decodingError
        }
        return result
    }

    private func serverError(_ data: Data, fallback: String) -> APIError {
        let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"] ?? fallback
        return .serverError(msg)
    }

    private func buildMultipart(boundary: String, imageData: Data, fileName: String, folderPath: String) -> Data {
        var body = Data()
        let crlf = "\r\n"
        func a(_ s: String) { body.append(s.data(using: .utf8)!) }
        a("--\(boundary)\(crlf)")
        a("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(crlf)")
        a("Content-Type: image/jpeg\(crlf)\(crlf)")
        body.append(imageData)
        a(crlf)
        a("--\(boundary)\(crlf)")
        a("Content-Disposition: form-data; name=\"dropbox_folder\"\(crlf)\(crlf)")
        a(folderPath)
        a(crlf)
        a("--\(boundary)\(crlf)")
        a("Content-Disposition: form-data; name=\"tax_year\"\(crlf)\(crlf)")
        a("2026")
        a(crlf)
        a("--\(boundary)--\(crlf)")
        return body
    }
}
