import Foundation
import MapKit

struct NoiseZone: Identifiable {
    let id = UUID()
    let polygon: [CLLocationCoordinate2D]
    let dbLevel: Int
}

// Legacy - kept for compatibility
struct NoiseRing: Identifiable {
    let id = UUID()
    let center: CLLocationCoordinate2D
    let radiusMeters: Double
    let dbLevel: Int
}

enum RoadType {
    case freeway      // US-101, I-280, I-880 → peak 78 dB
    case expressway   // SR-237, SR-85, Montague → peak 73 dB
    case arterial     // El Camino Real, Stevens Creek → peak 68 dB
}

struct Road {
    let name: String
    let type: RoadType
    let coordinates: [CLLocationCoordinate2D]

    var peakDb: Int {
        switch type {
        case .freeway:    return 78
        case .expressway: return 73
        case .arterial:   return 68
        }
    }

    /// Buffer distances (meters from road center) for each noise band
    var bufferLevels: [(dist: Double, dbOffset: Int)] {
        switch type {
        case .freeway:    return [(20,0),(60,4),(120,9),(250,15),(450,22),(800,30),(1300,38)]
        case .expressway: return [(15,0),(45,4),(90,9),(180,15),(350,22),(650,30)]
        case .arterial:   return [(10,0),(30,4),(70,9),(140,15),(280,22)]
        }
    }
}

class NoiseService: ObservableObject {
    @Published var zones: [NoiseZone] = []
    @Published var rings: [NoiseRing] = []  // legacy placeholder

    func fetch() {
        let roads = Self.bayAreaRoads()
        var result: [NoiseZone] = []
        for road in roads {
            result.append(contentsOf: Self.generateBands(road: road))
        }
        // Sort outermost (low dB) first so inner bands paint on top
        zones = result.sorted { $0.dbLevel < $1.dbLevel }
    }

