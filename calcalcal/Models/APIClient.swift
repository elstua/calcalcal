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
}

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
} 