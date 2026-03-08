import Foundation
import MapKit

struct SupportiveHousingFacility: Identifiable {
    let id = UUID()
    let name: String
    let type: String    // "Shelter", "Transitional", "Permanent"
    let coordinate: CLLocationCoordinate2D
    let capacity: Int?  // beds/units if known
}

class SupportiveHousingService: ObservableObject {
    @Published var facilities: [SupportiveHousingFacility] = []

    func fetch() {
        facilities = Self.allFacilities()
    }

    func fetchNear(lat: Double, lon: Double, radiusMiles: Double = 5) {
        facilities = Self.allFacilities().filter { f in
            let d = sqrt(pow(f.coordinate.latitude-lat,2)+pow(f.coordinate.longitude-lon,2)) * 69.0
            return d <= radiusMiles
        }
    }

    static func allFacilities() -> [SupportiveHousingFacility] {
        return [
            // ─── Santa Clara County (San Jose) ────────────────────────────────
            SupportiveHousingFacility(name: "HomeFirst Sunnyvale Winter Shelter", type: "Shelter",
                coordinate: .init(latitude: 37.3688, longitude: -122.036), capacity: 150),
            SupportiveHousingFacility(name: "Sunrise Village Emergency Shelter", type: "Shelter",
                coordinate: .init(latitude: 37.458, longitude: -121.973), capacity: 80),
            SupportiveHousingFacility(name: "HomeFirst Santa Clara", type: "Shelter",
                coordinate: .init(latitude: 37.355, longitude: -121.968), capacity: 100),
            SupportiveHousingFacility(name: "Sobrato Family Living Center", type: "Transitional",
                coordinate: .init(latitude: 37.358, longitude: -121.942), capacity: 60),
            SupportiveHousingFacility(name: "HomeKey Lawrence & Benton", type: "Permanent",
                coordinate: .init(latitude: 37.371, longitude: -121.988), capacity: 45),
            SupportiveHousingFacility(name: "Julian Street Inn", type: "Shelter",
                coordinate: .init(latitude: 37.341, longitude: -121.897), capacity: 115),
            SupportiveHousingFacility(name: "Parkmoor Community Hub", type: "Permanent",
                coordinate: .init(latitude: 37.299, longitude: -121.918), capacity: 50),
            SupportiveHousingFacility(name: "HomeFirst Overnight Warming Center", type: "Shelter",
                coordinate: .init(latitude: 37.280, longitude: -121.944), capacity: 75),
            SupportiveHousingFacility(name: "Eight Trees Apartments", type: "Permanent",
                coordinate: .init(latitude: 37.382, longitude: -122.052), capacity: 55),
            SupportiveHousingFacility(name: "Prospect & Highway 85 Shelter", type: "Shelter",
                coordinate: .init(latitude: 37.265, longitude: -122.037), capacity: 40),
            SupportiveHousingFacility(name: "Boccardo Reception Center", type: "Shelter",
                coordinate: .init(latitude: 37.352, longitude: -121.888), capacity: 225),
            SupportiveHousingFacility(name: "Montgomery Street Inn", type: "Transitional",
                coordinate: .init(latitude: 37.336, longitude: -121.893), capacity: 89),
            SupportiveHousingFacility(name: "South County Compassion Center", type: "Shelter",
                coordinate: .init(latitude: 37.198, longitude: -121.696), capacity: 50),
            SupportiveHousingFacility(name: "Bill Wilson Center (San Jose)", type: "Transitional",
                coordinate: .init(latitude: 37.310, longitude: -121.844), capacity: 120),
            SupportiveHousingFacility(name: "Cameron House", type: "Permanent",
                coordinate: .init(latitude: 37.332, longitude: -121.885), capacity: 35),
            SupportiveHousingFacility(name: "Charities Housing (San Jose)", type: "Permanent",
                coordinate: .init(latitude: 37.348, longitude: -121.906), capacity: 80),
            SupportiveHousingFacility(name: "Catholic Charities SCC", type: "Transitional",
                coordinate: .init(latitude: 37.356, longitude: -121.918), capacity: 65),
            SupportiveHousingFacility(name: "CARES Act Emergency Shelter (Berger)", type: "Shelter",
                coordinate: .init(latitude: 37.365, longitude: -121.925), capacity: 200),
            SupportiveHousingFacility(name: "Family Supportive Housing", type: "Permanent",
                coordinate: .init(latitude: 37.372, longitude: -121.958), capacity: 90),
            SupportiveHousingFacility(name: "Knox Tiny Home Village", type: "Transitional",
                coordinate: .init(latitude: 37.380, longitude: -121.870), capacity: 40),

            // ─── Mountain View / Sunnyvale ────────────────────────────────────
            SupportiveHousingFacility(name: "InnVision First Step (Mountain View)", type: "Transitional",
                coordinate: .init(latitude: 37.390, longitude: -122.082), capacity: 70),
            SupportiveHousingFacility(name: "HomeFirst Sunnyvale Family Shelter", type: "Shelter",
                coordinate: .init(latitude: 37.375, longitude: -122.025), capacity: 50),
            SupportiveHousingFacility(name: "StarHouse (Sunnyvale)", type: "Permanent",
                coordinate: .init(latitude: 37.381, longitude: -122.018), capacity: 30),

            // ─── Milpitas ─────────────────────────────────────────────────────
            SupportiveHousingFacility(name: "Milpitas Emergency Shelter", type: "Shelter",
                coordinate: .init(latitude: 37.432, longitude: -121.907), capacity: 60),
            SupportiveHousingFacility(name: "Milpitas Supportive Housing", type: "Permanent",
                coordinate: .init(latitude: 37.418, longitude: -121.916), capacity: 40),

            // ─── East San Jose ────────────────────────────────────────────────
            SupportiveHousingFacility(name: "Alum Rock Shelter (SJCC)", type: "Shelter",
                coordinate: .init(latitude: 37.368, longitude: -121.840), capacity: 45),
            SupportiveHousingFacility(name: "Eastside Navigation Center", type: "Transitional",
                coordinate: .init(latitude: 37.350, longitude: -121.820), capacity: 75),

            // ─── South San Jose / Gilroy ──────────────────────────────────────
            SupportiveHousingFacility(name: "South San Jose Shelter", type: "Shelter",
                coordinate: .init(latitude: 37.240, longitude: -121.870), capacity: 55),
            SupportiveHousingFacility(name: "Gilroy Compassion Center", type: "Shelter",
                coordinate: .init(latitude: 37.005, longitude: -121.569), capacity: 50),

            // ─── Los Gatos / Campbell ─────────────────────────────────────────
            SupportiveHousingFacility(name: "InnVision St. Joseph's (Campbell)", type: "Transitional",
                coordinate: .init(latitude: 37.288, longitude: -121.942), capacity: 55),
            SupportiveHousingFacility(name: "West Valley Community Services", type: "Shelter",
                coordinate: .init(latitude: 37.278, longitude: -121.998), capacity: 30),

            // ─── Fremont / Newark (Alameda County) ────────────────────────────
            SupportiveHousingFacility(name: "Abode Services Family Shelter (Fremont)", type: "Shelter",
                coordinate: .init(latitude: 37.548, longitude: -121.988), capacity: 60),
            SupportiveHousingFacility(name: "Fremont Family Resource Center", type: "Transitional",
                coordinate: .init(latitude: 37.560, longitude: -121.975), capacity: 45),
            SupportiveHousingFacility(name: "Eden Council Shelter (Hayward)", type: "Shelter",
                coordinate: .init(latitude: 37.668, longitude: -122.080), capacity: 80),

            // ─── Palo Alto ────────────────────────────────────────────────────
            SupportiveHousingFacility(name: "InnVision Opportunity Center (PA)", type: "Shelter",
                coordinate: .init(latitude: 37.444, longitude: -122.165), capacity: 90),
            SupportiveHousingFacility(name: "Palo Alto Shelter Network", type: "Transitional",
                coordinate: .init(latitude: 37.450, longitude: -122.178), capacity: 35),
        ]
    }
}