    // MARK: - Road data (Full Bay Area coverage)
    static func bayAreaRoads() -> [Road] {
        return [
            // ─── SOUTH BAY (Santa Clara County) ───────────────────────────────
            Road(name: "US-101 South Bay", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.470, longitude: -121.953),
                CLLocationCoordinate2D(latitude: 37.450, longitude: -121.940),
                CLLocationCoordinate2D(latitude: 37.425, longitude: -121.930),
                CLLocationCoordinate2D(latitude: 37.405, longitude: -121.918),
                CLLocationCoordinate2D(latitude: 37.385, longitude: -121.905),
                CLLocationCoordinate2D(latitude: 37.365, longitude: -121.890),
                CLLocationCoordinate2D(latitude: 37.345, longitude: -121.872),
                CLLocationCoordinate2D(latitude: 37.325, longitude: -121.855),
                CLLocationCoordinate2D(latitude: 37.305, longitude: -121.835),
            ]),
            Road(name: "I-280 South Bay", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.438, longitude: -122.115),
                CLLocationCoordinate2D(latitude: 37.415, longitude: -122.095),
                CLLocationCoordinate2D(latitude: 37.393, longitude: -122.072),
                CLLocationCoordinate2D(latitude: 37.370, longitude: -122.048),
                CLLocationCoordinate2D(latitude: 37.348, longitude: -122.026),
                CLLocationCoordinate2D(latitude: 37.325, longitude: -122.005),
                CLLocationCoordinate2D(latitude: 37.305, longitude: -121.985),
            ]),
            Road(name: "I-880 South Bay", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.490, longitude: -121.953),
                CLLocationCoordinate2D(latitude: 37.468, longitude: -121.940),
                CLLocationCoordinate2D(latitude: 37.448, longitude: -121.928),
                CLLocationCoordinate2D(latitude: 37.428, longitude: -121.918),
                CLLocationCoordinate2D(latitude: 37.408, longitude: -121.910),
                CLLocationCoordinate2D(latitude: 37.385, longitude: -121.902),
                CLLocationCoordinate2D(latitude: 37.362, longitude: -121.893),
                CLLocationCoordinate2D(latitude: 37.340, longitude: -121.882),
            ]),
            Road(name: "SR-237", type: .expressway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.428, longitude: -122.030),
                CLLocationCoordinate2D(latitude: 37.423, longitude: -122.005),
                CLLocationCoordinate2D(latitude: 37.418, longitude: -121.978),
                CLLocationCoordinate2D(latitude: 37.416, longitude: -121.955),
                CLLocationCoordinate2D(latitude: 37.413, longitude: -121.930),
            ]),
            Road(name: "SR-85", type: .expressway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.358, longitude: -122.082),
                CLLocationCoordinate2D(latitude: 37.345, longitude: -122.062),
                CLLocationCoordinate2D(latitude: 37.332, longitude: -122.042),
                CLLocationCoordinate2D(latitude: 37.318, longitude: -122.022),
                CLLocationCoordinate2D(latitude: 37.305, longitude: -122.002),
                CLLocationCoordinate2D(latitude: 37.290, longitude: -121.982),
            ]),
            Road(name: "Montague Expy", type: .expressway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.415, longitude: -121.975),
                CLLocationCoordinate2D(latitude: 37.412, longitude: -121.940),
                CLLocationCoordinate2D(latitude: 37.408, longitude: -121.908),
                CLLocationCoordinate2D(latitude: 37.405, longitude: -121.882),
            ]),
            Road(name: "El Camino Real South", type: .arterial, coordinates: [
                CLLocationCoordinate2D(latitude: 37.388, longitude: -122.070),
                CLLocationCoordinate2D(latitude: 37.376, longitude: -122.048),
                CLLocationCoordinate2D(latitude: 37.365, longitude: -122.025),
                CLLocationCoordinate2D(latitude: 37.352, longitude: -122.000),
                CLLocationCoordinate2D(latitude: 37.341, longitude: -121.978),
                CLLocationCoordinate2D(latitude: 37.332, longitude: -121.958),
            ]),
            Road(name: "Lawrence Expy", type: .expressway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.408, longitude: -122.007),
                CLLocationCoordinate2D(latitude: 37.390, longitude: -122.006),
                CLLocationCoordinate2D(latitude: 37.370, longitude: -122.006),
                CLLocationCoordinate2D(latitude: 37.350, longitude: -122.005),
                CLLocationCoordinate2D(latitude: 37.330, longitude: -122.004),
            ]),
            Road(name: "SR-87 Guadalupe", type: .expressway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.360, longitude: -121.895),
                CLLocationCoordinate2D(latitude: 37.342, longitude: -121.892),
                CLLocationCoordinate2D(latitude: 37.322, longitude: -121.888),
                CLLocationCoordinate2D(latitude: 37.300, longitude: -121.882),
                CLLocationCoordinate2D(latitude: 37.280, longitude: -121.876),
            ]),

            // ─── PENINSULA (San Mateo County) ─────────────────────────────────
            Road(name: "US-101 Peninsula", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.558, longitude: -122.058),
                CLLocationCoordinate2D(latitude: 37.538, longitude: -122.048),
                CLLocationCoordinate2D(latitude: 37.518, longitude: -122.038),
                CLLocationCoordinate2D(latitude: 37.498, longitude: -122.025),
                CLLocationCoordinate2D(latitude: 37.478, longitude: -122.015),
                CLLocationCoordinate2D(latitude: 37.460, longitude: -122.005),
                CLLocationCoordinate2D(latitude: 37.442, longitude: -122.152),
                CLLocationCoordinate2D(latitude: 37.422, longitude: -122.172),
                CLLocationCoordinate2D(latitude: 37.402, longitude: -122.188),
            ]),
            Road(name: "I-280 Peninsula", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.678, longitude: -122.468),
                CLLocationCoordinate2D(latitude: 37.658, longitude: -122.448),
                CLLocationCoordinate2D(latitude: 37.638, longitude: -122.432),
                CLLocationCoordinate2D(latitude: 37.618, longitude: -122.412),
                CLLocationCoordinate2D(latitude: 37.598, longitude: -122.388),
                CLLocationCoordinate2D(latitude: 37.578, longitude: -122.368),
                CLLocationCoordinate2D(latitude: 37.558, longitude: -122.348),
                CLLocationCoordinate2D(latitude: 37.538, longitude: -122.328),
                CLLocationCoordinate2D(latitude: 37.510, longitude: -122.302),
                CLLocationCoordinate2D(latitude: 37.488, longitude: -122.278),
                CLLocationCoordinate2D(latitude: 37.462, longitude: -122.252),
                CLLocationCoordinate2D(latitude: 37.438, longitude: -122.225),
            ]),
            Road(name: "El Camino Real Peninsula", type: .arterial, coordinates: [
                CLLocationCoordinate2D(latitude: 37.548, longitude: -122.052),
                CLLocationCoordinate2D(latitude: 37.528, longitude: -122.042),
                CLLocationCoordinate2D(latitude: 37.508, longitude: -122.032),
                CLLocationCoordinate2D(latitude: 37.488, longitude: -122.022),
                CLLocationCoordinate2D(latitude: 37.468, longitude: -122.152),
                CLLocationCoordinate2D(latitude: 37.448, longitude: -122.168),
                CLLocationCoordinate2D(latitude: 37.428, longitude: -122.180),
            ]),
            Road(name: "SR-92 San Mateo Bridge", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.578, longitude: -122.052),
                CLLocationCoordinate2D(latitude: 37.572, longitude: -122.098),
                CLLocationCoordinate2D(latitude: 37.568, longitude: -122.148),
                CLLocationCoordinate2D(latitude: 37.562, longitude: -122.198),
                CLLocationCoordinate2D(latitude: 37.558, longitude: -122.238),
                CLLocationCoordinate2D(latitude: 37.558, longitude: -122.278),
                CLLocationCoordinate2D(latitude: 37.558, longitude: -122.318),
            ]),

            // ─── EAST BAY (Alameda / Contra Costa) ────────────────────────────
            Road(name: "I-880 Oakland-Hayward", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.808, longitude: -122.282),
                CLLocationCoordinate2D(latitude: 37.788, longitude: -122.268),
                CLLocationCoordinate2D(latitude: 37.768, longitude: -122.252),
                CLLocationCoordinate2D(latitude: 37.748, longitude: -122.238),
                CLLocationCoordinate2D(latitude: 37.718, longitude: -122.198),
                CLLocationCoordinate2D(latitude: 37.688, longitude: -122.162),
                CLLocationCoordinate2D(latitude: 37.658, longitude: -122.118),
                CLLocationCoordinate2D(latitude: 37.628, longitude: -122.088),
                CLLocationCoordinate2D(latitude: 37.598, longitude: -122.058),
                CLLocationCoordinate2D(latitude: 37.568, longitude: -122.028),
                CLLocationCoordinate2D(latitude: 37.540, longitude: -121.998),
            ]),
            Road(name: "I-580 Oakland-Livermore", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.818, longitude: -122.262),
                CLLocationCoordinate2D(latitude: 37.808, longitude: -122.232),
                CLLocationCoordinate2D(latitude: 37.792, longitude: -122.198),
                CLLocationCoordinate2D(latitude: 37.772, longitude: -122.162),
                CLLocationCoordinate2D(latitude: 37.752, longitude: -122.128),
                CLLocationCoordinate2D(latitude: 37.728, longitude: -122.088),
                CLLocationCoordinate2D(latitude: 37.712, longitude: -122.052),
                CLLocationCoordinate2D(latitude: 37.705, longitude: -122.012),
                CLLocationCoordinate2D(latitude: 37.700, longitude: -121.968),
                CLLocationCoordinate2D(latitude: 37.695, longitude: -121.918),
                CLLocationCoordinate2D(latitude: 37.685, longitude: -121.858),
            ]),
            Road(name: "I-80 East Bay", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.872, longitude: -122.292),
                CLLocationCoordinate2D(latitude: 37.868, longitude: -122.268),
                CLLocationCoordinate2D(latitude: 37.868, longitude: -122.238),
                CLLocationCoordinate2D(latitude: 37.870, longitude: -122.212),
                CLLocationCoordinate2D(latitude: 37.882, longitude: -122.182),
                CLLocationCoordinate2D(latitude: 37.898, longitude: -122.158),
                CLLocationCoordinate2D(latitude: 37.918, longitude: -122.138),
                CLLocationCoordinate2D(latitude: 37.938, longitude: -122.118),
                CLLocationCoordinate2D(latitude: 37.958, longitude: -122.092),
                CLLocationCoordinate2D(latitude: 37.978, longitude: -122.062),
                CLLocationCoordinate2D(latitude: 38.002, longitude: -122.038),
            ]),
            Road(name: "SR-24 Caldecott", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.822, longitude: -122.232),
                CLLocationCoordinate2D(latitude: 37.838, longitude: -122.212),
                CLLocationCoordinate2D(latitude: 37.852, longitude: -122.188),
                CLLocationCoordinate2D(latitude: 37.862, longitude: -122.162),
                CLLocationCoordinate2D(latitude: 37.868, longitude: -122.138),
                CLLocationCoordinate2D(latitude: 37.872, longitude: -122.112),
                CLLocationCoordinate2D(latitude: 37.878, longitude: -122.088),
            ]),
            Road(name: "I-680 Pleasanton-Walnut Creek", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.532, longitude: -121.922),
                CLLocationCoordinate2D(latitude: 37.560, longitude: -121.932),
                CLLocationCoordinate2D(latitude: 37.588, longitude: -121.942),
                CLLocationCoordinate2D(latitude: 37.618, longitude: -121.948),
                CLLocationCoordinate2D(latitude: 37.648, longitude: -121.948),
                CLLocationCoordinate2D(latitude: 37.678, longitude: -121.948),
                CLLocationCoordinate2D(latitude: 37.710, longitude: -121.952),
                CLLocationCoordinate2D(latitude: 37.742, longitude: -121.958),
                CLLocationCoordinate2D(latitude: 37.772, longitude: -121.962),
                CLLocationCoordinate2D(latitude: 37.802, longitude: -121.968),
                CLLocationCoordinate2D(latitude: 37.832, longitude: -121.978),
                CLLocationCoordinate2D(latitude: 37.862, longitude: -121.988),
                CLLocationCoordinate2D(latitude: 37.892, longitude: -121.998),
                CLLocationCoordinate2D(latitude: 37.922, longitude: -122.012),
            ]),
            Road(name: "SR-84 Dumbarton", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.512, longitude: -122.048),
                CLLocationCoordinate2D(latitude: 37.508, longitude: -122.088),
                CLLocationCoordinate2D(latitude: 37.504, longitude: -122.132),
                CLLocationCoordinate2D(latitude: 37.502, longitude: -122.178),
                CLLocationCoordinate2D(latitude: 37.498, longitude: -122.215),
            ]),
            Road(name: "I-238 San Leandro", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.718, longitude: -122.162),
                CLLocationCoordinate2D(latitude: 37.705, longitude: -122.148),
                CLLocationCoordinate2D(latitude: 37.695, longitude: -122.132),
                CLLocationCoordinate2D(latitude: 37.688, longitude: -122.118),
            ]),
            Road(name: "Hwy 4 Contra Costa", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.988, longitude: -121.808),
                CLLocationCoordinate2D(latitude: 37.988, longitude: -121.858),
                CLLocationCoordinate2D(latitude: 37.988, longitude: -121.908),
                CLLocationCoordinate2D(latitude: 37.988, longitude: -121.958),
                CLLocationCoordinate2D(latitude: 37.988, longitude: -122.008),
                CLLocationCoordinate2D(latitude: 37.988, longitude: -122.048),
                CLLocationCoordinate2D(latitude: 37.988, longitude: -122.092),
                CLLocationCoordinate2D(latitude: 37.978, longitude: -122.132),
            ]),

            // ─── SAN FRANCISCO ────────────────────────────────────────────────
            Road(name: "US-101 SF", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.808, longitude: -122.472),
                CLLocationCoordinate2D(latitude: 37.792, longitude: -122.452),
                CLLocationCoordinate2D(latitude: 37.778, longitude: -122.432),
                CLLocationCoordinate2D(latitude: 37.762, longitude: -122.412),
                CLLocationCoordinate2D(latitude: 37.748, longitude: -122.392),
                CLLocationCoordinate2D(latitude: 37.732, longitude: -122.378),
                CLLocationCoordinate2D(latitude: 37.712, longitude: -122.400),
                CLLocationCoordinate2D(latitude: 37.698, longitude: -122.418),
            ]),
            Road(name: "I-80 Bay Bridge-SF", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.798, longitude: -122.398),
                CLLocationCoordinate2D(latitude: 37.795, longitude: -122.368),
                CLLocationCoordinate2D(latitude: 37.792, longitude: -122.338),
                CLLocationCoordinate2D(latitude: 37.792, longitude: -122.308),
                CLLocationCoordinate2D(latitude: 37.798, longitude: -122.280),
                CLLocationCoordinate2D(latitude: 37.808, longitude: -122.258),
                CLLocationCoordinate2D(latitude: 37.820, longitude: -122.238),
                CLLocationCoordinate2D(latitude: 37.840, longitude: -122.220),
                CLLocationCoordinate2D(latitude: 37.858, longitude: -122.272),
                CLLocationCoordinate2D(latitude: 37.862, longitude: -122.302),
            ]),
            Road(name: "I-280 SF Segment", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.728, longitude: -122.420),
                CLLocationCoordinate2D(latitude: 37.738, longitude: -122.440),
                CLLocationCoordinate2D(latitude: 37.748, longitude: -122.458),
                CLLocationCoordinate2D(latitude: 37.758, longitude: -122.472),
                CLLocationCoordinate2D(latitude: 37.768, longitude: -122.482),
                CLLocationCoordinate2D(latitude: 37.780, longitude: -122.488),
            ]),
            Road(name: "19th Ave SF", type: .arterial, coordinates: [
                CLLocationCoordinate2D(latitude: 37.776, longitude: -122.477),
                CLLocationCoordinate2D(latitude: 37.762, longitude: -122.476),
                CLLocationCoordinate2D(latitude: 37.748, longitude: -122.475),
                CLLocationCoordinate2D(latitude: 37.732, longitude: -122.476),
                CLLocationCoordinate2D(latitude: 37.718, longitude: -122.477),
            ]),
            Road(name: "Bayshore Freeway SF", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.695, longitude: -122.418),
                CLLocationCoordinate2D(latitude: 37.710, longitude: -122.405),
                CLLocationCoordinate2D(latitude: 37.718, longitude: -122.395),
                CLLocationCoordinate2D(latitude: 37.728, longitude: -122.392),
                CLLocationCoordinate2D(latitude: 37.740, longitude: -122.385),
                CLLocationCoordinate2D(latitude: 37.752, longitude: -122.382),
            ]),

            // ─── NORTH BAY (Marin / Sonoma) ────────────────────────────────────
            Road(name: "US-101 Marin", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.838, longitude: -122.502),
                CLLocationCoordinate2D(latitude: 37.858, longitude: -122.512),
                CLLocationCoordinate2D(latitude: 37.878, longitude: -122.518),
                CLLocationCoordinate2D(latitude: 37.898, longitude: -122.522),
                CLLocationCoordinate2D(latitude: 37.918, longitude: -122.528),
                CLLocationCoordinate2D(latitude: 37.940, longitude: -122.528),
                CLLocationCoordinate2D(latitude: 37.960, longitude: -122.518),
                CLLocationCoordinate2D(latitude: 37.978, longitude: -122.508),
                CLLocationCoordinate2D(latitude: 37.998, longitude: -122.498),
                CLLocationCoordinate2D(latitude: 38.018, longitude: -122.488),
            ]),
            Road(name: "US-101 Sonoma", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 38.018, longitude: -122.488),
                CLLocationCoordinate2D(latitude: 38.048, longitude: -122.478),
                CLLocationCoordinate2D(latitude: 38.080, longitude: -122.468),
                CLLocationCoordinate2D(latitude: 38.112, longitude: -122.462),
                CLLocationCoordinate2D(latitude: 38.142, longitude: -122.468),
                CLLocationCoordinate2D(latitude: 38.168, longitude: -122.478),
                CLLocationCoordinate2D(latitude: 38.198, longitude: -122.492),
                CLLocationCoordinate2D(latitude: 38.232, longitude: -122.508),
                CLLocationCoordinate2D(latitude: 38.262, longitude: -122.518),
                CLLocationCoordinate2D(latitude: 38.298, longitude: -122.528),
            ]),
            Road(name: "SR-37 Novato-Vallejo", type: .expressway, coordinates: [
                CLLocationCoordinate2D(latitude: 38.068, longitude: -122.538),
                CLLocationCoordinate2D(latitude: 38.068, longitude: -122.498),
                CLLocationCoordinate2D(latitude: 38.068, longitude: -122.458),
                CLLocationCoordinate2D(latitude: 38.068, longitude: -122.418),
                CLLocationCoordinate2D(latitude: 38.068, longitude: -122.378),
                CLLocationCoordinate2D(latitude: 38.078, longitude: -122.338),
                CLLocationCoordinate2D(latitude: 38.088, longitude: -122.298),
            ]),
        ]
    }

    // MARK: - Generate buffer strips along each road segment
    static func generateBands(road: Road) -> [NoiseZone] {
        var zones: [NoiseZone] = []
        let coords = road.coordinates
        guard coords.count >= 2 else { return [] }

        for level in road.bufferLevels {
            var leftSide:  [CLLocationCoordinate2D] = []
            var rightSide: [CLLocationCoordinate2D] = []

            for i in 0..<coords.count {
                // Get bearing: use segment before/after for smoother joins
                let brg: Double
                if i == 0 {
                    brg = bearing(from: coords[0], to: coords[1])
                } else if i == coords.count - 1 {
                    brg = bearing(from: coords[i-1], to: coords[i])
                } else {
                    let b1 = bearing(from: coords[i-1], to: coords[i])
                    let b2 = bearing(from: coords[i], to: coords[i+1])
                    brg = (b1 + b2) / 2
                }

                leftSide.append(offset(coords[i], bearing: brg - 90, distanceM: level.dist))
                rightSide.append(offset(coords[i], bearing: brg + 90, distanceM: level.dist))
            }

            // Build polygon: left side forward + right side backward
            let polygon = leftSide + rightSide.reversed()
            let db = max(40, road.peakDb - level.dbOffset)
            zones.append(NoiseZone(polygon: polygon, dbLevel: db))
        }
        return zones
    }

    // MARK: - Geometry helpers

    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude  * .pi / 180
        let lat2 = b.latitude  * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x) * 180 / .pi
    }

    static func offset(_ c: CLLocationCoordinate2D, bearing brg: Double, distanceM d: Double) -> CLLocationCoordinate2D {
        let R = 6371000.0
        let dist = d / R
        let b = brg * .pi / 180
        let lat1 = c.latitude  * .pi / 180
        let lon1 = c.longitude * .pi / 180
        let lat2 = asin(sin(lat1)*cos(dist) + cos(lat1)*sin(dist)*cos(b))
        let lon2 = lon1 + atan2(sin(b)*sin(dist)*cos(lat1), cos(dist) - sin(lat1)*sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * (180.0 / Double.pi), longitude: lon2 * (180.0 / Double.pi))
    }

    static func color(for db: Int) -> (r: Double, g: Double, b: Double) {
        switch db {
        case ..<50:   return (1.0, 1.0, 0.4)
        case 50..<55: return (1.0, 0.92, 0.1)
        case 55..<60: return (1.0, 0.72, 0.0)
        case 60..<65: return (1.0, 0.45, 0.0)
        case 65..<70: return (0.92, 0.1, 0.3)
        case 70..<80: return (0.60, 0.0, 0.72)
        default:      return (0.28, 0.0, 0.50)
        }
    }
}
