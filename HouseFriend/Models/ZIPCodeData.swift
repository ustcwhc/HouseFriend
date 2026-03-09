import Foundation
import MapKit

struct ZIPDemographics {
    let population: Int
    let medianAge: Double
    let medianIncome: Int
    let white, hispanic, asian, black, other: Int
    let incUnder50, inc50_100, inc100_150, inc150_200, inc200Plus: Int
    let age_under18, age_18_34, age_35_54, age_55_74, age_75Plus: Int
}

struct ZIPCodeRegion: Identifiable {
    let id: String
    let polygon: [CLLocationCoordinate2D]
    let center: CLLocationCoordinate2D
    let demographics: ZIPDemographics
}

// Loads bayarea_zips.json from the app bundle at runtime.
// Zero compile-time cost — no giant Swift literal arrays.
struct ZIPCodeData {
    static func allZIPs() -> [ZIPCodeRegion] {
        guard let url = Bundle.main.url(forResource: "bayarea_zips", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return raw.compactMap { parseRegion($0) }
    }

    private static func parseRegion(_ d: [String: Any]) -> ZIPCodeRegion? {
        guard let id   = d["id"]      as? String,
              let poly = d["polygon"] as? [[Double]],
              let ctr  = d["center"]  as? [Double],
              ctr.count == 2,
              let dem  = d["demographics"] as? [String: Any]
        else { return nil }

        let polygon = poly.compactMap { pt -> CLLocationCoordinate2D? in
            guard pt.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pt[1], longitude: pt[0])
        }
        guard polygon.count >= 4 else { return nil }

        let center = CLLocationCoordinate2D(latitude: ctr[1], longitude: ctr[0])

        func i(_ key: String) -> Int { dem[key] as? Int ?? 0 }
        func db(_ key: String) -> Double { dem[key] as? Double ?? Double(i(key)) }

        let demographics = ZIPDemographics(
            population:   i("population"),
            medianAge:    db("medianAge"),
            medianIncome: i("medianIncome"),
            white:     i("white"),    hispanic: i("hispanic"),
            asian:     i("asian"),    black:    i("black"),  other: i("other"),
            incUnder50:  i("incUnder50"),  inc50_100:  i("inc50_100"),
            inc100_150:  i("inc100_150"), inc150_200: i("inc150_200"),
            inc200Plus:  i("inc200Plus"),
            age_under18: i("age_under18"), age_18_34:  i("age_18_34"),
            age_35_54:   i("age_35_54"),  age_55_74:  i("age_55_74"),
            age_75Plus:  i("age_75Plus")
        )
        return ZIPCodeRegion(id: id, polygon: polygon, center: center, demographics: demographics)
    }
}
