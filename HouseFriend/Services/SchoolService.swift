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
    let rating: Int
    let coordinate: CLLocationCoordinate2D
    let district: String
}

class SchoolService: ObservableObject {
    @Published var schools: [School] = []

    func fetch() { schools = Self.allBayAreaSchools() }

    func fetchNear(lat: Double, lon: Double, radiusMiles: Double = 5) {
        schools = Self.allBayAreaSchools().filter { s in
            sqrt(pow(s.coordinate.latitude-lat,2)+pow(s.coordinate.longitude-lon,2)) * 69.0 <= radiusMiles
        }
    }

    static func allBayAreaSchools() -> [School] { return
        santaClaraSchools() + alamedaSchools() + sanFranciscoSchools() +
        sanMateoSchools() + contraCostSchools() + marinSonomaSchools()
    }

    // ═══════════════════════════════════════════════════════
    // SANTA CLARA COUNTY
    // ═══════════════════════════════════════════════════════
    static func santaClaraSchools() -> [School] { return [
        // High Schools
        School(name:"Lynbrook High",level:.high,rating:10,coordinate:.init(latitude:37.3063,longitude:-122.0044),district:"FUHSD"),
        School(name:"Monta Vista High",level:.high,rating:10,coordinate:.init(latitude:37.3185,longitude:-122.0553),district:"FUHSD"),
        School(name:"Homestead High",level:.high,rating:10,coordinate:.init(latitude:37.3228,longitude:-122.0436),district:"FUHSD"),
        School(name:"Fremont High Sunnyvale",level:.high,rating:8,coordinate:.init(latitude:37.3730,longitude:-122.0238),district:"FUHSD"),
        School(name:"Cupertino High",level:.high,rating:9,coordinate:.init(latitude:37.3245,longitude:-122.0302),district:"FUHSD"),
        School(name:"Santa Clara High",level:.high,rating:10,coordinate:.init(latitude:37.3561,longitude:-121.9734),district:"SCUSD"),
        School(name:"Adrian Wilcox High",level:.high,rating:9,coordinate:.init(latitude:37.3797,longitude:-121.9731),district:"SCUSD"),
        School(name:"Leland High",level:.high,rating:9,coordinate:.init(latitude:37.2520,longitude:-121.8488),district:"SJUSD"),
        School(name:"Willow Glen High",level:.high,rating:7,coordinate:.init(latitude:37.3010,longitude:-121.9010),district:"SJUSD"),
        School(name:"Pioneer High SJ",level:.high,rating:7,coordinate:.init(latitude:37.3352,longitude:-121.9128),district:"SJUSD"),
        School(name:"Lincoln High SJ",level:.high,rating:6,coordinate:.init(latitude:37.3488,longitude:-121.8938),district:"SJUSD"),
        School(name:"Del Mar High",level:.high,rating:7,coordinate:.init(latitude:37.2940,longitude:-121.8902),district:"Campbell USD"),
        School(name:"Westmont High",level:.high,rating:9,coordinate:.init(latitude:37.2629,longitude:-121.9746),district:"Campbell USD"),
        School(name:"Los Gatos High",level:.high,rating:9,coordinate:.init(latitude:37.2298,longitude:-121.9658),district:"LGUSD"),
        School(name:"Saratoga High",level:.high,rating:10,coordinate:.init(latitude:37.2685,longitude:-122.0238),district:"LGUSD"),
        School(name:"Independence High SJ",level:.high,rating:4,coordinate:.init(latitude:37.3682,longitude:-121.8408),district:"ESUHSD"),
        School(name:"Piedmont Hills High",level:.high,rating:8,coordinate:.init(latitude:37.4190,longitude:-121.8534),district:"ESUHSD"),
        School(name:"Silver Creek High",level:.high,rating:6,coordinate:.init(latitude:37.3060,longitude:-121.8048),district:"ESUHSD"),
        School(name:"Evergreen Valley High",level:.high,rating:8,coordinate:.init(latitude:37.3218,longitude:-121.7850),district:"ESUHSD"),
        School(name:"James Lick High",level:.high,rating:3,coordinate:.init(latitude:37.3488,longitude:-121.8478),district:"ESUHSD"),
        School(name:"Milpitas High",level:.high,rating:7,coordinate:.init(latitude:37.4268,longitude:-121.9066),district:"Milpitas USD"),
        School(name:"Mountain View High",level:.high,rating:8,coordinate:.init(latitude:37.3890,longitude:-122.0872),district:"MVLA"),
        School(name:"Los Altos High",level:.high,rating:9,coordinate:.init(latitude:37.3678,longitude:-122.1028),district:"MVLA"),
        School(name:"Palo Alto High",level:.high,rating:9,coordinate:.init(latitude:37.4418,longitude:-122.1592),district:"PAUSD"),
        School(name:"Henry M. Gunn High",level:.high,rating:10,coordinate:.init(latitude:37.3978,longitude:-122.1168),district:"PAUSD"),
        // Middle
        School(name:"Miller Middle Cupertino",level:.middle,rating:8,coordinate:.init(latitude:37.3320,longitude:-122.0200),district:"CUSD"),
        School(name:"Hyde Middle",level:.middle,rating:8,coordinate:.init(latitude:37.3450,longitude:-122.0080),district:"CUSD"),
        School(name:"Kennedy Middle Cupertino",level:.middle,rating:8,coordinate:.init(latitude:37.3098,longitude:-122.0448),district:"CUSD"),
        School(name:"Graham Middle MV",level:.middle,rating:7,coordinate:.init(latitude:37.3978,longitude:-122.0632),district:"MVWSD"),
        School(name:"Crittenden Middle MV",level:.middle,rating:5,coordinate:.init(latitude:37.3988,longitude:-122.0868),district:"MVWSD"),
        School(name:"Jordan Middle PA",level:.middle,rating:8,coordinate:.init(latitude:37.4358,longitude:-122.1298),district:"PAUSD"),
        School(name:"JLS Middle PA",level:.middle,rating:8,coordinate:.init(latitude:37.4078,longitude:-122.1198),district:"PAUSD"),
        School(name:"Milpitas Middle",level:.middle,rating:6,coordinate:.init(latitude:37.4320,longitude:-121.9010),district:"Milpitas USD"),
        School(name:"Sunnyvale Middle",level:.middle,rating:7,coordinate:.init(latitude:37.3868,longitude:-122.0188),district:"Sunnyvale SD"),
        // Elementary
        School(name:"Lincoln Elementary Cupertino",level:.elementary,rating:10,coordinate:.init(latitude:37.3230,longitude:-122.0608),district:"CUSD"),
        School(name:"Montclaire Elementary",level:.elementary,rating:9,coordinate:.init(latitude:37.3370,longitude:-122.0540),district:"CUSD"),
        School(name:"Saratoga Elementary",level:.elementary,rating:10,coordinate:.init(latitude:37.2658,longitude:-122.0218),district:"Saratoga USD"),
        School(name:"Weibel Elementary",level:.elementary,rating:10,coordinate:.init(latitude:37.4740,longitude:-121.9265),district:"Milpitas USD"),
        School(name:"Cherry Chase Elementary",level:.elementary,rating:8,coordinate:.init(latitude:37.3648,longitude:-122.0238),district:"Sunnyvale SD"),
        School(name:"Ohlone Elementary PA",level:.elementary,rating:9,coordinate:.init(latitude:37.4298,longitude:-122.1368),district:"PAUSD"),
    ]}

