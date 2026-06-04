import Foundation

// Types exist in separate files - they should be available automatically if in same target

struct DiaryAPI {
    struct AnalyzeResponse: Codable { let success: Bool; let updatedBlocksCount: Int? }
    struct AnalyzeError: Codable { let error: String; let code: String?; let ai_step: String? }
    
    struct AnalyzeBlockResponse: Codable {
        let blockId: String
        let entryId: String
        let description: String?
        let calories: Int?
        let protein: Double?
        let fat: Double?
        let carbs: Double?
        let fiber: Double?
        let sugar: Double?
        let sodium: Double?
        let weight: Double?
        let metric_description: String?
        let confidence: Double?
        let totals: EntryTotals?
        let streaks: StreaksData?
    }
    
    struct EntryTotals: Codable {
        let total_calories: Int
        let total_protein: Double
        let total_fat: Double
        let total_carbs: Double
        let total_fiber: Double
        let total_sugar: Double
        let total_sodium: Double
    }
    
    struct Totals: Codable {
        let total_calories: Int
        let total_protein: Double
        let total_fat: Double
        let total_carbs: Double
        let total_fiber: Double
        let total_sugar: Double
        let total_sodium: Double
    }
    struct Row: Codable {
        let id: String
        let user_id: String
        let date: String
        let content: String?
        let blocks: [DBBlock]?
        let images: [String]?
        let total_calories: Int?
        let total_protein: Double?
        let total_fat: Double?
        let total_carbs: Double?
        let ai_analysis_status: String?
        let updated_at: String?

        enum CodingKeys: String, CodingKey {
            case id, user_id, date, content, blocks, images, total_calories, total_protein, total_fat, total_carbs, ai_analysis_status, updated_at
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(String.self, forKey: .id)
            self.user_id = try c.decode(String.self, forKey: .user_id)
            self.date = try c.decode(String.self, forKey: .date)
            self.content = try? c.decode(String.self, forKey: .content)
            self.blocks = try? c.decode([DBBlock].self, forKey: .blocks)
            self.images = try? c.decode([String].self, forKey: .images)
            self.total_calories = c.decodeIntForgiving(forKey: .total_calories)
            // Handle PostgreSQL numeric types that may come as strings
            self.total_protein = c.decodeDoubleForgiving(forKey: .total_protein)
            self.total_fat = c.decodeDoubleForgiving(forKey: .total_fat)
            self.total_carbs = c.decodeDoubleForgiving(forKey: .total_carbs)
            self.ai_analysis_status = try? c.decode(String.self, forKey: .ai_analysis_status)
            self.updated_at = try? c.decode(String.self, forKey: .updated_at)
        }
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
        let weight: Double?
        let metric_description: String?
        let confidence: Double?

        enum CodingKeys: String, CodingKey {
            case id, position, content, calories, protein, fat, carbs, fiber, sugar, sodium, weight, metric_description, confidence
        }

        init(id: String?, position: Int?, content: String?, calories: Int?, protein: Double?, fat: Double?, carbs: Double?, fiber: Double?, sugar: Double?, sodium: Double?, weight: Double?, metric_description: String?, confidence: Double?) {
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
            self.weight = weight
            self.metric_description = metric_description
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
            self.weight = c.decodeDoubleForgiving(forKey: .weight)
            self.metric_description = try? c.decode(String.self, forKey: .metric_description)
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
            try c.encodeIfPresent(weight, forKey: .weight)
            try c.encodeIfPresent(metric_description, forKey: .metric_description)
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
                weight: weight,
                metricDescription: metric_description,
                confidence: confidence,
                aiAnalysis: nil // We'll fetch this separately if needed
            )
        }

