import Foundation
import MapKit
import Combine

// Wrapper to make MKLocalSearchCompletion usable in ForEach
struct SearchCompletion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let original: MKLocalSearchCompletion
}

class SearchCompleterService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var completions: [SearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        // Filter to Bay Area
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.650, longitude: -122.100),
            span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
        )
        // Include both addresses and POIs
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func search(_ text: String) {
        completer.queryFragment = text
    }

    func clear() {
        completer.queryFragment = ""
        completions = []
    }

    // MARK: - MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results.prefix(6).map {
            SearchCompletion(title: $0.title, subtitle: $0.subtitle, original: $0)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
    }
}