    // ═══════════════════════════════════════════════════════
    // ALAMEDA COUNTY
    // ═══════════════════════════════════════════════════════
    static func alamedaSchools() -> [School] { return [
        // Fremont
        School(name:"Mission San Jose High",level:.high,rating:10,coordinate:.init(latitude:37.5308,longitude:-121.9280),district:"Fremont USD"),
        School(name:"Irvington High Fremont",level:.high,rating:9,coordinate:.init(latitude:37.5448,longitude:-121.9618),district:"Fremont USD"),
        School(name:"Washington High Fremont",level:.high,rating:7,coordinate:.init(latitude:37.5578,longitude:-121.9828),district:"Fremont USD"),
        School(name:"American High Fremont",level:.high,rating:8,coordinate:.init(latitude:37.5138,longitude:-121.9730),district:"Fremont USD"),
        School(name:"Newark Memorial High",level:.high,rating:6,coordinate:.init(latitude:37.5298,longitude:-122.0468),district:"Newark USD"),
        // Oakland
        School(name:"Oakland Tech High",level:.high,rating:7,coordinate:.init(latitude:37.8258,longitude:-122.2528),district:"OUSD"),
        School(name:"Skyline High Oakland",level:.high,rating:6,coordinate:.init(latitude:37.8018,longitude:-122.1958),district:"OUSD"),
        School(name:"McClymonds High Oakland",level:.high,rating:3,coordinate:.init(latitude:37.8138,longitude:-122.2918),district:"OUSD"),
        School(name:"Fremont High Oakland",level:.high,rating:3,coordinate:.init(latitude:37.7718,longitude:-122.2168),district:"OUSD"),
        School(name:"Castlemont High Oakland",level:.high,rating:3,coordinate:.init(latitude:37.7648,longitude:-122.1858),district:"OUSD"),
        School(name:"Oakland High",level:.high,rating:4,coordinate:.init(latitude:37.8018,longitude:-122.2668),district:"OUSD"),
        School(name:"Skyline High Oakland Hills",level:.high,rating:6,coordinate:.init(latitude:37.8148,longitude:-122.1988),district:"OUSD"),
        // Berkeley
        School(name:"Berkeley High",level:.high,rating:8,coordinate:.init(latitude:37.8678,longitude:-122.2678),district:"BUSD"),
        // Hayward
        School(name:"Hayward High",level:.high,rating:5,coordinate:.init(latitude:37.6688,longitude:-122.0948),district:"Hayward USD"),
        School(name:"Mt. Eden High",level:.high,rating:5,coordinate:.init(latitude:37.6518,longitude:-122.0618),district:"Hayward USD"),
        School(name:"Tennyson High Hayward",level:.high,rating:4,coordinate:.init(latitude:37.6258,longitude:-122.0738),district:"Hayward USD"),
        // San Leandro
        School(name:"San Leandro High",level:.high,rating:6,coordinate:.init(latitude:37.7218,longitude:-122.1558),district:"San Leandro USD"),
        // Tri-Valley
        School(name:"Dublin High",level:.high,rating:9,coordinate:.init(latitude:37.7028,longitude:-121.9298),district:"Dublin USD"),
        School(name:"Pleasanton High",level:.high,rating:9,coordinate:.init(latitude:37.6618,longitude:-121.8748),district:"Pleasanton USD"),
        School(name:"Foothill High Pleasanton",level:.high,rating:9,coordinate:.init(latitude:37.6938,longitude:-121.8648),district:"Pleasanton USD"),
        School(name:"Livermore High",level:.high,rating:7,coordinate:.init(latitude:37.6818,longitude:-121.7688),district:"Livermore USD"),
        School(name:"Granada High Livermore",level:.high,rating:7,coordinate:.init(latitude:37.6948,longitude:-121.7498),district:"Livermore USD"),
        // Alameda
        School(name:"Alameda High",level:.high,rating:7,coordinate:.init(latitude:37.7758,longitude:-122.2528),district:"Alameda USD"),
        School(name:"Encinal High Alameda",level:.high,rating:6,coordinate:.init(latitude:37.7718,longitude:-122.2708),district:"Alameda USD"),
        // Middle / Elementary
        School(name:"King Middle Berkeley",level:.middle,rating:7,coordinate:.init(latitude:37.8638,longitude:-122.2798),district:"BUSD"),
        School(name:"Longfellow Middle Oakland",level:.middle,rating:5,coordinate:.init(latitude:37.8108,longitude:-122.2628),district:"OUSD"),
        School(name:"Gomes Elementary Fremont",level:.elementary,rating:9,coordinate:.init(latitude:37.5388,longitude:-121.9328),district:"Fremont USD"),
        School(name:"Warm Springs Elementary",level:.elementary,rating:10,coordinate:.init(latitude:37.4840,longitude:-121.9130),district:"Fremont USD"),
        School(name:"Chabot Elementary Oakland",level:.elementary,rating:8,coordinate:.init(latitude:37.8328,longitude:-122.2108),district:"OUSD"),
    ]}

