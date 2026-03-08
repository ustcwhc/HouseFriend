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

    // MARK: - Road data (Bay Area major roads)
    static func bayAreaRoads() -> [Road] {
        return [
            // US-101 San Jose / Santa Clara / Sunnyvale
            Road(name: "US-101", type: .freeway, coordinates: [
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
            // I-280
            Road(name: "I-280", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.438, longitude: -122.115),
                CLLocationCoordinate2D(latitude: 37.415, longitude: -122.095),
                CLLocationCoordinate2D(latitude: 37.393, longitude: -122.072),
                CLLocationCoordinate2D(latitude: 37.370, longitude: -122.048),
                CLLocationCoordinate2D(latitude: 37.348, longitude: -122.026),
                CLLocationCoordinate2D(latitude: 37.325, longitude: -122.005),
                CLLocationCoordinate2D(latitude: 37.305, longitude: -121.985),
            ]),
            // I-880
            Road(name: "I-880", type: .freeway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.490, longitude: -121.953),
                CLLocationCoordinate2D(latitude: 37.468, longitude: -121.940),
                CLLocationCoordinate2D(latitude: 37.448, longitude: -121.928),
                CLLocationCoordinate2D(latitude: 37.428, longitude: -121.918),
                CLLocationCoordinate2D(latitude: 37.408, longitude: -121.910),
                CLLocationCoordinate2D(latitude: 37.385, longitude: -121.902),
                CLLocationCoordinate2D(latitude: 37.362, longitude: -121.893),
                CLLocationCoordinate2D(latitude: 37.340, longitude: -121.882),
            ]),
            // SR-237
            Road(name: "SR-237", type: .expressway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.428, longitude: -122.030),
                CLLocationCoordinate2D(latitude: 37.423, longitude: -122.005),
                CLLocationCoordinate2D(latitude: 37.418, longitude: -121.978),
                CLLocationCoordinate2D(latitude: 37.416, longitude: -121.955),
                CLLocationCoordinate2D(latitude: 37.413, longitude: -121.930),
            ]),
            // SR-85
            Road(name: "SR-85", type: .expressway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.358, longitude: -122.082),
                CLLocationCoordinate2D(latitude: 37.345, longitude: -122.062),
                CLLocationCoordinate2D(latitude: 37.332, longitude: -122.042),
                CLLocationCoordinate2D(latitude: 37.318, longitude: -122.022),
                CLLocationCoordinate2D(latitude: 37.305, longitude: -122.002),
                CLLocationCoordinate2D(latitude: 37.290, longitude: -121.982),
            ]),
            // Montague Expressway
            Road(name: "Montague Expy", type: .expressway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.415, longitude: -121.975),
                CLLocationCoordinate2D(latitude: 37.412, longitude: -121.940),
                CLLocationCoordinate2D(latitude: 37.408, longitude: -121.908),
                CLLocationCoordinate2D(latitude: 37.405, longitude: -121.882),
            ]),
            // El Camino Real (Sunnyvale / Santa Clara)
            Road(name: "El Camino Real", type: .arterial, coordinates: [
                CLLocationCoordinate2D(latitude: 37.388, longitude: -122.070),
                CLLocationCoordinate2D(latitude: 37.376, longitude: -122.048),
                CLLocationCoordinate2D(latitude: 37.365, longitude: -122.025),
                CLLocationCoordinate2D(latitude: 37.352, longitude: -122.000),
                CLLocationCoordinate2D(latitude: 37.341, longitude: -121.978),
                CLLocationCoordinate2D(latitude: 37.332, longitude: -121.958),
            ]),
            // Stevens Creek Blvd
            Road(name: "Stevens Creek Blvd", type: .arterial, coordinates: [
                CLLocationCoordinate2D(latitude: 37.334, longitude: -122.073),
                CLLocationCoordinate2D(latitude: 37.326, longitude: -122.050),
                CLLocationCoordinate2D(latitude: 37.320, longitude: -122.025),
                CLLocationCoordinate2D(latitude: 37.316, longitude: -122.000),
                CLLocationCoordinate2D(latitude: 37.312, longitude: -121.978),
            ]),
            // Lawrence Expressway
            Road(name: "Lawrence Expy", type: .expressway, coordinates: [
                CLLocationCoordinate2D(latitude: 37.408, longitude: -122.007),
                CLLocationCoordinate2D(latitude: 37.390, longitude: -122.006),
                CLLocationCoordinate2D(latitude: 37.370, longitude: -122.006),
                CLLocationCoordinate2D(latitude: 37.350, longitude: -122.005),
                CLLocationCoordinate2D(latitude: 37.330, longitude: -122.004),
                CLLocationCoordinate2D(latitude: 37.310, longitude: -122.003),
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
