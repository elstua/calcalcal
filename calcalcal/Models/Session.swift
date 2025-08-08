import Foundation

struct Session: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct AuthResponse: Codable {
    let success: Bool
    let user: User?
    let session: Session?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case user
        case session
        case error
    }
} 