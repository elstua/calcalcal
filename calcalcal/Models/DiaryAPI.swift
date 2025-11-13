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

        enum CodingKeys: String, CodingKey {
            case id, position, content, calories, protein, fat, carbs, fiber, sugar, sodium, confidence
        }

        init(id: String?, position: Int?, content: String?, calories: Int?, protein: Double?, fat: Double?, carbs: Double?, fiber: Double?, sugar: Double?, sodium: Double?, confidence: Double?) {
            self.id = id
            self.position = position
            self.content = content
            self.calories = calories
            self.protein = protein
            self.fat = fat
            self.carbs = carbs
            self.fiber = fiber
            self.sugar = sugar
            self.sodium = sodium
            self.confidence = confidence
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try? c.decode(String.self, forKey: .id)
            self.position = c.decodeIntForgiving(forKey: .position)
            self.content = try? c.decode(String.self, forKey: .content)
            self.calories = c.decodeIntForgiving(forKey: .calories)
            self.protein = c.decodeDoubleForgiving(forKey: .protein)
            self.fat = c.decodeDoubleForgiving(forKey: .fat)
            self.carbs = c.decodeDoubleForgiving(forKey: .carbs)
            self.fiber = c.decodeDoubleForgiving(forKey: .fiber)
            self.sugar = c.decodeDoubleForgiving(forKey: .sugar)
            self.sodium = c.decodeDoubleForgiving(forKey: .sodium)
            self.confidence = c.decodeDoubleForgiving(forKey: .confidence)
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(id, forKey: .id)
            try c.encodeIfPresent(position, forKey: .position)
            try c.encodeIfPresent(content, forKey: .content)
            try c.encodeIfPresent(calories, forKey: .calories)
            try c.encodeIfPresent(protein, forKey: .protein)
            try c.encodeIfPresent(fat, forKey: .fat)
            try c.encodeIfPresent(carbs, forKey: .carbs)
            try c.encodeIfPresent(fiber, forKey: .fiber)
            try c.encodeIfPresent(sugar, forKey: .sugar)
            try c.encodeIfPresent(sodium, forKey: .sodium)
            try c.encodeIfPresent(confidence, forKey: .confidence)
        }

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
                // Writes require authenticated session
                throw NSError(domain: "DiaryAPI", code: -10, userInfo: [NSLocalizedDescriptionKey: "Missing session; cannot perform write operation. Please sign in again."])
            }
            // Reads also require auth in new backend
            throw NSError(domain: "DiaryAPI", code: -10, userInfo: [NSLocalizedDescriptionKey: "Missing session; please sign in."])
        }
        // No apikey header needed - backend uses JWT token for auth
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
        let base = Configuration.apiURL
        // Backend automatically filters by user_id from JWT token
        let urlString = "\(base)/api/diary/entries?dateFrom=\(dateFrom)&dateTo=\(dateTo)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let request = try makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // Backend returns array directly
        return try decodeRows(data)
    }

    static func getByDate(_ date: String) async throws -> Row? {
        // Use listEntries with same date for both from/to
        let entries = try await listEntries(dateFrom: date, dateTo: date)
        return entries.first
    }

    static func getById(_ id: String) async throws -> Row? {
        let base = Configuration.apiURL
        let urlString = "\(base)/api/diary/entries/\(id)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let request = try makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // Backend returns single object, not array
        let decoder = JSONDecoder()
        return try decoder.decode(Row.self, from: data)
    }

    static func getBlocksById(_ id: String) async throws -> [DBBlock] {
        // Get full entry via getById, then extract blocks
        let entry = try await getById(id)
        // Entry should have blocks field - need to decode it
        // For now, we'll need to fetch the full entry with blocks
        // Let's create a helper that gets the full entry including blocks
        let base = Configuration.apiURL
        let urlString = "\(base)/api/diary/entries/\(id)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let request = try makeRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        struct FullEntry: Codable {
            let blocks: [DBBlock]?
        }
        let fullEntry = try decoder.decode(FullEntry.self, from: data)
        print("🐛 DEBUG: getBlocksById(\(id)) returning \(fullEntry.blocks?.count ?? 0) blocks")
        return fullEntry.blocks ?? []
    }

    /// Get analyzed blocks as AnalyzedBlock structs for change detection
    static func getAnalyzedBlocksById(_ id: String) async throws -> [AnalyzedBlock] {
        let dbBlocks = try await getBlocksById(id)
        return dbBlocks.compactMap { $0.toAnalyzedBlock() }
    }

    static func insert(date: String, content: String) async throws -> Row {
        // This overload requires userId - use insert(date:content:userId:) instead
        throw NSError(domain: "DiaryAPI", code: -3, userInfo: [NSLocalizedDescriptionKey: "Use insert(date:content:userId:) overload to insert."])
    }

    static func insert(date: String, content: String, userId: String) async throws -> Row {
        let base = Configuration.apiURL
        // Backend upserts automatically on (user_id, date) - user_id comes from JWT token
        let urlString = "\(base)/api/diary/entries"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let payload: [String: Any] = [
            "date": date,
            "content": content
            // user_id comes from JWT token automatically
            // images can be added later if needed
        ]
        let body = try JSONSerialization.data(withJSONObject: payload) // Single object, not array
        let request = try makeRequest(url: url, method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            print("❌ Insert failed HTTP=\(status) body=\(bodyText)")
            throw NSError(domain: "DiaryAPI", code: status, userInfo: [NSLocalizedDescriptionKey: "Insert failed (HTTP \(status)): \(bodyText)"])
        }
        // Backend returns single object, not array
        let decoder = JSONDecoder()
        return try decoder.decode(Row.self, from: data)
    }

    static func updateContent(id: String, content: String) async throws -> Row {
        let base = Configuration.apiURL
        let urlString = "\(base)/api/diary/entries/\(id)"
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
        // Backend returns single object, not array
        let decoder = JSONDecoder()
        return try decoder.decode(Row.self, from: data)
    }

    static func upsertContent(date: String, userId: String, content: String) async throws -> Row {
        if let existing = try await getByDate(date) {
            return try await updateContent(id: existing.id, content: content)
        } else {
            return try await insert(date: date, content: content, userId: userId)
        }
    }

    static func analyze(entryId: String, blocksPayload: [[String: Any]]) async throws -> AnalyzeResponse {
        let base = Configuration.apiURL
        let urlString = "\(base)/api/ai/analyze"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let body = try JSONSerialization.data(withJSONObject: [
            "entryId": entryId,
            "blocks": blocksPayload
        ])
        let request = try makeRequest(url: url, method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200..<300).contains(http.statusCode) {
            // Try to decode structured error for debugging
            struct ErrorResponse: Codable {
                let error: String
                let message: String?
            }
            if let apiErr = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                print("❌ Analyze HTTP \(http.statusCode): error=\(apiErr.error) message=\(apiErr.message ?? "-")")
                throw NSError(domain: "DiaryAPI", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: apiErr.message ?? apiErr.error
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
    /// Note: Backend doesn't support incremental flag yet, so we'll merge client-side
    static func analyzeIncremental(entryId: String, blocksPayload: [[String: Any]], existingBlocks: [AnalyzedBlock]) async throws -> AnalyzeResponse {
        // For now, just call regular analyze - backend will analyze all blocks
        // TODO: Add incremental support to backend if needed
        return try await analyze(entryId: entryId, blocksPayload: blocksPayload)
    }

    /// Clear all nutrition data for an empty diary entry
    static func clearEntryNutrition(entryId: String) async throws {
        let base = Configuration.apiURL
        let urlString = "\(base)/api/diary/entries/\(entryId)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let clearData: [String: Any] = [
            "blocks": [] as [Any], // Empty array, not string
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
        let base = Configuration.apiURL
        let urlString = "\(base)/api/diary/entries/\(entryId)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let request = try makeRequest(url: url, method: "DELETE")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeIntForgiving(forKey key: K) -> Int? {
        if let v = try? decode(Int.self, forKey: key) { return v }
        if let s = try? decode(String.self, forKey: key) {
            if let i = Int(s) { return i }
            if let d = Double(s) { return Int(d.rounded()) }
        }
        return nil
    }

    func decodeDoubleForgiving(forKey key: K) -> Double? {
        if let v = try? decode(Double.self, forKey: key) { return v }
        if let i = try? decode(Int.self, forKey: key) { return Double(i) }
        if let s = try? decode(String.self, forKey: key) {
            if let d = Double(s) { return d }
            if let i = Int(s) { return Double(i) }
        }
        return nil
    }
}
// MARK: - Mapping helpers
extension DiaryAPI.Row {
    func toDiaryEntry() -> DiaryEntry {
        let uuid = UUID(uuidString: id) ?? UUID()
        print("🐛 DEBUG: toDiaryEntry - db_id=\(id), db_date=\(date), local_id=\(uuid.uuidString)")
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


