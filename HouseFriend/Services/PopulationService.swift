import Foundation
import MapKit

struct PopulationInfo {
    let density: Int       // people per sq mile
    let totalPop: Int      // city/zip estimate
    let medianAge: Double
    let medianIncome: Int
    let cityName: String
}

class PopulationService: ObservableObject {
    @Published var info: PopulationInfo?

    func fetch(lat: Double, lon: Double) {
        // Reverse geocode to get city, then look up known Bay Area city data
        let location = CLLocation(latitude: lat, longitude: lon)
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let city = placemarks?.first?.locality ?? ""
            DispatchQueue.main.async {
                self?.info = Self.dataForCity(city, lat: lat, lon: lon)
            }
        }
    }

    /// Bay Area city population data (from 2020 Census + ACS estimates)
    static func dataForCity(_ city: String, lat: Double, lon: Double) -> PopulationInfo {
        let cityLower = city.lowercased()

        if cityLower.contains("milpitas") {
            return PopulationInfo(density: 5800, totalPop: 83_366, medianAge: 38.2, medianIncome: 121_000, cityName: "Milpitas")
        } else if cityLower.contains("san jose") || cityLower.contains("san josé") {
            return PopulationInfo(density: 5820, totalPop: 1_013_240, medianAge: 36.5, medianIncome: 104_675, cityName: "San Jose")
        } else if cityLower.contains("sunnyvale") {
            return PopulationInfo(density: 6720, totalPop: 155_805, medianAge: 35.8, medianIncome: 142_000, cityName: "Sunnyvale")
        } else if cityLower.contains("santa clara") {
            return PopulationInfo(density: 6100, totalPop: 127_647, medianAge: 35.1, medianIncome: 128_000, cityName: "Santa Clara")
        } else if cityLower.contains("cupertino") {
            return PopulationInfo(density: 4200, totalPop: 59_623, medianAge: 40.2, medianIncome: 175_000, cityName: "Cupertino")
        } else if cityLower.contains("fremont") {
            return PopulationInfo(density: 2900, totalPop: 230_504, medianAge: 37.8, medianIncome: 131_000, cityName: "Fremont")
        } else if cityLower.contains("mountain view") {
            return PopulationInfo(density: 7100, totalPop: 82_376, medianAge: 34.6, medianIncome: 148_000, cityName: "Mountain View")
        } else if cityLower.contains("campbell") {
            return PopulationInfo(density: 7800, totalPop: 42_835, medianAge: 37.3, medianIncome: 118_000, cityName: "Campbell")
        } else if cityLower.contains("los gatos") {
            return PopulationInfo(density: 3600, totalPop: 33_698, medianAge: 44.1, medianIncome: 185_000, cityName: "Los Gatos")
        } else {
            // Estimate from coordinates
            let density = 5000 + Int((lat - 37.3) * 2000) + Int((lon + 122.0) * 1500)
            return PopulationInfo(density: max(1000, min(12000, density)), totalPop: 80_000, medianAge: 37.0, medianIncome: 120_000, cityName: city.isEmpty ? "Bay Area" : city)
        }
    }
}