    // ═══════════════════════════════════════════════════════
    // SAN FRANCISCO COUNTY
    // ═══════════════════════════════════════════════════════
    static func sanFranciscoSchools() -> [School] { return [
        School(name:"Lowell High SF",level:.high,rating:10,coordinate:.init(latitude:37.7268,longitude:-122.4788),district:"SFUSD"),
        School(name:"Galileo High SF",level:.high,rating:6,coordinate:.init(latitude:37.8008,longitude:-122.4278),district:"SFUSD"),
        School(name:"Washington High SF",level:.high,rating:6,coordinate:.init(latitude:37.7538,longitude:-122.4688),district:"SFUSD"),
        School(name:"Lincoln High SF",level:.high,rating:7,coordinate:.init(latitude:37.7238,longitude:-122.4908),district:"SFUSD"),
        School(name:"Mission High SF",level:.high,rating:5,coordinate:.init(latitude:37.7628,longitude:-122.4258),district:"SFUSD"),
        School(name:"Balboa High SF",level:.high,rating:5,coordinate:.init(latitude:37.7208,longitude:-122.4478),district:"SFUSD"),
        School(name:"SF International High",level:.high,rating:4,coordinate:.init(latitude:37.7778,longitude:-122.4108),district:"SFUSD"),
        School(name:"Thurgood Marshall High SF",level:.high,rating:5,coordinate:.init(latitude:37.7318,longitude:-122.4078),district:"SFUSD"),
        School(name:"Everett Middle SF",level:.middle,rating:5,coordinate:.init(latitude:37.7618,longitude:-122.4258),district:"SFUSD"),
        School(name:"Presidio Middle SF",level:.middle,rating:7,coordinate:.init(latitude:37.7868,longitude:-122.4608),district:"SFUSD"),
        School(name:"Rooftop K-8 SF",level:.elementary,rating:8,coordinate:.init(latitude:37.7478,longitude:-122.4438),district:"SFUSD"),
        School(name:"Alvarado Elementary SF",level:.elementary,rating:7,coordinate:.init(latitude:37.7488,longitude:-122.4288),district:"SFUSD"),
        School(name:"Chinese Immersion K-8",level:.elementary,rating:8,coordinate:.init(latitude:37.7938,longitude:-122.4078),district:"SFUSD"),
    ]}

