import SwiftUI
import MapboxMaps

@main
struct HouseFriendApp: App {
    init() {
        // Load Mapbox access token from bundled file
        if let path = Bundle.main.path(forResource: ".mapbox_token", ofType: nil),
           let token = try? String(contentsOfFile: path).trimmingCharacters(in: .whitespacesAndNewlines) {
            MapboxOptions.accessToken = token
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
