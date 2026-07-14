import SwiftUI

@main
struct AMapsMain: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            MapScreen()
                .environmentObject(model)
                .preferredColorScheme(.light)
        }
    }
}
