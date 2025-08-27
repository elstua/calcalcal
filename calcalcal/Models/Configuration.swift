import Foundation
import Supabase

let supabase = SupabaseClient(
  supabaseURL: URL(string: Configuration.supabaseURL)!,
  supabaseKey: Configuration.supabaseAnonKey
)

struct Configuration {
    static let supabaseURL: String = {
        #if DEBUG
        if let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String, !s.isEmpty {
            return s
        }
        return "https://lospxwasburnwmlqducq.supabase.co"
        #else
        return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "https://YOUR_PROJECT_REF.supabase.co"
        #endif
    }()

    static let supabaseAnonKey: String = {
        #if DEBUG
        if let k = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String, !k.isEmpty {
            return k
        }
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxvc3B4d2FzYnVybndtbHFkdWNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1NDQyNjEsImV4cCI6MjA2OTEyMDI2MX0.1Nyeo2k0uctrIUqNpm2w22fYzgDSBnXxkzPlzQgFcKg"
        #else
        return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? "SET_ME"
        #endif
    }()
    static let appleClientId = "stua.calcalcal" // Your actual bundle identifier
}