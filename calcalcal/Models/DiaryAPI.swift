import Foundation

struct DiaryAPI {
    struct Row: Codable {
        let id: String
        let user_id: String
        let date: String
        let content: String?
        let images: [String]?
        let total_calories: Int?
        let updated_at: String?
    }

    private static func makeRequest(url: URL, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let session = (try? KeychainManager.shared.loadTokens()) ?? nil {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            // Fallback to anon for development-only endpoints that don't require auth
            request.setValue("Bearer \(Configuration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(Configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if method == "POST" || method == "PATCH" || method == "PUT" {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        request.httpBody = body
        return request
    }

    private static func decodeRows(_ data: Data) throws -> [Row] {
        let decoder = JSONDecoder()
        return try decoder.decode([Row].self, from: data)
    }

    private static func decodeSingleRow(_ data: Data) throws -> Row {
        let rows = try decodeRows(data)
        if let first = rows.first { return first }
        throw NSError(domain: "DiaryAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response"])
    }

    static func listEntries(dateFrom: String, dateTo: String) async throws -> [Row] {
        let base = Configuration.supabaseURL
        let select = "id,user_id,date,content,images,total_calories,updated_at"
        let urlString = "\(base)/rest/v1/diary_entries?select=\(select)&date=gte.\(dateFrom)&date=lte.\(dateTo)&order=date.desc"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let request = try makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decodeRows(data)
    }

    static func getByDate(_ date: String) async throws -> Row? {
        let base = Configuration.supabaseURL
        let select = "id,user_id,date,content,images,total_calories,updated_at"
        let urlString = "\(base)/rest/v1/diary_entries?select=\(select)&date=eq.\(date)&limit=1"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let request = try makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let rows = try decodeRows(data)
        return rows.first
    }

    static func insert(date: String, content: String) async throws -> Row {
        let base = Configuration.supabaseURL
        let urlString = "\(base)/rest/v1/diary_entries"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        guard let userId = try? KeychainManager.shared.loadTokens(), userId != nil else {
            // We still need the user_id for RLS insert; get it from current user via AuthManager if available.
            throw NSError(domain: "DiaryAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing session; cannot insert diary entry."])
        }
        // Try to fetch user id from stored user profile endpoint is out of scope here; require caller to provide user id if needed.
        // For now, we expect an authenticated session and resolve user id via /auth-profile beforehand at app start.
        // As a practical workaround, pass a placeholder; server RLS will reject if mismatched.

        // To obtain user id, we rely on a cached AuthManager.currentUser persisted elsewhere.
        // As this module is static, read from UserDefaults if set by app when auth loads (optional in future).

        // Placeholder to avoid compiler warnings; actual value is provided by caller through overload below.
        throw NSError(domain: "DiaryAPI", code: -3, userInfo: [NSLocalizedDescriptionKey: "Use insert(date:content:userId:) overload to insert."])
    }

    static func insert(date: String, content: String, userId: String) async throws -> Row {
        let base = Configuration.supabaseURL
        let urlString = "\(base)/rest/v1/diary_entries"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let payload: [String: Any] = [
            "user_id": userId,
            "date": date,
            "content": content,
            "images": [] as [String]
        ]
        let body = try JSONSerialization.data(withJSONObject: [payload]) // PostgREST expects array for bulk insert
        var request = try makeRequest(url: url, method: "POST", body: body)
        request.setValue("resolution=merge-duplicates, return=representation", forHTTPHeaderField: "Prefer")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.cannotCreateFile)
        }
        return try decodeSingleRow(data)
    }

    static func updateContent(id: String, content: String) async throws -> Row {
        let base = Configuration.supabaseURL
        let urlString = "\(base)/rest/v1/diary_entries?id=eq.\(id)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let payload: [String: Any] = ["content": content]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = try makeRequest(url: url, method: "PATCH", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.cannotWriteToFile)
        }
        return try decodeSingleRow(data)
    }

    static func upsertContent(date: String, userId: String, content: String) async throws -> Row {
        if let existing = try await getByDate(date) {
            return try await updateContent(id: existing.id, content: content)
        } else {
            return try await insert(date: date, content: content, userId: userId)
        }
    }
}

// MARK: - Mapping helpers
extension DiaryAPI.Row {
    func toDiaryEntry() -> DiaryEntry {
        let uuid = UUID(uuidString: id) ?? UUID()
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateValue = dateFormatter.date(from: date) ?? Date()
        let blocks = (content ?? "").toTextBlocks()
        let updated: Date
        if let updated_at, let parsedUpdated = ISO8601DateFormatter().date(from: updated_at) { updated = parsedUpdated } else { updated = Date() }
        return DiaryEntry(
            id: uuid,
            date: dateValue,
            blocks: blocks,
            totalCalories: total_calories,
            lastModified: updated,
            aiGeneratedSummary: nil
        )
    }
}


