import SwiftUI

/// The menu: pick a mode, see what the fold is for.
struct RootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("DuoCut")
                .font(.system(size: 56, weight: .black, design: .rounded))
            Text("Line the shape up with the fold.\nSnap the hinge to cut it.")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.paper)
    }
}

/// Flat, calm, high contrast: paper, ink, and one accent.
enum Palette {
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let ink = Color(red: 0.13, green: 0.13, blue: 0.15)
    static let blade = Color(red: 0.91, green: 0.42, blue: 0.36)
}

#Preview {
    RootView()
}
