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
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let session = session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func updateSession(_ newSession: Session) {
        session = newSession
    }
    
    func clearSession() {
        session = nil
    }
}

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
} 