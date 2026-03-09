import Foundation
import MapKit

/// Computes neighborhood scores for all 10 layers given service data.
/// Extracted from ContentView to keep the view layer thin and enable unit testing.
enum ScoringService {

    struct ScoreResult {
        let score: Int
        let label: String
    }

    // MARK: - Per-layer scoring

    static func earthquakeScore(events: [EarthquakeEvent], coord: CLLocationCoordinate2D) -> ScoreResult {
        let nearby = events.filter {
            abs($0.coordinate.latitude - coord.latitude) < 0.2 &&
            abs($0.coordinate.longitude - coord.longitude) < 0.25
        }.count
        let score = max(20, 100 - nearby * 12)
        let label = nearby == 0 ? "Low Risk" : nearby < 3 ? "Some Activity" : "High Activity"
        return ScoreResult(score: score, label: label)
    }

    static func superfundScore(sites: [SuperfundSite], coord: CLLocationCoordinate2D) -> ScoreResult {
        let nearbySites = sites.filter {
            abs($0.coordinate.latitude - coord.latitude) < 0.12 &&
            abs($0.coordinate.longitude - coord.longitude) < 0.15
        }.sorted { ($0.distanceMiles ?? 99) < ($1.distanceMiles ?? 99) }
        let score = max(10, 100 - nearbySites.count * 22)
        let label: String
        if nearbySites.isEmpty {
            label = "No EPA sites nearby"
        } else if let closest = nearbySites.first, let dist = closest.distanceMiles {
            label = "\(nearbySites.count) sites · closest \(String(format:"%.1f",dist))mi"
        } else {
            label = "\(nearbySites.count) EPA site(s) nearby"
        }
        return ScoreResult(score: score, label: label)
    }

    static func airQualityScore(data: AirQualityData?) -> ScoreResult {
        let aqi = data?.aqi ?? 55
        let score = aqi <= 50 ? 95 : aqi <= 100 ? 75 : aqi <= 150 ? 50 : 25
        let label = data?.category ?? "Moderate"
        return ScoreResult(score: score, label: label)
    }

    static func crimeScore(stats: CrimeStats) -> ScoreResult {
        ScoreResult(score: stats.score, label: stats.label)
    }

    static func fireScore(zones: [FireHazardZone], coord: CLLocationCoordinate2D) -> ScoreResult {
        var worstSeverity = "None"
        var minDist = Double.infinity
        for zone in zones {
            for pt in zone.coordinates {
                let d = sqrt(pow(pt.latitude - coord.latitude, 2) + pow(pt.longitude - coord.longitude, 2))
                if d < minDist {
                    minDist = d
                    worstSeverity = zone.severity
                }
            }
        }
        for zone in zones {
            if pointInPolygon(coord, polygon: zone.coordinates) {
                worstSeverity = zone.severity
                minDist = 0
                break
            }
        }
        let safeMinDist = minDist.isFinite ? minDist : 999.0
        let score: Int
        let label: String
        switch worstSeverity {
        case "Extreme":
            score = 25; label = "Extreme Fire Risk"
        case "Very High":
            score = safeMinDist < 0.05 ? 40 : 55; label = "Very High Fire Risk"
        case "High":
            score = safeMinDist < 0.05 ? 60 : 72; label = "High Fire Risk"
        default:
            score = 88; label = "Low Fire Risk"
        }
        return ScoreResult(score: score, label: label)
    }

    static func schoolScore(schools: [School], coord: CLLocationCoordinate2D) -> ScoreResult {
        let nearbySchools = schools.filter {
            abs($0.coordinate.latitude - coord.latitude) < 0.05 &&
            abs($0.coordinate.longitude - coord.longitude) < 0.06
        }.sorted {
            let d0 = pow($0.coordinate.latitude-coord.latitude,2)+pow($0.coordinate.longitude-coord.longitude,2)
            let d1 = pow($1.coordinate.latitude-coord.latitude,2)+pow($1.coordinate.longitude-coord.longitude,2)
            return d0 < d1
        }
        let avgRating = nearbySchools.isEmpty ? 6 :
            nearbySchools.map(\.rating).reduce(0,+) / nearbySchools.count
        let score = min(100, avgRating * 10 + (nearbySchools.count > 5 ? 5 : 0))
        let label: String
        if nearbySchools.isEmpty {
            label = "No schools found nearby"
        } else {
            label = "\(nearbySchools.count) schools · avg \(avgRating)/10"
        }
        return ScoreResult(score: score, label: label)
    }

