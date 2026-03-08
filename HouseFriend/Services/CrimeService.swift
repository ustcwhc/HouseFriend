import Foundation
import MapKit

struct CrimeIncident: Identifiable {
    let id = UUID()
    let category: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let date: Date
}

class CrimeService: ObservableObject {
    @Published var incidents: [CrimeIncident] = []
    @Published var isLoading = false
    @Published var crimeScore: Int = 0  // 0-100, higher = safer

    // San Jose Open Data - Crime incidents
    private let sjCrimeUrl = "https://data.sanjoseca.gov/resource/7d7f-m4ck.json?$limit=200&$order=date_time%20DESC"

    func fetchNear(lat: Double, lon: Double) {
        isLoading = true
        // Use SJ open data API
        guard let url = URL(string: sjCrimeUrl) else { isLoading = false; return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { DispatchQueue.main.async { self?.isLoading = false } }
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                DispatchQueue.main.async { self?.incidents = Self.mockIncidents(lat: lat, lon: lon) }
                return
            }
            let incidents = json.compactMap { item -> CrimeIncident? in
                guard let category = item["offense_category"] as? String,
                      let latStr = item["latitude"] as? String, let iLat = Double(latStr),
                      let lonStr = item["longitude"] as? String, let iLon = Double(lonStr) else { return nil }
                return CrimeIncident(
                    category: category,
                    description: item["offense_description"] as? String ?? category,
                    coordinate: CLLocationCoordinate2D(latitude: iLat, longitude: iLon),
                    date: Date()
                )
            }
            let score = max(0, 100 - incidents.count * 2)
            DispatchQueue.main.async {
                self?.incidents = incidents
                self?.crimeScore = score
            }
        }.resume()
    }

    static func mockIncidents(lat: Double, lon: Double) -> [CrimeIncident] {
        // Spread some mock incidents around the location
        let types = ["Theft", "Vandalism", "Burglary", "Auto Theft", "Assault"]
        return (0..<5).map { i in
            CrimeIncident(
                category: types[i % types.count],
                description: "\(types[i % types.count]) incident",
                coordinate: CLLocationCoordinate2D(
                    latitude: lat + Double.random(in: -0.01...0.01),
                    longitude: lon + Double.random(in: -0.01...0.01)
                ),
                date: Date().addingTimeInterval(-Double(i) * 86400)
            )
        }
    }
}
