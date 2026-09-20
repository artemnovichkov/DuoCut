import SwiftUI

@main
struct DuoCutApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
