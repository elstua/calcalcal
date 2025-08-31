import Foundation

struct DiaryAPI {
    struct AnalyzeResponse: Codable { let success: Bool; let updatedBlocksCount: Int? }
    struct AnalyzeError: Codable { let error: String; let code: String?; let ai_step: String? }
    struct Row: Codable {
        let id: String
        let user_id: String
        let date: String
        let content: String?
        let images: [String]?
        let total_calories: Int?
        let updated_at: String?
    }

    struct DBBlock: Codable {
        let id: String?
        let position: Int?
        let content: String?
        let calories: Int?
        let protein: Double?
        let fat: Double?
        let carbs: Double?
        let fiber: Double?
        let sugar: Double?
        let sodium: Double?
        let confidence: Double?

        /// Convert to AnalyzedBlock for comparison
        func toAnalyzedBlock() -> AnalyzedBlock? {
            guard let id = id, let content = content else { return nil }
            return AnalyzedBlock(
                id: id,
                position: position ?? 0,
                content: content,
                calories: calories,
                protein: protein,
                fat: fat,
                carbs: carbs,
                fiber: fiber,
                sugar: sugar,
                sodium: sodium,
                confidence: confidence,
                aiAnalysis: nil // We'll fetch this separately if needed
            )
        }
    }
    private struct BlocksRow: Codable { let blocks: [DBBlock]? }

