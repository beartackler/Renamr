import SwiftUI

/// Renamr's look: a violet "magic" brand that matches the app icon. Kept in one
/// place so the whole app feels cohesive.
enum Brand {
    static let start = Color(red: 0.40, green: 0.34, blue: 0.97)   // indigo
    static let end   = Color(red: 0.73, green: 0.30, blue: 0.96)   // violet
    static let accent = Color(red: 0.53, green: 0.34, blue: 0.97)

    static let gradient = LinearGradient(
        colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
