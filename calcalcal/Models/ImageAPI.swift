import Foundation

struct ImageAPI {
    struct UploadResponse: Codable {
        let publicUrl: String
        let relativeUrl: String?
        let objectKey: String?
        let size: Int?
        let contentType: String?
    }

    struct AnalyzeImageResponse: Codable {
        struct Macros: Codable {
            let protein: Double?
            let fat: Double?
            let carbs: Double?
            let fiber: Double?
            let sugar: Double?
            let sodium: Double?
            let weight: Double?
            let metric_description: String?
        }
        let description: String
        let calories: Int?
        let macros: Macros?
        let confidence: Double?
    }

    private static func authorizedRequest(url: URL, method: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let session = try? KeychainManager.shared.loadTokens() {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            throw NSError(domain: "ImageAPI", code: -10, userInfo: [NSLocalizedDescriptionKey: "Missing session; please sign in."])
        }
        return request
    }

    static func uploadJPEG(data: Data, filename: String = "image.jpg", contentType: String = "image/jpeg") async throws -> UploadResponse {
        let base = Configuration.apiURL
        guard let url = URL(string: "\(base)/api/storage/upload") else { throw URLError(.badURL) }

        var request = try authorizedRequest(url: url, method: "POST")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let disposition = "form-data; name=\"file\"; filename=\"\(filename)\""
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: \(disposition)\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        #if DEBUG
        print("📤 Upload start -> \(filename) (\(data.count) bytes)")
        #endif

        let (respData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200..<300).contains(http.statusCode) {
            let bodyText = String(data: respData, encoding: .utf8) ?? "<no body>"
            print("❌ Upload failed HTTP=\(http.statusCode) body=\(bodyText)")
            throw NSError(domain: "ImageAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Upload failed: HTTP \(http.statusCode)"])
        }
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UploadResponse.self, from: respData)
        #if DEBUG
        print("✅ Upload success publicUrl=\(decoded.publicUrl)")
        print("✅ Upload publicUrl length=\(decoded.publicUrl.count), last10='\(String(decoded.publicUrl.suffix(10)))'")
        if decoded.publicUrl.hasSuffix(".") {
            print("⚠️ WARNING: Upload response publicUrl ends with a trailing dot!")
        }
        #endif
        return decoded
    }

    /// Ensure we send an absolute URL to backend (required by server to fetch or inline image)
    private static func normalizeImageURL(_ imageUrl: String) -> String {
        var trimmed = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip any trailing dots that might have been incorrectly added after file extension
        // (defensive fix for URL corruption bug - e.g., ".jpg." -> ".jpg")
        let validExtensions = [".jpg.", ".jpeg.", ".png.", ".webp.", ".gif."]
        for ext in validExtensions {
            if trimmed.lowercased().hasSuffix(ext) {
                #if DEBUG
                print("⚠️ normalizeImageURL: stripping trailing dot from URL ending with '\(ext)': \(trimmed)")
                #endif
                trimmed.removeLast() // Remove trailing dot
                break
            }
        }

        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }
        // Prepend base API URL for relative paths like "uploads/..." or "/uploads/..."
        var base = Configuration.apiURL
        if base.hasSuffix("/") { base.removeLast() }
        if trimmed.hasPrefix("/") {
            return "\(base)\(trimmed)"
        } else {
            return "\(base)/\(trimmed)"
        }
    }

    static func analyzeImage(imageUrl: String, entryId: String, blockId: String) async throws -> AnalyzeImageResponse {
        // For now, use the legacy analyze-image endpoint
        // The unified endpoint integration will be done separately
        return try await analyzeImageLegacy(imageUrl: imageUrl, entryId: entryId, blockId: blockId)
    }
    
    /// Legacy method for backward compatibility - requires entryId and blockId
    static func analyzeImageLegacy(imageUrl: String, entryId: String? = nil, blockId: String? = nil) async throws -> AnalyzeImageResponse {
        let base = Configuration.apiURL
        guard let url = URL(string: "\(base)/api/ai/analyze-image") else { throw URLError(.badURL) }
        var request = try authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let absoluteImageUrl = normalizeImageURL(imageUrl)
        var payload: [String: Any] = ["imageUrl": absoluteImageUrl]
        if let entryId = entryId { payload["entryId"] = entryId }
        if let blockId = blockId { payload["blockId"] = blockId }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        #if DEBUG
        print("🤖 Legacy Analyze start imageUrl=\(absoluteImageUrl)")
        print("🤖 Legacy Analyze input imageUrl=\(imageUrl), length=\(imageUrl.count), last10='\(String(imageUrl.suffix(10)))'")
        print("🤖 Legacy Analyze normalized imageUrl=\(absoluteImageUrl), length=\(absoluteImageUrl.count), last10='\(String(absoluteImageUrl.suffix(10)))'")
        if absoluteImageUrl.hasSuffix(".") {
            print("⚠️ WARNING: imageUrl ends with a trailing dot!")
        }
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200..<300).contains(http.statusCode) {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            print("❌ Legacy Analyze failed HTTP=\(http.statusCode) body=\(bodyText)")
            throw NSError(domain: "ImageAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Legacy Analyze failed: HTTP \(http.statusCode)"])
        }
        let decoder = JSONDecoder()
        let result = try decoder.decode(AnalyzeImageResponse.self, from: data)
        #if DEBUG
        print("✅ Legacy Analyze success desc='\(result.description)' calories=\(String(describing: result.calories))")
        #endif
        return result
    }
}