import Foundation
import Supabase

let supabase = SupabaseClient(
  supabaseURL: URL(string: "http://192.168.1.252:54321")!,
  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZXYiLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
)

struct Configuration {
    static let supabaseURL = "http://192.168.1.252:54321" // Your Supabase URL
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZXYiLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
    static let appleClientId = "stua.calcalcal" // Your actual bundle identifier
}