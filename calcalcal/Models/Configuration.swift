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
        return "http://127.0.0.1:54321"
        #else
        return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "https://YOUR_PROJECT_REF.supabase.co"
        #endif
    }()

    static let supabaseAnonKey: String = {
        #if DEBUG
        if let k = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String, !k.isEmpty {
            return k
        }
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
        #else
        return Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? "SET_ME"
        #endif
    }()
    static let appleClientId = "stua.calcalcal" // Your actual bundle identifier
}