    static func noiseScore(zones: [NoiseZone], roads: [NoiseRoad], coord: CLLocationCoordinate2D) -> ScoreResult {
        var loudestDb = 40

        // Check polygon zones (legacy, may be empty)
        for zone in zones {
            if pointInPolygon(coord, polygon: zone.polygon) {
                if zone.dbLevel > loudestDb { loudestDb = zone.dbLevel }
            }
        }

        // Check proximity to noise roads (primary data source)
        for road in roads {
            let coords = road.coordinates
            for j in 0..<max(0, coords.count - 1) {
                let p1 = coords[j]; let p2 = coords[j + 1]
                let dx = p2.longitude - p1.longitude
                let dy = p2.latitude  - p1.latitude
                let lenSq = dx * dx + dy * dy
                let t = lenSq > 0 ? max(0, min(1, ((coord.longitude - p1.longitude) * dx + (coord.latitude - p1.latitude) * dy) / lenSq)) : 0
                let nearLat = p1.latitude + t * dy
                let nearLon = p1.longitude + t * dx
                let distDeg = sqrt(pow(coord.latitude - nearLat, 2) + pow(coord.longitude - nearLon, 2))
                let distMiles = distDeg * 69.0
                // Sound attenuates with distance: reduce dB by ~6dB per doubling of distance
                // At 0.05mi (~80m) from road, use full dB; attenuate beyond
                if distMiles < 0.5 {
                    let attenuation = distMiles < 0.05 ? 0 : Int(6.0 * log2(max(1, distMiles / 0.05)))
                    let effectiveDb = max(40, road.dbLevel - attenuation)
                    if effectiveDb > loudestDb { loudestDb = effectiveDb }
                }
            }
        }

        // Fallback: check nearest zone vertex if still at baseline
        if loudestDb == 40 {
            for zone in zones {
                for pt in zone.polygon {
                    let d = sqrt(pow(pt.latitude - coord.latitude, 2) + pow(pt.longitude - coord.longitude, 2))
                    if d.isFinite {
                        let adj = Int(d * 500)
                        loudestDb = max(loudestDb, zone.dbLevel - adj)
                    }
                }
            }
        }

        let score = max(10, 100 - max(0, loudestDb - 40) * 2)
        let label: String
        switch loudestDb {
        case 75...: label = "Very Loud (>\(loudestDb)dB)"
        case 65...: label = "Loud (~\(loudestDb)dB)"
        case 55...: label = "Moderate (~\(loudestDb)dB)"
        default:    label = "Quiet (<55dB)"
        }
        return ScoreResult(score: score, label: label)
    }

    static func electricLineScore(lines: [ElectricLine], coord: CLLocationCoordinate2D) -> ScoreResult {
        var minLineDistDeg = Double.infinity
        var closestVoltage = 0
        for line in lines {
            let coords = line.coordinates
            for j in 0..<max(0, coords.count-1) {
                let p1 = coords[j]; let p2 = coords[j+1]
                let dx = p2.longitude - p1.longitude
                let dy = p2.latitude  - p1.latitude
                let lenSq = dx*dx + dy*dy
                let t = lenSq > 0 ? max(0, min(1, ((coord.longitude-p1.longitude)*dx + (coord.latitude-p1.latitude)*dy)/lenSq)) : 0
                let nearLat = p1.latitude + t*dy
                let nearLon = p1.longitude + t*dx
                let d = sqrt(pow(coord.latitude-nearLat,2) + pow(coord.longitude-nearLon,2))
                if d < minLineDistDeg { minLineDistDeg = d; closestVoltage = line.voltage }
            }
        }
        guard minLineDistDeg.isFinite else {
            return ScoreResult(score: 75, label: "Data loading...")
        }
        let distMiles = minLineDistDeg * 69.0
        let score: Int
        let label: String
        if distMiles < 0.1 {
            score = 45; label = "Very Close (\(closestVoltage)kV line)"
        } else if distMiles < 0.3 {
            score = 62; label = "Nearby (\(closestVoltage)kV, \(String(format:"%.1f",distMiles))mi)"
        } else if distMiles < 1.0 {
            score = 78; label = "\(String(format:"%.1f",distMiles))mi to nearest line"
        } else {
            score = 92; label = "Low Exposure (>\(min(999, Int(distMiles)))mi)"
        }
        return ScoreResult(score: score, label: label)
    }

    static func populationScore(info: PopulationInfo?) -> ScoreResult {
        if let pop = info {
            let score = max(20, min(95, 100 - (pop.density - 3000) / 120))
            let densityK = String(format: "%.1f", Double(pop.density) / 1000.0)
            return ScoreResult(score: score, label: "\(densityK)k/sq mi · \(pop.cityName)")
        }
        return ScoreResult(score: 70, label: "~5k / sq mi")
    }

    static func supportiveHomeScore(facilities: [SupportiveHousingFacility], coord: CLLocationCoordinate2D) -> ScoreResult {
        let cnt = facilities.filter {
            abs($0.coordinate.latitude - coord.latitude) < 0.05 &&
            abs($0.coordinate.longitude - coord.longitude) < 0.06
        }.count
        return ScoreResult(score: max(40, 100 - cnt * 15), label: "\(cnt) facilities nearby")
    }

    // MARK: - Geometry

    static func pointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude; let yi = polygon[i].latitude
            let xj = polygon[j].longitude; let yj = polygon[j].latitude
            if ((yi > point.latitude) != (yj > point.latitude)) &&
               (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
                inside = !inside
            }
            j = i
        }
        return inside
    }
}
