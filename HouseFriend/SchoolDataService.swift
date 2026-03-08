import Foundation
import MapKit

struct SchoolBoundary: Identifiable {
    let id = UUID()
    let name: String
    let schoolLevel: String  // "Elementary", "Middle", "High"
    let polygon: MKPolygon
}

struct SchoolInfo: Identifiable {
    let id = UUID()
    let name: String
    let level: String
    let rating: Int?  // 1-10 from GreatSchools
    let coordinate: CLLocationCoordinate2D
}

class SchoolDataService: ObservableObject {
    @Published var boundaries: [SchoolBoundary] = []
    @Published var schools: [SchoolInfo] = []
    @Published var isLoading = false

    // SFUSD Open Data
    private let sfusdUrl = "https://data.sfgov.org/resource/e6tr-sxwg.json"

    func fetchSchools() {
        isLoading = true
        guard let url = URL(string: sfusdUrl) else { isLoading = false; return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { DispatchQueue.main.async { self?.isLoading = false } }
            guard let data = data, error == nil else {
                print("School data error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            print("School data fetched: \(data.count) bytes")
            let parsed = GeoJSONParser.parseSFUSD(data: data)
            DispatchQueue.main.async {
                self?.boundaries = parsed
            }
        }.resume()
    }
}
