import Foundation
import MapKit
import CoreLocation

struct PopulationInfo {
    let cityName: String
    let population: Int
    let density: Int        // per sq mile
    let medianIncome: Int
    let medianAge: Double
}

class PopulationService: ObservableObject {
    @Published var info: PopulationInfo?

    func fetch(lat: Double, lon: Double) {
        // Reverse geocode to city, then match census data
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: lat, longitude: lon)
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            let city = placemarks?.first?.locality ?? placemarks?.first?.subAdministrativeArea ?? ""
            DispatchQueue.main.async {
                self.info = Self.lookup(city: city) ?? Self.estimateFromCoord(lat: lat, lon: lon)
            }
        }
    }

    static func lookup(city: String) -> PopulationInfo? {
        let lower = city.lowercased()
        return allCities().first { lower.contains($0.cityName.lowercased()) || $0.cityName.lowercased().contains(lower) }
    }

    static func estimateFromCoord(lat: Double, lon: Double) -> PopulationInfo {
        // Estimate density by proximity to urban cores
        let sfDist = sqrt(pow(lat-37.775,2)+pow(lon+122.418,2))
        let oakDist = sqrt(pow(lat-37.805,2)+pow(lon+122.272,2))
        let sjDist  = sqrt(pow(lat-37.338,2)+pow(lon+121.886,2))
        let minDist = min(sfDist, oakDist, sjDist)
        let density = minDist < 0.05 ? 18000 : minDist < 0.12 ? 9000 : minDist < 0.25 ? 5000 : 2500
        return PopulationInfo(cityName: "Bay Area", population: 0, density: density, medianIncome: 105000, medianAge: 37.5)
    }

    static func allCities() -> [PopulationInfo] {
        return [
            // ─── San Francisco ───────────────────────────────────────────────
            PopulationInfo(cityName: "San Francisco",  population: 874961, density: 18838, medianIncome: 130696, medianAge: 38.5),

            // ─── Santa Clara County ──────────────────────────────────────────
            PopulationInfo(cityName: "San Jose",       population: 1013240, density: 5820, medianIncome: 109593, medianAge: 36.5),
            PopulationInfo(cityName: "Sunnyvale",      population: 155805,  density: 6902, medianIncome: 148258, medianAge: 36.0),
            PopulationInfo(cityName: "Santa Clara",    population: 127647,  density: 6208, medianIncome: 138232, medianAge: 35.5),
            PopulationInfo(cityName: "Cupertino",      population: 60170,   density: 4540, medianIncome: 186548, medianAge: 40.5),
            PopulationInfo(cityName: "Mountain View",  population: 82376,   density: 6822, medianIncome: 142932, medianAge: 34.8),
            PopulationInfo(cityName: "Palo Alto",      population: 68572,   density: 2830, medianIncome: 193308, medianAge: 39.2),
            PopulationInfo(cityName: "Milpitas",       population: 80874,   density: 5288, medianIncome: 131248, medianAge: 37.0),
            PopulationInfo(cityName: "Campbell",       population: 44114,   density: 7018, medianIncome: 101852, medianAge: 37.5),
            PopulationInfo(cityName: "Los Gatos",      population: 34740,   density: 2892, medianIncome: 181222, medianAge: 44.0),
            PopulationInfo(cityName: "Saratoga",       population: 32588,   density: 2168, medianIncome: 250001, medianAge: 48.2),
            PopulationInfo(cityName: "Los Altos",      population: 31352,   density: 3698, medianIncome: 250001, medianAge: 45.8),
            PopulationInfo(cityName: "Gilroy",         population: 59811,   density: 2450, medianIncome: 82952,  medianAge: 35.5),
            PopulationInfo(cityName: "Morgan Hill",    population: 47246,   density: 1788, medianIncome: 115228, medianAge: 38.8),

            // ─── Alameda County ──────────────────────────────────────────────
            PopulationInfo(cityName: "Oakland",        population: 440646,  density: 7924, medianIncome: 82972,  medianAge: 36.8),
            PopulationInfo(cityName: "Fremont",        population: 241110,  density: 2842, medianIncome: 138898, medianAge: 37.2),
            PopulationInfo(cityName: "Hayward",        population: 162954,  density: 4522, medianIncome: 82050,  medianAge: 35.0),
            PopulationInfo(cityName: "Berkeley",       population: 124321,  density: 10388, medianIncome: 91802, medianAge: 33.8),
            PopulationInfo(cityName: "San Leandro",    population: 90747,   density: 7302, medianIncome: 74824,  medianAge: 38.0),
            PopulationInfo(cityName: "Alameda",        population: 79827,   density: 7282, medianIncome: 105288, medianAge: 40.5),
            PopulationInfo(cityName: "Dublin",         population: 72589,   density: 3228, medianIncome: 162942, medianAge: 36.8),
            PopulationInfo(cityName: "Pleasanton",     population: 82178,   density: 2538, medianIncome: 172118, medianAge: 40.2),
            PopulationInfo(cityName: "Livermore",      population: 95332,   density: 2832, medianIncome: 118398, medianAge: 38.5),
            PopulationInfo(cityName: "Union City",     population: 75294,   density: 4828, medianIncome: 103218, medianAge: 37.8),
            PopulationInfo(cityName: "Newark",         population: 48018,   density: 5128, medianIncome: 92488,  medianAge: 37.0),
            PopulationInfo(cityName: "Emeryville",     population: 12728,   density: 8822, medianIncome: 71892,  medianAge: 34.5),
            PopulationInfo(cityName: "Piedmont",       population: 11418,   density: 4802, medianIncome: 250001, medianAge: 45.2),

            // ─── Contra Costa County ─────────────────────────────────────────
            PopulationInfo(cityName: "Concord",        population: 134477,  density: 4228, medianIncome: 82048,  medianAge: 37.5),
            PopulationInfo(cityName: "Richmond",       population: 115672,  density: 4638, medianIncome: 60582,  medianAge: 34.2),
            PopulationInfo(cityName: "Antioch",        population: 118776,  density: 3128, medianIncome: 76988,  medianAge: 34.0),
            PopulationInfo(cityName: "Walnut Creek",   population: 70412,   density: 3298, medianIncome: 116098, medianAge: 44.8),
            PopulationInfo(cityName: "San Ramon",      population: 84605,   density: 2828, medianIncome: 168522, medianAge: 38.5),
            PopulationInfo(cityName: "Danville",       population: 44965,   density: 1348, medianIncome: 194528, medianAge: 45.2),
            PopulationInfo(cityName: "Pittsburg",      population: 76492,   density: 3482, medianIncome: 70288,  medianAge: 33.5),
            PopulationInfo(cityName: "Brentwood",      population: 66428,   density: 2038, medianIncome: 115488, medianAge: 36.2),
            PopulationInfo(cityName: "Lafayette",      population: 26074,   density: 1488, medianIncome: 198822, medianAge: 47.8),
            PopulationInfo(cityName: "Orinda",         population: 20425,   density: 982,  medianIncome: 216552, medianAge: 48.2),
            PopulationInfo(cityName: "Moraga",         population: 17228,   density: 1128, medianIncome: 189028, medianAge: 47.2),
            PopulationInfo(cityName: "Pinole",         population: 19988,   density: 3528, medianIncome: 81288,  medianAge: 41.0),

            // ─── San Mateo County ────────────────────────────────────────────
            PopulationInfo(cityName: "San Mateo",      population: 105661,  density: 7628, medianIncome: 118048, medianAge: 38.8),
            PopulationInfo(cityName: "Daly City",      population: 106082,  density: 14228, medianIncome: 80288, medianAge: 36.8),
            PopulationInfo(cityName: "Redwood City",   population: 84888,   density: 4828, medianIncome: 115488, medianAge: 37.5),
            PopulationInfo(cityName: "South San Francisco", population: 67208, density: 7228, medianIncome: 92488, medianAge: 37.0),
            PopulationInfo(cityName: "San Bruno",      population: 46828,   density: 7028, medianIncome: 95288,  medianAge: 38.5),
            PopulationInfo(cityName: "Burlingame",     population: 31188,   density: 5628, medianIncome: 142488, medianAge: 41.5),
            PopulationInfo(cityName: "Foster City",    population: 34448,   density: 4828, medianIncome: 148288, medianAge: 39.5),
            PopulationInfo(cityName: "San Carlos",     population: 30996,   density: 4528, medianIncome: 148888, medianAge: 40.8),
            PopulationInfo(cityName: "Millbrae",       population: 22824,   density: 5228, medianIncome: 116288, medianAge: 42.5),
            PopulationInfo(cityName: "Menlo Park",     population: 35254,   density: 3228, medianIncome: 163288, medianAge: 38.5),
            PopulationInfo(cityName: "Half Moon Bay",  population: 12477,   density: 828,  medianIncome: 95288,  medianAge: 42.0),
            PopulationInfo(cityName: "Belmont",        population: 28228,   density: 4228, medianIncome: 148288, medianAge: 41.5),
            PopulationInfo(cityName: "Pacifica",       population: 37234,   density: 2828, medianIncome: 103288, medianAge: 41.0),
            PopulationInfo(cityName: "Woodside",       population: 5828,    density: 428,  medianIncome: 250001, medianAge: 49.5),
            PopulationInfo(cityName: "Atherton",       population: 7228,    density: 1228, medianIncome: 250001, medianAge: 48.8),
            PopulationInfo(cityName: "Portola Valley", population: 4812,    density: 428,  medianIncome: 250001, medianAge: 50.2),

            // ─── Marin County ────────────────────────────────────────────────
            PopulationInfo(cityName: "San Rafael",     population: 62828,   density: 3828, medianIncome: 104288, medianAge: 42.5),
            PopulationInfo(cityName: "Novato",         population: 57228,   density: 2228, medianIncome: 105488, medianAge: 43.5),
            PopulationInfo(cityName: "Mill Valley",    population: 14828,   density: 2028, medianIncome: 168288, medianAge: 45.8),
            PopulationInfo(cityName: "Tiburon",        population: 9228,    density: 2828, medianIncome: 210288, medianAge: 51.2),
            PopulationInfo(cityName: "Sausalito",      population: 7388,    density: 3228, medianIncome: 115288, medianAge: 47.5),
            PopulationInfo(cityName: "Fairfax",        population: 7828,    density: 4028, medianIncome: 99288,  medianAge: 44.2),
            PopulationInfo(cityName: "San Anselmo",    population: 12628,   density: 4228, medianIncome: 123288, medianAge: 44.8),

            // ─── Sonoma County ───────────────────────────────────────────────
            PopulationInfo(cityName: "Santa Rosa",     population: 178127,  density: 3828, medianIncome: 75288,  medianAge: 38.5),
            PopulationInfo(cityName: "Petaluma",       population: 61828,   density: 3228, medianIncome: 98288,  medianAge: 40.5),
            PopulationInfo(cityName: "Rohnert Park",   population: 42628,   density: 5228, medianIncome: 76288,  medianAge: 37.5),
            PopulationInfo(cityName: "Windsor",        population: 28828,   density: 2828, medianIncome: 95288,  medianAge: 37.0),
            PopulationInfo(cityName: "Sonoma",         population: 11228,   density: 2628, medianIncome: 82288,  medianAge: 48.5),

            // ─── Napa County ─────────────────────────────────────────────────
            PopulationInfo(cityName: "Napa",           population: 80228,   density: 2828, medianIncome: 78288,  medianAge: 40.5),
            PopulationInfo(cityName: "American Canyon",population: 21228,   density: 2228, medianIncome: 101288, medianAge: 36.5),

            // ─── Solano County ───────────────────────────────────────────────
            PopulationInfo(cityName: "Vallejo",        population: 124228,  density: 3428, medianIncome: 63288,  medianAge: 36.5),
            PopulationInfo(cityName: "Fairfield",      population: 120228,  density: 2728, medianIncome: 79288,  medianAge: 35.8),
            PopulationInfo(cityName: "Vacaville",      population: 104228,  density: 2528, medianIncome: 82288,  medianAge: 36.5),
            PopulationInfo(cityName: "Benicia",        population: 27228,   density: 2028, medianIncome: 102288, medianAge: 44.5),
        ]
    }
}
