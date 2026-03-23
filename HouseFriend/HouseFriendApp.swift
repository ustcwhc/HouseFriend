import SwiftUI
import MapboxMaps

@main
struct HouseFriendApp: App {
    init() {
        // Load Mapbox access token from bundled file
        if let url = Bundle.main.url(forResource: "MapboxToken", withExtension: "txt"),
           let token = try? String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines) {
            MapboxOptions.accessToken = token
        } else {
            // Fallback: hardcoded token (same as MapboxToken.txt)
            MapboxOptions.accessToken = "pk.eyJ1IjoidXN0Y3doYyIsImEiOiJjbW4yb2Jva3ExMW11MnFweWtqcmdhYjgyIn0.TYCu3HWx-rxUwCgIHZnGDQ"
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