    private static func makeRequest(url: URL, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let isWrite = (method == "POST" || method == "PATCH" || method == "PUT" || method == "DELETE")
        if let session = (try? KeychainManager.shared.loadTokens()) ?? nil {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            if isWrite {
                // Writes require authenticated session to satisfy RLS
                throw NSError(domain: "DiaryAPI", code: -10, userInfo: [NSLocalizedDescriptionKey: "Missing session; cannot perform write operation. Please sign in again."])
            }
            // Fallback to anon for read-only endpoints that may not require auth
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
        let userId = UserDefaults.standard.string(forKey: "current_user_id")
        let urlString: String
        if let userId = userId, !userId.isEmpty {
            urlString = "\(base)/rest/v1/diary_entries?select=\(select)&user_id=eq.\(userId)&date=gte.\(dateFrom)&date=lte.\(dateTo)&order=date.desc"
        } else {
            urlString = "\(base)/rest/v1/diary_entries?select=\(select)&date=gte.\(dateFrom)&date=lte.\(dateTo)&order=date.desc"
        }
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
        // Scope by current user_id when available to avoid cross-user matches
        let userId = UserDefaults.standard.string(forKey: "current_user_id")
        let urlString: String
        if let userId = userId, !userId.isEmpty {
            urlString = "\(base)/rest/v1/diary_entries?select=\(select)&date=eq.\(date)&user_id=eq.\(userId)&limit=1"
        } else {
            urlString = "\(base)/rest/v1/diary_entries?select=\(select)&date=eq.\(date)&limit=1"
        }
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let request = try makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let rows = try decodeRows(data)
        return rows.first
    }

    static func getById(_ id: String) async throws -> Row? {
        let base = Configuration.supabaseURL
        let select = "id,user_id,date,content,images,total_calories,updated_at"
        let urlString = "\(base)/rest/v1/diary_entries?select=\(select)&id=eq.\(id)&limit=1"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let request = try makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let rows = try decodeRows(data)
        return rows.first
    }

    static func getBlocksById(_ id: String) async throws -> [DBBlock] {
        let base = Configuration.supabaseURL
        let urlString = "\(base)/rest/v1/diary_entries?select=blocks&id=eq.\(id)&limit=1"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let request = try makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        let rows = try decoder.decode([BlocksRow].self, from: data)
        return rows.first?.blocks ?? []
    }

    /// Get analyzed blocks as AnalyzedBlock structs for change detection
    static func getAnalyzedBlocksById(_ id: String) async throws -> [AnalyzedBlock] {
        let dbBlocks = try await getBlocksById(id)
        return dbBlocks.compactMap { $0.toAnalyzedBlock() }
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
        // Use on_conflict to upsert on (user_id, date)
        let urlString = "\(base)/rest/v1/diary_entries?on_conflict=user_id,date"
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
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            print("❌ Insert failed HTTP=\(status) body=\(bodyText)")
            throw NSError(domain: "DiaryAPI", code: status, userInfo: [NSLocalizedDescriptionKey: "Insert failed (HTTP \(status)): \(bodyText)"])
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
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            print("❌ Update failed HTTP=\(status) body=\(bodyText)")
            throw NSError(domain: "DiaryAPI", code: status, userInfo: [NSLocalizedDescriptionKey: "Update failed (HTTP \(status)): \(bodyText)"])
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

    static func analyze(entryId: String, blocksPayload: [[String: Any]]) async throws -> AnalyzeResponse {
        let base = Configuration.supabaseURL
        // Function is served as single-segment name: ai-analyze
        let urlString = "\(base)/functions/v1/ai-analyze"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let body = try JSONSerialization.data(withJSONObject: [
            "entryId": entryId,
            "blocks": blocksPayload
        ])
        var request = try makeRequest(url: url, method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200..<300).contains(http.statusCode) {
            // Try to decode structured error for debugging
            if let apiErr = try? JSONDecoder().decode(AnalyzeError.self, from: data) {
                print("❌ Analyze HTTP \(http.statusCode): code=\(apiErr.code ?? "-") step=\(apiErr.ai_step ?? "-") error=\(apiErr.error)")
                throw NSError(domain: "DiaryAPI", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: apiErr.error,
                    "code": apiErr.code ?? "",
                    "ai_step": apiErr.ai_step ?? ""
                ])
            } else if let body = String(data: data, encoding: .utf8) {
                print("❌ Analyze HTTP \(http.statusCode) raw body: \(body)")
            }
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(AnalyzeResponse.self, from: data)
    }

    /// Analyze only changed blocks and merge with existing results
    static func analyzeIncremental(entryId: String, blocksPayload: [[String: Any]], existingBlocks: [AnalyzedBlock]) async throws -> AnalyzeResponse {
        let base = Configuration.supabaseURL
        let urlString = "\(base)/functions/v1/ai-analyze"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        // Prepare payload with incremental analysis request
        let body = try JSONSerialization.data(withJSONObject: [
            "entryId": entryId,
            "blocks": blocksPayload,
            "incremental": true,
            "existingBlocks": existingBlocks.map { block in
                [
                    "id": block.id,
                    "position": block.position,
                    "calories": block.calories ?? 0,
                    "protein": block.protein ?? 0.0,
                    "fat": block.fat ?? 0.0,
                    "carbs": block.carbs ?? 0.0,
                    "fiber": block.fiber ?? 0.0,
                    "sugar": block.sugar ?? 0.0,
                    "sodium": block.sodium ?? 0.0,
                    "confidence": block.confidence ?? 0.0
                ]
            }
        ])

        var request = try makeRequest(url: url, method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200..<300).contains(http.statusCode) {
            // Try to decode structured error for debugging
            if let apiErr = try? JSONDecoder().decode(AnalyzeError.self, from: data) {
                print("❌ Incremental Analyze HTTP \(http.statusCode): code=\(apiErr.code ?? "-") step=\(apiErr.ai_step ?? "-") error=\(apiErr.error)")
                throw NSError(domain: "DiaryAPI", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: apiErr.error,
                    "code": apiErr.code ?? "",
                    "ai_step": apiErr.ai_step ?? ""
                ])
            } else if let body = String(data: data, encoding: .utf8) {
                print("❌ Incremental Analyze HTTP \(http.statusCode) raw body: \(body)")
            }
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(AnalyzeResponse.self, from: data)
    }

    /// Clear all nutrition data for an empty diary entry
    static func clearEntryNutrition(entryId: String) async throws {
        let base = Configuration.supabaseURL
        let urlString = "\(base)/rest/v1/diary_entries?id=eq.\(entryId)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let clearData: [String: Any] = [
            "blocks": "[]" as Any, // Clear all blocks
            "total_calories": 0,
            "total_protein": 0.0,
            "total_fat": 0.0,
            "total_carbs": 0.0,
            "total_fiber": 0.0,
            "total_sugar": 0.0,
            "total_sodium": 0.0,
            "ai_analysis_status": "completed" // Mark as completed with zero values
        ]

        let body = try JSONSerialization.data(withJSONObject: clearData)
        let request = try makeRequest(url: url, method: "PATCH", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    /// Delete a diary entry completely
    static func deleteEntry(entryId: String) async throws {
        let base = Configuration.supabaseURL
        let urlString = "\(base)/rest/v1/diary_entries?id=eq.\(entryId)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let request = try makeRequest(url: url, method: "DELETE")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - Mapping helpers
extension DiaryAPI.Row {
    func toDiaryEntry() -> DiaryEntry {
        let uuid = UUID(uuidString: id) ?? UUID()
        // Robustly parse server `date` which may arrive as "YYYY-MM-DD" or ISO8601
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let parsedDate: Date? = {
            // Preferred: strict yyyy-MM-dd
            if let d = dateFormatter.date(from: date) { return d }
            // Fallback: ISO8601 full timestamp
            if let d = isoFormatter.date(from: date) {
                // Normalize to UTC midnight of that local calendar day representation
                // by formatting back to yyyy-MM-dd and re-parsing with the strict formatter.
                let dayString = dateFormatter.string(from: d)
                return dateFormatter.date(from: dayString)
            }
            // Fallback: take first 10 chars if present and try again (e.g., "YYYY-MM-DDTHH:mm:ssZ")
            if date.count >= 10 {
                let prefix = String(date.prefix(10))
                if let d = dateFormatter.date(from: prefix) { return d }
            }
            return nil
        }()
        let dateValue = parsedDate ?? Date.distantPast // avoid collapsing to "today" when parse fails
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