    // ═══════════════════════════════════════════════════════
    // SAN MATEO COUNTY
    // ═══════════════════════════════════════════════════════
    static func sanMateoSchools() -> [School] { return [
        School(name:"Palo Alto High",level:.high,rating:9,coordinate:.init(latitude:37.4418,longitude:-122.1592),district:"PAUSD"),
        School(name:"Gunn High",level:.high,rating:10,coordinate:.init(latitude:37.3978,longitude:-122.1168),district:"PAUSD"),
        School(name:"Menlo-Atherton High",level:.high,rating:7,coordinate:.init(latitude:37.4518,longitude:-122.1868),district:"SMUHSD"),
        School(name:"Sequoia High Redwood City",level:.high,rating:7,coordinate:.init(latitude:37.4858,longitude:-122.2248),district:"SMUHSD"),
        School(name:"Woodside High",level:.high,rating:8,coordinate:.init(latitude:37.4338,longitude:-122.2528),district:"SMUHSD"),
        School(name:"Carlmont High",level:.high,rating:8,coordinate:.init(latitude:37.5188,longitude:-122.2968),district:"SMUHSD"),
        School(name:"Aragon High",level:.high,rating:9,coordinate:.init(latitude:37.5728,longitude:-122.3508),district:"SMUHSD"),
        School(name:"Mills High Millbrae",level:.high,rating:9,coordinate:.init(latitude:37.5978,longitude:-122.3888),district:"SMUHSD"),
        School(name:"San Mateo High",level:.high,rating:7,coordinate:.init(latitude:37.5618,longitude:-122.3168),district:"SMUHSD"),
        School(name:"Capuchino High",level:.high,rating:6,coordinate:.init(latitude:37.5888,longitude:-122.4008),district:"SMUHSD"),
        School(name:"Serra High San Mateo",level:.high,rating:8,coordinate:.init(latitude:37.5478,longitude:-122.3028),district:"Archdiocese"),
        School(name:"Half Moon Bay High",level:.high,rating:7,coordinate:.init(latitude:37.4638,longitude:-122.4278),district:"CSMA USD"),
        // Middle
        School(name:"Abbott Middle San Mateo",level:.middle,rating:7,coordinate:.init(latitude:37.5568,longitude:-122.3198),district:"SMUSD"),
        School(name:"Borel Middle",level:.middle,rating:8,coordinate:.init(latitude:37.5668,longitude:-122.3368),district:"SMUSD"),
        // Elementary
        School(name:"Hillsdale Elementary",level:.elementary,rating:8,coordinate:.init(latitude:37.5508,longitude:-122.3168),district:"SMUSD"),
        School(name:"Laurel Elementary Atherton",level:.elementary,rating:9,coordinate:.init(latitude:37.4618,longitude:-122.1988),district:"Redwood City USD"),
    ]}