        func toBlock() -> Block? {
            guard let content = content else { return nil }
            var block = Block(
                id: id.flatMap(UUID.init(uuidString:)) ?? UUID(),
                type: .text(content),
                calorieData: calories.map(String.init),
                nutrition: NutritionData(
                    calories: calories,
                    protein: protein,
                    fat: fat,
                    carbs: carbs,
                    fiber: fiber,
                    sugar: sugar,
                    sodium: sodium,
                    weight: weight,
                    metric_description: metric_description,
                    confidence: confidence,
                    userModified: nil
                )
            )
            block.stableId = id.flatMap(UUID.init(uuidString:))
            return block
        }
    }
    private struct BlocksRow: Codable { let blocks: [DBBlock]? }

    /// Per-method timeouts. URLSession default is 60s, which is far too long for
    /// interactive read paths — the UI sits frozen on bad cellular. Reads now
    /// time out after 20s, writes after 45s (writes often trigger AI analysis on
    /// the backend, which can legitimately take 30s+).
    private static let readTimeout: TimeInterval = 20
    private static let writeTimeout: TimeInterval = 45

    private static func makeRequest(url: URL, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let isWrite = (method == "POST" || method == "PATCH" || method == "PUT" || method == "DELETE")
        request.timeoutInterval = isWrite ? writeTimeout : readTimeout
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
        let entry = try await getById(id)
        let blocks = entry?.blocks ?? []
        dlog("🐛 DEBUG: getBlocksById(\(id)) returning \(blocks.count) blocks")
        return blocks
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

    static func insert(date: String, content: String, userId: String, blocks: [[String: Any]]? = nil) async throws -> Row {
        let base = Configuration.apiURL
        // Backend upserts automatically on (user_id, date) - user_id comes from JWT token
        let urlString = "\(base)/api/diary/entries"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var payload: [String: Any] = [
            "date": date,
            "content": content
            // user_id comes from JWT token automatically
            // images can be added later if needed
        ]
        if let blocks = blocks {
            payload["blocks"] = blocks
        }
        let body = try JSONSerialization.data(withJSONObject: payload) // Single object, not array
        let request = try makeRequest(url: url, method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            dlog("❌ Insert failed HTTP=\(status) body=\(bodyText)")
            throw NSError(domain: "DiaryAPI", code: status, userInfo: [NSLocalizedDescriptionKey: "Insert failed (HTTP \(status)): \(bodyText)"])
        }
        // Backend returns single object, not array
        let decoder = JSONDecoder()
        return try decoder.decode(Row.self, from: data)
    }

    static func updateContent(id: String, content: String, blocks: [[String: Any]]? = nil) async throws -> Row {
        let base = Configuration.apiURL
        let urlString = "\(base)/api/diary/entries/\(id)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var payload: [String: Any] = ["content": content]
        if let blocks = blocks {
            payload["blocks"] = blocks
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = try makeRequest(url: url, method: "PATCH", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            dlog("❌ Update failed HTTP=\(status) body=\(bodyText)")
            throw NSError(domain: "DiaryAPI", code: status, userInfo: [NSLocalizedDescriptionKey: "Update failed (HTTP \(status)): \(bodyText)"])
        }
        // Backend returns single object, not array
        let decoder = JSONDecoder()
        return try decoder.decode(Row.self, from: data)
    }

    static func upsertContent(date: String, userId: String, content: String, blocks: [[String: Any]]? = nil) async throws -> Row {
        return try await insert(date: date, content: content, userId: userId, blocks: blocks)
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
                dlog("❌ Analyze HTTP \(http.statusCode): error=\(apiErr.error) message=\(apiErr.message ?? "-")")
                throw NSError(domain: "DiaryAPI", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: apiErr.message ?? apiErr.error
                ])
            } else if let body = String(data: data, encoding: .utf8) {
                dlog("❌ Analyze HTTP \(http.statusCode) raw body: \(body)")
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

    /// Unified analysis endpoint for single block - can handle text, image, or both
    static func analyzeBlock(entryId: String, blockId: String, content: [String: Any], userModified: Bool = false) async throws -> AnalyzeBlockResponse {
        let base = Configuration.apiURL
        let urlString = "\(base)/api/ai/analyze-block"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var payload: [String: Any] = [
            "entryId": entryId,
            "blockId": blockId,
            "content": content,
            "userModified": userModified
        ]
        
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = try makeRequest(url: url, method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200..<300).contains(http.statusCode) {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            dlog("❌ analyzeBlock failed HTTP=\(http.statusCode) body=\(bodyText)")
            throw NSError(domain: "DiaryAPI", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "analyzeBlock failed (HTTP \(http.statusCode)): \(bodyText)"
            ])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(AnalyzeBlockResponse.self, from: data)
    }

    /// Fetch current user streaks data
    static func getStreaks() async throws -> StreaksData {
        let base = Configuration.apiURL
        let urlString = "\(base)/api/streaks"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        // This is a GET request, authenticated by session token in makeRequest
        let request = try makeRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200..<300).contains(http.statusCode) {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            dlog("❌ getStreaks failed HTTP=\(http.statusCode) body=\(bodyText)")
            throw NSError(domain: "DiaryAPI", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "getStreaks failed (HTTP \(http.statusCode)): \(bodyText)"
            ])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(StreaksData.self, from: data)
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
        dlog("🐛 DEBUG: toDiaryEntry - db_id=\(id), db_date=\(date), local_id=\(uuid.uuidString)")
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60

        // Robustly parse server `date` which may arrive as "YYYY-MM-DD" or ISO8601.
        // A diary date is a user-local calendar day, not a UTC instant; anchoring a
        // plain day string at UTC midnight shifts it into the previous day in
        // negative timezones when the timeline re-buckets entries.
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let parsedDate: Date? = {
            // Preferred: strict yyyy-MM-dd
            if date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
                return LocalDayMath.startUTC(forDayKey: date, offsetMinutes: offsetMinutes)
            }
            // Fallback: ISO8601 full timestamp
            if let d = isoFormatter.date(from: date) {
                // Normalize to UTC midnight of that local calendar day representation
                // by formatting back to yyyy-MM-dd and re-parsing with the strict formatter.
                let dayString = dateFormatter.string(from: d)
                return LocalDayMath.startUTC(forDayKey: dayString, offsetMinutes: offsetMinutes)
            }
            // Fallback: take first 10 chars if present and try again (e.g., "YYYY-MM-DDTHH:mm:ssZ")
            if date.count >= 10 {
                let prefix = String(date.prefix(10))
                if prefix.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
                    return LocalDayMath.startUTC(forDayKey: prefix, offsetMinutes: offsetMinutes)
                }
            }
            return nil
        }()
        let dateValue = parsedDate ?? Date.distantPast // avoid collapsing to "today" when parse fails
        // Prefer local cached blocks for fast, lossless hydration across app restarts
        let cachedBlocks = BlocksCache.shared.load(entryId: uuid)
        
        if let cached = cachedBlocks {
            DataFlowLogger.shared.entryMappingUsingCache(entryId: uuid, blockCount: cached.count)
        } else {
            DataFlowLogger.shared.entryMappingUsingBackendContent(
                entryId: uuid, 
                contentPreview: String((content ?? "").prefix(50))
            )
        }
        
        let backendBlocks = blocks?.compactMap { $0.toBlock() }
        let nonEmptyBackendBlocks = (backendBlocks?.isEmpty == false) ? backendBlocks : nil
        let hydratedBlocks = cachedBlocks ?? nonEmptyBackendBlocks ?? (content ?? "").toTextBlocks()
        let blocks = hydratedBlocks.withStableIdsAndChangeTracking()
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
