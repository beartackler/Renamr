import SwiftUI

/// Renamr's look: a fresh, friendly garden palette — leafy greens with a soft
/// blossom-pink accent. Kept in one place so the app feels cohesive and warm,
/// not default-SwiftUI.
enum Brand {
    static let leaf      = Color(red: 0.36, green: 0.78, blue: 0.49)   // bright leaf
    static let green     = Color(red: 0.22, green: 0.68, blue: 0.43)   // primary
    static let deep      = Color(red: 0.13, green: 0.52, blue: 0.36)   // emerald shade
    static let blossom   = Color(red: 1.00, green: 0.55, blue: 0.62)   // floral pink accent
    static let cream     = Color(red: 0.97, green: 0.98, blue: 0.96)

    static let gradient = LinearGradient(
        colors: [leaf, deep], startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let leafGradient = LinearGradient(
        colors: [leaf, green], startPoint: .top, endPoint: .bottom
    )
}
