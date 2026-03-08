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
    let rating: Int         // 1-10 GreatSchools style
    let coordinate: CLLocationCoordinate2D
    let district: String
}

class SchoolService: ObservableObject {
    @Published var schools: [School] = []

    func fetch() {
        schools = Self.allBayAreaSchools()
    }

    func fetchNear(lat: Double, lon: Double, radiusMiles: Double = 5) {
        let all = Self.allBayAreaSchools()
        schools = all.filter { school in
            let dlat = school.coordinate.latitude  - lat
            let dlon = school.coordinate.longitude - lon
            return sqrt(dlat*dlat + dlon*dlon) * 69.0 <= radiusMiles
        }
    }

    static func allBayAreaSchools() -> [School] {
        return [
            // ═══════════════════════════════════════════════
            // HIGH SCHOOLS
            // ═══════════════════════════════════════════════

            // Cupertino Union / Fremont Union
            School(name: "Lynbrook High", level: .high, rating: 10,
                   coordinate: .init(latitude: 37.3063, longitude: -122.0044), district: "FUHSD"),
            School(name: "Monta Vista High", level: .high, rating: 10,
                   coordinate: .init(latitude: 37.3185, longitude: -122.0553), district: "FUHSD"),
            School(name: "Homestead High", level: .high, rating: 10,
                   coordinate: .init(latitude: 37.3228, longitude: -122.0436), district: "FUHSD"),
            School(name: "Fremont High (Sunnyvale)", level: .high, rating: 8,
                   coordinate: .init(latitude: 37.3730, longitude: -122.0238), district: "FUHSD"),
            School(name: "Cupertino High", level: .high, rating: 9,
                   coordinate: .init(latitude: 37.3245, longitude: -122.0302), district: "FUHSD"),

            // Santa Clara USD
            School(name: "Santa Clara High", level: .high, rating: 10,
                   coordinate: .init(latitude: 37.3561, longitude: -121.9734), district: "SCUSD"),
            School(name: "Adrian Wilcox High", level: .high, rating: 9,
                   coordinate: .init(latitude: 37.3797, longitude: -121.9731), district: "SCUSD"),
            School(name: "Mission Early College High", level: .high, rating: 9,
                   coordinate: .init(latitude: 37.3720, longitude: -121.9556), district: "SCUSD"),

            // San Jose USD
            School(name: "Leland High", level: .high, rating: 9,
                   coordinate: .init(latitude: 37.2520, longitude: -121.8488), district: "SJUSD"),
            School(name: "Willow Glen High", level: .high, rating: 7,
                   coordinate: .init(latitude: 37.3010, longitude: -121.9010), district: "SJUSD"),
            School(name: "Pioneer High (San Jose)", level: .high, rating: 7,
                   coordinate: .init(latitude: 37.3352, longitude: -121.9128), district: "SJUSD"),
            School(name: "Lincoln High (San Jose)", level: .high, rating: 6,
                   coordinate: .init(latitude: 37.3488, longitude: -121.8938), district: "SJUSD"),
            School(name: "Del Mar High", level: .high, rating: 7,
                   coordinate: .init(latitude: 37.2940, longitude: -121.8902), district: "Campbell USD"),
            School(name: "Branham High", level: .high, rating: 6,
                   coordinate: .init(latitude: 37.2458, longitude: -121.8784), district: "Campbell USD"),
            School(name: "Westmont High", level: .high, rating: 9,
                   coordinate: .init(latitude: 37.2629, longitude: -121.9746), district: "Campbell USD"),
            School(name: "Los Gatos High", level: .high, rating: 9,
                   coordinate: .init(latitude: 37.2298, longitude: -121.9658), district: "Los Gatos-Saratoga"),
            School(name: "Saratoga High", level: .high, rating: 10,
                   coordinate: .init(latitude: 37.2685, longitude: -122.0238), district: "Los Gatos-Saratoga"),

            // East Side Union
            School(name: "Independence High (San Jose)", level: .high, rating: 4,
                   coordinate: .init(latitude: 37.3682, longitude: -121.8408), district: "ESUHSD"),
            School(name: "Piedmont Hills High", level: .high, rating: 8,
                   coordinate: .init(latitude: 37.4190, longitude: -121.8534), district: "ESUHSD"),
            School(name: "Silver Creek High", level: .high, rating: 6,
                   coordinate: .init(latitude: 37.3060, longitude: -121.8048), district: "ESUHSD"),
            School(name: "Evergreen Valley High", level: .high, rating: 8,
                   coordinate: .init(latitude: 37.3218, longitude: -121.7850), district: "ESUHSD"),
            School(name: "James Lick High", level: .high, rating: 3,
                   coordinate: .init(latitude: 37.3488, longitude: -121.8478), district: "ESUHSD"),
            School(name: "Yerlan High", level: .high, rating: 3,
                   coordinate: .init(latitude: 37.3388, longitude: -121.8138), district: "ESUHSD"),

            // Milpitas USD
            School(name: "Milpitas High", level: .high, rating: 7,
                   coordinate: .init(latitude: 37.4268, longitude: -121.9066), district: "Milpitas USD"),

            // Fremont / Newark USD
            School(name: "Mission San Jose High (Fremont)", level: .high, rating: 10,
                   coordinate: .init(latitude: 37.5308, longitude: -121.9280), district: "Fremont USD"),
            School(name: "Irvington High (Fremont)", level: .high, rating: 9,
                   coordinate: .init(latitude: 37.5448, longitude: -121.9618), district: "Fremont USD"),
            School(name: "Washington High (Fremont)", level: .high, rating: 7,
                   coordinate: .init(latitude: 37.5578, longitude: -121.9828), district: "Fremont USD"),
            School(name: "American High (Fremont)", level: .high, rating: 8,
                   coordinate: .init(latitude: 37.5138, longitude: -121.9730), district: "Fremont USD"),
            School(name: "Newark Memorial High", level: .high, rating: 6,
                   coordinate: .init(latitude: 37.5298, longitude: -122.0468), district: "Newark USD"),

            // Mountain View / Los Altos
            School(name: "Mountain View High", level: .high, rating: 8,
                   coordinate: .init(latitude: 37.3890, longitude: -122.0872), district: "MVLA"),
            School(name: "Los Altos High", level: .high, rating: 9,
                   coordinate: .init(latitude: 37.3678, longitude: -122.1028), district: "MVLA"),

            // Palo Alto
            School(name: "Palo Alto High (Paly)", level: .high, rating: 9,
                   coordinate: .init(latitude: 37.4418, longitude: -122.1592), district: "Palo Alto USD"),
            School(name: "Gunn High (Palo Alto)", level: .high, rating: 10,
                   coordinate: .init(latitude: 37.3978, longitude: -122.1168), district: "Palo Alto USD"),

            // ═══════════════════════════════════════════════
            // MIDDLE SCHOOLS
            // ═══════════════════════════════════════════════
            School(name: "Price Charter Middle", level: .middle, rating: 9,
                   coordinate: .init(latitude: 37.2570, longitude: -121.8880), district: "Campbell USD"),
            School(name: "Lawson Middle (Santa Clara)", level: .middle, rating: 7,
                   coordinate: .init(latitude: 37.3630, longitude: -121.9740), district: "SCUSD"),
            School(name: "Milpitas Middle", level: .middle, rating: 6,
                   coordinate: .init(latitude: 37.4320, longitude: -121.9010), district: "Milpitas USD"),
            School(name: "Miller Middle (Cupertino)", level: .middle, rating: 8,
                   coordinate: .init(latitude: 37.3320, longitude: -122.0200), district: "CUSD"),
            School(name: "Hyde Middle (Cupertino)", level: .middle, rating: 8,
                   coordinate: .init(latitude: 37.3450, longitude: -122.0080), district: "CUSD"),
            School(name: "Kennedy Middle (Cupertino)", level: .middle, rating: 8,
                   coordinate: .init(latitude: 37.3098, longitude: -122.0448), district: "CUSD"),
            School(name: "Crittenden Middle (Mountain View)", level: .middle, rating: 5,
                   coordinate: .init(latitude: 37.3988, longitude: -122.0868), district: "MVWSD"),
            School(name: "Graham Middle (Mountain View)", level: .middle, rating: 7,
                   coordinate: .init(latitude: 37.3978, longitude: -122.0632), district: "MVWSD"),
            School(name: "Jordan Middle (Palo Alto)", level: .middle, rating: 8,
                   coordinate: .init(latitude: 37.4358, longitude: -122.1298), district: "PAUSD"),
            School(name: "JLS Middle (Palo Alto)", level: .middle, rating: 8,
                   coordinate: .init(latitude: 37.4078, longitude: -122.1198), district: "PAUSD"),
            School(name: "Muir Middle (San Jose)", level: .middle, rating: 6,
                   coordinate: .init(latitude: 37.3600, longitude: -121.9350), district: "SJUSD"),
            School(name: "Hoover Middle (San Jose)", level: .middle, rating: 5,
                   coordinate: .init(latitude: 37.3218, longitude: -121.8748), district: "SJUSD"),
            School(name: "Bret Harte Middle (San Jose)", level: .middle, rating: 6,
                   coordinate: .init(latitude: 37.2768, longitude: -121.8958), district: "SJUSD"),
            School(name: "Dartmouth Middle (San Jose)", level: .middle, rating: 5,
                   coordinate: .init(latitude: 37.3488, longitude: -121.8558), district: "ESUHSD"),
            School(name: "Fremont Middle (Sunnyvale)", level: .middle, rating: 6,
                   coordinate: .init(latitude: 37.3728, longitude: -122.0118), district: "Sunnyvale SD"),
            School(name: "Sunnyvale Middle", level: .middle, rating: 7,
                   coordinate: .init(latitude: 37.3868, longitude: -122.0188), district: "Sunnyvale SD"),
            School(name: "Thomas Russell Middle (Milpitas)", level: .middle, rating: 6,
                   coordinate: .init(latitude: 37.4380, longitude: -121.9068), district: "Milpitas USD"),
            School(name: "Lakeview Middle (Santa Clara)", level: .middle, rating: 7,
                   coordinate: .init(latitude: 37.3788, longitude: -121.9918), district: "SCUSD"),

            // ═══════════════════════════════════════════════
            // ELEMENTARY SCHOOLS
            // ═══════════════════════════════════════════════
            // Milpitas
            School(name: "Fred E. Weibel Elementary", level: .elementary, rating: 10,
                   coordinate: .init(latitude: 37.4740, longitude: -121.9265), district: "Milpitas USD"),
            School(name: "Warm Springs Elementary", level: .elementary, rating: 10,
                   coordinate: .init(latitude: 37.4840, longitude: -121.9130), district: "Fremont USD"),
            School(name: "George Mayne Elementary", level: .elementary, rating: 8,
                   coordinate: .init(latitude: 37.4420, longitude: -121.9310), district: "Milpitas USD"),
            School(name: "Anthony Spangler Elementary", level: .elementary, rating: 7,
                   coordinate: .init(latitude: 37.4550, longitude: -121.9180), district: "Milpitas USD"),
            School(name: "Curtner Elementary (Milpitas)", level: .elementary, rating: 7,
                   coordinate: .init(latitude: 37.4288, longitude: -121.8958), district: "Milpitas USD"),
            School(name: "Weller Elementary (Milpitas)", level: .elementary, rating: 6,
                   coordinate: .init(latitude: 37.4418, longitude: -121.9058), district: "Milpitas USD"),

            // Cupertino USD
            School(name: "Lincoln Elementary (Cupertino)", level: .elementary, rating: 10,
                   coordinate: .init(latitude: 37.3230, longitude: -122.0608), district: "CUSD"),
            School(name: "Montclaire Elementary", level: .elementary, rating: 9,
                   coordinate: .init(latitude: 37.3370, longitude: -122.0540), district: "CUSD"),
            School(name: "Nimitz Elementary", level: .elementary, rating: 9,
                   coordinate: .init(latitude: 37.3178, longitude: -122.0318), district: "CUSD"),
            School(name: "Eaton Elementary", level: .elementary, rating: 9,
                   coordinate: .init(latitude: 37.3088, longitude: -122.0508), district: "CUSD"),
            School(name: "Sedgwick Elementary", level: .elementary, rating: 9,
                   coordinate: .init(latitude: 37.2948, longitude: -122.0368), district: "CUSD"),

            // Santa Clara USD
            School(name: "Briarwood Elementary (Santa Clara)", level: .elementary, rating: 8,
                   coordinate: .init(latitude: 37.3490, longitude: -121.9760), district: "SCUSD"),
            School(name: "Bowers Elementary", level: .elementary, rating: 7,
                   coordinate: .init(latitude: 37.3840, longitude: -121.9688), district: "SCUSD"),
            School(name: "Sutter Elementary (Santa Clara)", level: .elementary, rating: 7,
                   coordinate: .init(latitude: 37.3648, longitude: -121.9558), district: "SCUSD"),

            // San Jose USD
            School(name: "Dolores Huerta Elementary", level: .elementary, rating: 6,
                   coordinate: .init(latitude: 37.3750, longitude: -121.9640), district: "SJUSD"),
            School(name: "Willow Glen Elementary", level: .elementary, rating: 7,
                   coordinate: .init(latitude: 37.3018, longitude: -121.9068), district: "SJUSD"),
            School(name: "Allen at Steinbeck Elementary", level: .elementary, rating: 8,
                   coordinate: .init(latitude: 37.2550, longitude: -121.8508), district: "SJUSD"),
            School(name: "Booksin Elementary", level: .elementary, rating: 8,
                   coordinate: .init(latitude: 37.2808, longitude: -121.8868), district: "SJUSD"),

            // Fremont
            School(name: "Gomes Elementary (Fremont)", level: .elementary, rating: 9,
                   coordinate: .init(latitude: 37.5388, longitude: -121.9328), district: "Fremont USD"),
            School(name: "Oliveira Elementary (Fremont)", level: .elementary, rating: 8,
                   coordinate: .init(latitude: 37.5438, longitude: -121.9588), district: "Fremont USD"),
            School(name: "Centerville Elementary (Fremont)", level: .elementary, rating: 7,
                   coordinate: .init(latitude: 37.5268, longitude: -121.9678), district: "Fremont USD"),

            // Sunnyvale
            School(name: "Cherry Chase Elementary", level: .elementary, rating: 8,
                   coordinate: .init(latitude: 37.3648, longitude: -122.0238), district: "Sunnyvale SD"),
            School(name: "Bishop Elementary (Sunnyvale)", level: .elementary, rating: 7,
                   coordinate: .init(latitude: 37.3878, longitude: -122.0368), district: "Sunnyvale SD"),
            School(name: "Lakewood Elementary (Sunnyvale)", level: .elementary, rating: 7,
                   coordinate: .init(latitude: 37.3778, longitude: -122.0288), district: "Sunnyvale SD"),

            // Mountain View
            School(name: "Castro Elementary (Mountain View)", level: .elementary, rating: 6,
                   coordinate: .init(latitude: 37.3918, longitude: -122.0798), district: "MVWSD"),
            School(name: "Theuerkauf Elementary", level: .elementary, rating: 7,
                   coordinate: .init(latitude: 37.3798, longitude: -122.0798), district: "MVWSD"),
            School(name: "Bubb Elementary", level: .elementary, rating: 7,
                   coordinate: .init(latitude: 37.3658, longitude: -122.0798), district: "MVWSD"),

            // Palo Alto
            School(name: "Ohlone Elementary (Palo Alto)", level: .elementary, rating: 9,
                   coordinate: .init(latitude: 37.4298, longitude: -122.1368), district: "PAUSD"),
            School(name: "Duveneck Elementary (Palo Alto)", level: .elementary, rating: 9,
                   coordinate: .init(latitude: 37.4458, longitude: -122.1628), district: "PAUSD"),
            School(name: "Barron Park Elementary", level: .elementary, rating: 8,
                   coordinate: .init(latitude: 37.4098, longitude: -122.1228), district: "PAUSD"),
        ]
    }
}
