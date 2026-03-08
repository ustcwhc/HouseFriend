import Foundation
import MapKit

struct SupportiveHousingFacility: Identifiable {
    let id = UUID()
    let name: String
    let type: String    // "Shelter", "Transitional", "Permanent"
    let coordinate: CLLocationCoordinate2D
}

class SupportiveHousingService: ObservableObject {
    @Published var facilities: [SupportiveHousingFacility] = []

    func fetch() {
        // Known Santa Clara County supportive housing facilities
        facilities = [
            SupportiveHousingFacility(name: "HomeFirst Sunnyvale\nCounty Winter Shelter", type: "Shelter",
                coordinate: CLLocationCoordinate2D(latitude: 37.3688, longitude: -122.036)),
            SupportiveHousingFacility(name: "Sunrise Village\nEmergency Shelter", type: "Shelter",
                coordinate: CLLocationCoordinate2D(latitude: 37.458, longitude: -121.973)),
            SupportiveHousingFacility(name: "HomeFirst SC\nSanta Clara", type: "Shelter",
                coordinate: CLLocationCoordinate2D(latitude: 37.355, longitude: -121.968)),
            SupportiveHousingFacility(name: "Sobrato Family\nLiving Center", type: "Transitional",
                coordinate: CLLocationCoordinate2D(latitude: 37.358, longitude: -121.942)),
            SupportiveHousingFacility(name: "HomeKey Lawrence\n& Benton", type: "Permanent",
                coordinate: CLLocationCoordinate2D(latitude: 37.371, longitude: -121.988)),
            SupportiveHousingFacility(name: "Julian Street\nProgram", type: "Shelter",
                coordinate: CLLocationCoordinate2D(latitude: 37.341, longitude: -121.897)),
            SupportiveHousingFacility(name: "Parkmoor (HUB)", type: "Permanent",
                coordinate: CLLocationCoordinate2D(latitude: 37.299, longitude: -121.918)),
            SupportiveHousingFacility(name: "HomeFirst Overnight\nWarming Locations", type: "Shelter",
                coordinate: CLLocationCoordinate2D(latitude: 37.280, longitude: -121.944)),
            SupportiveHousingFacility(name: "Eight Trees\nApartments", type: "Permanent",
                coordinate: CLLocationCoordinate2D(latitude: 37.382, longitude: -122.052)),
            SupportiveHousingFacility(name: "Prospect Rd &\nHighway 85", type: "Shelter",
                coordinate: CLLocationCoordinate2D(latitude: 37.265, longitude: -122.037)),
        ]
    }
}
