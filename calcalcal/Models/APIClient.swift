import Foundation

/// Minimal session-token holder and a single async API used by the editor.
///
/// The Combine-based generic `request<T>()` helper that used to live here was
/// dead code (only `updateCaloriePopup` used it, and `updateCaloriePopup` had
/// only one caller). PR #3 of the perf triage removed it; everything else in
/// the app already builds URLSession requests directly via async/await.
final class APIClient {
    static let shared = APIClient()

    private let baseURL = Configuration.apiURL
    private var session: Session?

    private init() {
        loadSession()
    }

    private func loadSession() {
        session = try? KeychainManager.shared.loadTokens()
    }

    func updateSession(_ newSession: Session) {
        session = newSession
    }

    func clearSession() {
        session = nil
    }

    // MARK: - Calorie Popup Update

    func updateCaloriePopup(
        entryId: String,
        blockId: String,
        text: String,
        calories: Int? = nil,
        weight: Double? = nil
    ) async throws -> CaloriePopupUpdateResponse {
        var userProvidedData: [String: Any] = [:]
        if let calories = calories { userProvidedData["calories"] = calories }
        if let weight = weight { userProvidedData["weight"] = weight }

        let content: [String: Any] = [
            "text": text,
            "userProvidedData": userProvidedData
        ]
        let body: [String: Any] = [
            "entryId": entryId,
            "blockId": blockId,
            "content": content,
            "userModified": true
        ]

        let endpoint = "/api/ai/analyze-block"
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45  // matches DiaryAPI write timeout; AI analysis can be slow

        if let session = session ?? (try? KeychainManager.shared.loadTokens()) {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        do {
            return try JSONDecoder().decode(CaloriePopupUpdateResponse.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
}

// MARK: - Response Models

struct CaloriePopupUpdateResponse: Codable {
    let blockId: String
    let calories: Int
    let protein: Double
    let fat: Double
    let carbs: Double
    let fiber: Double
    let sugar: Double
    let sodium: Double
    let weight: Double?
    let metric_description: String?
    let confidence: Double
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out. Please try again."
        }
    }
}
