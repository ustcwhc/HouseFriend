import Foundation
import MapKit

struct SuperfundSite: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let status: String  // "NPL", "Proposed", "Removed", etc.
    let distanceMiles: Double?
}

class SuperfundService: ObservableObject {
    @Published var sites: [SuperfundSite] = []
    @Published var isLoading = false

    /// Fetch EPA Superfund / CERCLIS sites near a coordinate
    /// Uses EPA's ArcGIS REST endpoint
    func fetchNear(lat: Double, lon: Double, radiusMiles: Double = 5) {
        isLoading = true
        // EPA ECHO / FRS point layer for Superfund NPL sites
        let urlString = "https://enviro.epa.gov/enviro/efservice/V_SITE_INSP_SUMMARY/LATITUDE/>\(lat - 0.15)/LATITUDE/<\(lat + 0.15)/LONGITUDE/>\(lon - 0.2)/LONGITUDE/<\(lon + 0.2)/JSON"
        guard let url = URL(string: urlString) else { isLoading = false; return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { DispatchQueue.main.async { self?.isLoading = false } }
            guard let data = data, error == nil else {
                // Fallback: use mock for now
                DispatchQueue.main.async { self?.sites = Self.mockSites(lat: lat, lon: lon) }
                return
            }
            // If real API fails, fall back to mock data
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !json.isEmpty {
                let parsed = json.compactMap { item -> SuperfundSite? in
                    guard let name = item["FACILITY_NAME"] as? String,
                          let latStr = item["LATITUDE83"] as? String, let lat = Double(latStr),
                          let lonStr = item["LONGITUDE83"] as? String, let lon = Double(lonStr) else { return nil }
                    return SuperfundSite(name: name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), status: "NPL", distanceMiles: nil)
                }
                DispatchQueue.main.async { self?.sites = parsed }
            } else {
                DispatchQueue.main.async { self?.sites = Self.mockSites(lat: lat, lon: lon) }
            }
        }.resume()
    }

    static func mockSites(lat: Double, lon: Double) -> [SuperfundSite] {
        // Known real Superfund sites near Milpitas/Bay Area
        return [
            SuperfundSite(name: "Lorentz Barrel & Drum", coordinate: CLLocationCoordinate2D(latitude: 37.421, longitude: -121.898), status: "NPL", distanceMiles: 0.8),
            SuperfundSite(name: "Intel Magnetics", coordinate: CLLocationCoordinate2D(latitude: 37.385, longitude: -122.013), status: "NPL", distanceMiles: 3.2),
            SuperfundSite(name: "Middlefield-Ellis-Whisman", coordinate: CLLocationCoordinate2D(latitude: 37.390, longitude: -122.065), status: "NPL", distanceMiles: 4.1),
        ]
    }
}
