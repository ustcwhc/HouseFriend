import Foundation
import MapKit

struct FireHazardArea: Identifiable {
    let id = UUID()
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    let severity: String  // "Low", "Moderate", "High", "Very High", "Extreme"
}

class FireDataService: ObservableObject {
    @Published var hazardAreas: [FireHazardArea] = []
    @Published var isLoading = false

    // CAL FIRE State Responsibility Area (SRA) Fire Hazard Severity Zones
    private let urlString = "https://gis.data.cnra.ca.gov/api/download/v1/items/e50b7577426c4367a518b80b38e9b5d8/geojson?layers=0"

    func fetchFireData() {
        isLoading = true
        guard let url = URL(string: urlString) else { isLoading = false; return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { DispatchQueue.main.async { self?.isLoading = false } }
            guard let data = data, error == nil else {
                print("Fire data fetch error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            print("Fire data fetched: \(data.count) bytes")
            // GeoJSON parsing would happen here
            // For now we log success; full parsing via GeoJSONParser
        }.resume()
    }
}
