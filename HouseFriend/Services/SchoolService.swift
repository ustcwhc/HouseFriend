import Foundation
import MapKit

enum SchoolLevel: String {
    case elementary = "E"
    case middle = "M"
    case high = "H"
}

struct School: Identifiable {
    let id = UUID()
    let name: String
    let level: SchoolLevel
    let rating: Int   // 1-10 (GreatSchools style)
    let coordinate: CLLocationCoordinate2D
}

class SchoolService: ObservableObject {
    @Published var schools: [School] = []

    func fetch() {
        schools = Self.bayAreaSchools()
    }

    // Real Bay Area schools with approximate GreatSchools ratings
    static func bayAreaSchools() -> [School] {
        return [
            // High Schools
            School(name: "Homestead High", level: .high, rating: 10, coordinate: CLLocationCoordinate2D(latitude: 37.3228, longitude: -122.0436)),
            School(name: "Lynbrook High", level: .high, rating: 10, coordinate: CLLocationCoordinate2D(latitude: 37.3063, longitude: -122.0044)),
            School(name: "Monta Vista High", level: .high, rating: 10, coordinate: CLLocationCoordinate2D(latitude: 37.3185, longitude: -122.0553)),
            School(name: "Santa Clara High", level: .high, rating: 10, coordinate: CLLocationCoordinate2D(latitude: 37.3561, longitude: -121.9734)),
            School(name: "Adrian Wilcox High", level: .high, rating: 9, coordinate: CLLocationCoordinate2D(latitude: 37.3797, longitude: -121.9731)),
            School(name: "Mission Early College High", level: .high, rating: 9, coordinate: CLLocationCoordinate2D(latitude: 37.3720, longitude: -121.9556)),
            School(name: "Del Mar High", level: .high, rating: 7, coordinate: CLLocationCoordinate2D(latitude: 37.2940, longitude: -121.8902)),
            School(name: "Abraham Lincoln High", level: .high, rating: 6, coordinate: CLLocationCoordinate2D(latitude: 37.3080, longitude: -121.8720)),
            School(name: "Boynton High", level: .high, rating: 2, coordinate: CLLocationCoordinate2D(latitude: 37.3442, longitude: -121.9601)),
            School(name: "Westmont High", level: .high, rating: 9, coordinate: CLLocationCoordinate2D(latitude: 37.2629, longitude: -121.9746)),
            School(name: "Branham High", level: .high, rating: 6, coordinate: CLLocationCoordinate2D(latitude: 37.2458, longitude: -121.8784)),
            School(name: "Milpitas High", level: .high, rating: 7, coordinate: CLLocationCoordinate2D(latitude: 37.4268, longitude: -121.9066)),
            School(name: "Piedmont Hills High", level: .high, rating: 8, coordinate: CLLocationCoordinate2D(latitude: 37.4190, longitude: -121.8534)),
            School(name: "Cupertino High", level: .high, rating: 9, coordinate: CLLocationCoordinate2D(latitude: 37.3245, longitude: -122.0302)),

            // Middle Schools
            School(name: "Price Charter Middle", level: .middle, rating: 9, coordinate: CLLocationCoordinate2D(latitude: 37.2570, longitude: -121.8880)),
            School(name: "Lawson Middle", level: .middle, rating: 7, coordinate: CLLocationCoordinate2D(latitude: 37.3630, longitude: -121.9740)),
            School(name: "Muir Middle", level: .middle, rating: 6, coordinate: CLLocationCoordinate2D(latitude: 37.3600, longitude: -121.9350)),
            School(name: "Miller Middle", level: .middle, rating: 8, coordinate: CLLocationCoordinate2D(latitude: 37.3320, longitude: -122.0200)),
            School(name: "Hyde Middle", level: .middle, rating: 8, coordinate: CLLocationCoordinate2D(latitude: 37.3450, longitude: -122.0080)),
            School(name: "Milpitas Middle", level: .middle, rating: 6, coordinate: CLLocationCoordinate2D(latitude: 37.4320, longitude: -121.9010)),

            // Elementary Schools
            School(name: "Fred E. Weibel Elementary", level: .elementary, rating: 10, coordinate: CLLocationCoordinate2D(latitude: 37.4740, longitude: -121.9265)),
            School(name: "Warm Springs Elementary", level: .elementary, rating: 10, coordinate: CLLocationCoordinate2D(latitude: 37.4840, longitude: -121.9130)),
            School(name: "George Mayne Elementary", level: .elementary, rating: 8, coordinate: CLLocationCoordinate2D(latitude: 37.4420, longitude: -121.9310)),
            School(name: "Anthony S. Elementary", level: .elementary, rating: 7, coordinate: CLLocationCoordinate2D(latitude: 37.4550, longitude: -121.9180)),
            School(name: "Dolores Huerta Elementary", level: .elementary, rating: 6, coordinate: CLLocationCoordinate2D(latitude: 37.3750, longitude: -121.9640)),
            School(name: "Vargas Elementary", level: .elementary, rating: 5, coordinate: CLLocationCoordinate2D(latitude: 37.3600, longitude: -121.9500)),
            School(name: "Briarwood Elementary", level: .elementary, rating: 8, coordinate: CLLocationCoordinate2D(latitude: 37.3490, longitude: -121.9760)),
            School(name: "Cupertino Elementary", level: .elementary, rating: 9, coordinate: CLLocationCoordinate2D(latitude: 37.3220, longitude: -122.0320)),
            School(name: "Montclaire Elementary", level: .elementary, rating: 9, coordinate: CLLocationCoordinate2D(latitude: 37.3370, longitude: -122.0540)),
        ]
    }
}
