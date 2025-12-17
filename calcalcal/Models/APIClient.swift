import Foundation
import Combine

class APIClient {
    static let shared = APIClient()

    private let baseURL = Configuration.apiURL
    private var session: Session?

    private init() {
        loadSession()
    }

    private func loadSession() {
        session = try? KeychainManager.shared.loadTokens()
    }

    func request<T: Codable>(_ endpoint: String, method: String = "GET", body: [String: Any]? = nil) -> AnyPublisher<T, Error> {
        let fullURLString = "\(baseURL)\(endpoint)"
        guard let url = URL(string: fullURLString) else {
            #if DEBUG
            print("❌ APIClient: Invalid URL - \(fullURLString)")
            #endif
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }

        #if DEBUG
        print("🌐 APIClient: Requesting \(method) \(fullURLString)")
        #endif

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Set timeout for the request
        request.timeoutInterval = 60.0 // 60 seconds timeout

        if let session = session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { error -> APIError in
                #if DEBUG
                print("❌ APIClient: Network error - \(error.localizedDescription)")
                print("   Base URL: \(self.baseURL)")
                print("   Endpoint: \(endpoint)")
                #endif

                // Check if it's a timeout error
                if let urlError = error as? URLError,
                   urlError.code == .timedOut {
                    return APIError.timeout
                }

                return APIError.networkError(error)
            }
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error -> APIError in
                #if DEBUG
                print("❌ APIClient: Decoding error - \(error.localizedDescription)")
                #endif
                return APIError.decodingError
            }
            .eraseToAnyPublisher()
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
    ) -> AnyPublisher<CaloriePopupUpdateResponse, Error> {
        // Build user provided data for unified analysis
        var userProvidedData: [String: Any] = [:]
        
        if let calories = calories {
            userProvidedData["calories"] = calories
        }

        if let weight = weight {
            userProvidedData["weight"] = weight
        }
        
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

        return request("/api/ai/analyze-block", method: "POST", body: body)
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