    // ═══════════════════════════════════════════════════════
    // CONTRA COSTA COUNTY
    // ═══════════════════════════════════════════════════════
    static func contraCostSchools() -> [School] { return [
        School(name:"De La Salle High Concord",level:.high,rating:9,coordinate:.init(latitude:37.9628,longitude:-122.0518),district:"Private"),
        School(name:"Northgate High Walnut Creek",level:.high,rating:9,coordinate:.init(latitude:37.9318,longitude:-122.0638),district:"MDUSD"),
        School(name:"Acalanes High Lafayette",level:.high,rating:10,coordinate:.init(latitude:37.8918,longitude:-122.1118),district:"Acalanes USD"),
        School(name:"Campolindo High Moraga",level:.high,rating:10,coordinate:.init(latitude:37.8618,longitude:-122.1318),district:"Acalanes USD"),
        School(name:"Miramonte High Orinda",level:.high,rating:10,coordinate:.init(latitude:37.8738,longitude:-122.1848),district:"Acalanes USD"),
        School(name:"Las Lomas High Walnut Creek",level:.high,rating:9,coordinate:.init(latitude:37.9228,longitude:-122.0318),district:"Acalanes USD"),
        School(name:"San Ramon Valley High",level:.high,rating:9,coordinate:.init(latitude:37.8218,longitude:-121.9778),district:"SRVUSD"),
        School(name:"Dougherty Valley High",level:.high,rating:9,coordinate:.init(latitude:37.7918,longitude:-121.9438),district:"SRVUSD"),
        School(name:"California High San Ramon",level:.high,rating:9,coordinate:.init(latitude:37.7768,longitude:-121.9688),district:"SRVUSD"),
        School(name:"Monte Vista High Danville",level:.high,rating:10,coordinate:.init(latitude:37.8288,longitude:-121.9958),district:"SRVUSD"),
        School(name:"Concord High",level:.high,rating:6,coordinate:.init(latitude:37.9778,longitude:-122.0318),district:"MDUSD"),
        School(name:"College Park High Pleasant Hill",level:.high,rating:7,coordinate:.init(latitude:37.9478,longitude:-122.0778),district:"MDUSD"),
        School(name:"Pittsburg High",level:.high,rating:4,coordinate:.init(latitude:38.0178,longitude:-121.8778),district:"Pittsburg USD"),
        School(name:"Antioch High",level:.high,rating:4,coordinate:.init(latitude:38.0048,longitude:-121.8138),district:"Antioch USD"),
        School(name:"Heritage High Brentwood",level:.high,rating:7,coordinate:.init(latitude:37.9308,longitude:-121.6978),district:"Liberty USD"),
        // Middle
        School(name:"Alamo Elementary Middle",level:.middle,rating:9,coordinate:.init(latitude:37.8528,longitude:-122.0138),district:"SRVUSD"),
        School(name:"Walnut Creek Intermediate",level:.middle,rating:8,coordinate:.init(latitude:37.9108,longitude:-122.0558),district:"Walnut Creek SD"),
    ]}

    // ═══════════════════════════════════════════════════════
    // MARIN / SONOMA / NAPA
    // ═══════════════════════════════════════════════════════
    static func marinSonomaSchools() -> [School] { return [
        // Marin
        School(name:"Tamalpais High",level:.high,rating:9,coordinate:.init(latitude:37.8958,longitude:-122.5218),district:"TUHSD"),
        School(name:"Drake High Fairfax",level:.high,rating:8,coordinate:.init(latitude:37.9878,longitude:-122.5888),district:"TUHSD"),
        School(name:"Marin Catholic High",level:.high,rating:9,coordinate:.init(latitude:37.9548,longitude:-122.5438),district:"Private"),
        School(name:"San Rafael High",level:.high,rating:6,coordinate:.init(latitude:37.9728,longitude:-122.5198),district:"SRCS"),
        School(name:"Terra Linda High",level:.high,rating:7,coordinate:.init(latitude:37.9978,longitude:-122.5238),district:"SRCS"),
        School(name:"Redwood High Larkspur",level:.high,rating:9,coordinate:.init(latitude:37.9398,longitude:-122.5338),district:"TUHSD"),
        // Sonoma
        School(name:"Maria Carrillo High",level:.high,rating:8,coordinate:.init(latitude:38.4508,longitude:-122.7188),district:"Santa Rosa City"),
        School(name:"Montgomery High Santa Rosa",level:.high,rating:7,coordinate:.init(latitude:38.4388,longitude:-122.7108),district:"Santa Rosa City"),
        School(name:"Windsor High",level:.high,rating:7,coordinate:.init(latitude:38.5488,longitude:-122.8168),district:"Windsor USD"),
        School(name:"Petaluma High",level:.high,rating:7,coordinate:.init(latitude:38.2298,longitude:-122.6358),district:"Petaluma City"),
        // Napa
        School(name:"Napa High",level:.high,rating:7,coordinate:.init(latitude:38.2918,longitude:-122.2848),district:"Napa USD"),
        School(name:"Vintage High Napa",level:.high,rating:7,coordinate:.init(latitude:38.3208,longitude:-122.2868),district:"Napa USD"),
        School(name:"Redwood Middle Napa",level:.middle,rating:6,coordinate:.init(latitude:38.2958,longitude:-122.2828),district:"Napa USD"),
    ]}
}
