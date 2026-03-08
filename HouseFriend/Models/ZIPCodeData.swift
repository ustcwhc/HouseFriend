import Foundation
import CoreLocation

// MARK: - Models

struct ZIPDemographics {
    let zip: String
    let city: String
    let totalPopulation: Int
    let medianHouseholdIncome: Int
    let medianAge: Double

    // Race/Ethnicity (%)
    let white: Double
    let hispanic: Double
    let asian: Double
    let black: Double
    let other: Double

    // Household Income brackets (%)
    let incomeUnder25k: Double
    let income25to50k: Double
    let income50to75k: Double
    let income75to100k: Double
    let income100to150k: Double
    let incomeOver150k: Double

    // Age distribution (%)
    let ageUnder18: Double
    let age18to34: Double
    let age35to54: Double
    let age55to64: Double
    let age65plus: Double
}

struct ZIPCodeRegion: Identifiable {
    let id: String  // zip code
    let center: CLLocationCoordinate2D
    let polygon: [CLLocationCoordinate2D]
    let demographics: ZIPDemographics
}

// MARK: - Data

enum ZIPCodeData {
    static func allZIPs() -> [ZIPCodeRegion] {
        return [
            // ── San Francisco ─────────────────────────────────────────────
            zip("94102", "SF Tenderloin",       lat: 37.781, lon: -122.415,
                dlat: 0.018, dlon: 0.022,
                pop: 28000, mhi: 32000, mAge: 36.2,
                race: (19, 30, 28, 16, 7),
                income: (38, 24, 16, 10, 8, 4),
                age: (9, 38, 31, 12, 10)),

            zip("94103", "SF SoMa",             lat: 37.772, lon: -122.410,
                dlat: 0.016, dlon: 0.022,
                pop: 35000, mhi: 85000, mAge: 34.5,
                race: (42, 15, 30, 8, 5),
                income: (10, 14, 18, 16, 22, 20),
                age: (5, 45, 35, 9, 6)),

            zip("94107", "SF Potrero/Dogpatch", lat: 37.760, lon: -122.395,
                dlat: 0.016, dlon: 0.020,
                pop: 30000, mhi: 120000, mAge: 35.0,
                race: (55, 10, 22, 8, 5),
                income: (5, 8, 12, 15, 25, 35),
                age: (8, 42, 36, 8, 6)),

            zip("94110", "SF Mission",          lat: 37.750, lon: -122.415,
                dlat: 0.018, dlon: 0.020,
                pop: 52000, mhi: 78000, mAge: 35.8,
                race: (35, 40, 12, 8, 5),
                income: (12, 18, 20, 18, 18, 14),
                age: (15, 38, 32, 9, 6)),

            zip("94115", "SF Pacific Heights",  lat: 37.788, lon: -122.439,
                dlat: 0.018, dlon: 0.022,
                pop: 34000, mhi: 155000, mAge: 40.2,
                race: (68, 6, 18, 4, 4),
                income: (4, 5, 8, 10, 18, 55),
                age: (12, 22, 35, 16, 15)),

            zip("94117", "SF Haight/Ashbury",   lat: 37.770, lon: -122.448,
                dlat: 0.016, dlon: 0.020,
                pop: 28000, mhi: 115000, mAge: 37.5,
                race: (58, 10, 18, 8, 6),
                income: (6, 10, 14, 16, 24, 30),
                age: (10, 30, 38, 12, 10)),

            zip("94124", "SF Bayview",          lat: 37.727, lon: -122.390,
                dlat: 0.022, dlon: 0.024,
                pop: 40000, mhi: 55000, mAge: 35.0,
                race: (12, 25, 8, 48, 7),
                income: (22, 28, 22, 14, 10, 4),
                age: (22, 30, 28, 10, 10)),

            // ── Oakland ───────────────────────────────────────────────────
            zip("94601", "Oakland Fruitvale",   lat: 37.768, lon: -122.222,
                dlat: 0.020, dlon: 0.024,
                pop: 45000, mhi: 52000, mAge: 33.5,
                race: (10, 58, 10, 18, 4),
                income: (25, 30, 22, 12, 8, 3),
                age: (24, 32, 28, 9, 7)),

            zip("94607", "West Oakland",        lat: 37.812, lon: -122.290,
                dlat: 0.018, dlon: 0.022,
                pop: 30000, mhi: 45000, mAge: 34.0,
                race: (18, 32, 10, 35, 5),
                income: (30, 28, 20, 10, 8, 4),
                age: (20, 35, 28, 10, 7)),

            zip("94610", "Oakland Piedmont Ave",lat: 37.822, lon: -122.240,
                dlat: 0.018, dlon: 0.022,
                pop: 28000, mhi: 110000, mAge: 39.5,
                race: (62, 8, 18, 6, 6),
                income: (5, 8, 12, 15, 25, 35),
                age: (14, 25, 35, 14, 12)),

            zip("94611", "Oakland Montclair",   lat: 37.840, lon: -122.218,
                dlat: 0.022, dlon: 0.028,
                pop: 32000, mhi: 125000, mAge: 42.0,
                race: (65, 6, 20, 4, 5),
                income: (4, 5, 8, 12, 22, 49),
                age: (18, 18, 32, 16, 16)),

            zip("94618", "Oakland Rockridge",   lat: 37.842, lon: -122.255,
                dlat: 0.016, dlon: 0.020,
                pop: 18000, mhi: 130000, mAge: 41.0,
                race: (68, 5, 18, 5, 4),
                income: (4, 5, 8, 10, 22, 51),
                age: (16, 20, 34, 16, 14)),

            // ── Berkeley ──────────────────────────────────────────────────
            zip("94703", "Berkeley Central",    lat: 37.868, lon: -122.278,
                dlat: 0.018, dlon: 0.022,
                pop: 22000, mhi: 78000, mAge: 34.0,
                race: (45, 12, 18, 18, 7),
                income: (14, 16, 18, 16, 20, 16),
                age: (10, 40, 28, 12, 10)),

            zip("94705", "Berkeley Elmwood",    lat: 37.858, lon: -122.250,
                dlat: 0.016, dlon: 0.020,
                pop: 15000, mhi: 120000, mAge: 42.0,
                race: (65, 5, 20, 6, 4),
                income: (5, 6, 10, 14, 25, 40),
                age: (14, 22, 32, 16, 16)),

            // ── Richmond ──────────────────────────────────────────────────
            zip("94801", "Richmond Central",    lat: 37.935, lon: -122.355,
                dlat: 0.022, dlon: 0.026,
                pop: 38000, mhi: 48000, mAge: 33.5,
                race: (12, 42, 14, 26, 6),
                income: (28, 30, 20, 10, 8, 4),
                age: (24, 32, 28, 9, 7)),

            // ── San Mateo County ──────────────────────────────────────────
            zip("94301", "Palo Alto North",     lat: 37.445, lon: -122.160,
                dlat: 0.020, dlon: 0.024,
                pop: 25000, mhi: 185000, mAge: 41.5,
                race: (52, 4, 36, 2, 6),
                income: (3, 4, 6, 8, 18, 61),
                age: (18, 18, 32, 16, 16)),

            zip("94306", "Palo Alto South",     lat: 37.415, lon: -122.125,
                dlat: 0.020, dlon: 0.024,
                pop: 18000, mhi: 200000, mAge: 43.0,
                race: (48, 5, 38, 2, 7),
                income: (2, 3, 5, 8, 16, 66),
                age: (20, 15, 32, 18, 15)),

            zip("94402", "San Mateo Central",   lat: 37.558, lon: -122.318,
                dlat: 0.018, dlon: 0.022,
                pop: 30000, mhi: 105000, mAge: 38.5,
                race: (45, 20, 28, 4, 3),
                income: (6, 10, 14, 16, 24, 30),
                age: (15, 28, 35, 12, 10)),

            zip("94065", "Redwood Shores",      lat: 37.535, lon: -122.252,
                dlat: 0.016, dlon: 0.020,
                pop: 15000, mhi: 175000, mAge: 38.0,
                race: (40, 8, 46, 2, 4),
                income: (2, 4, 6, 10, 22, 56),
                age: (18, 25, 40, 10, 7)),

            // ── Santa Clara County ────────────────────────────────────────
            zip("95014", "Cupertino",           lat: 37.323, lon: -122.032,
                dlat: 0.022, dlon: 0.028,
                pop: 58000, mhi: 168000, mAge: 39.5,
                race: (20, 4, 70, 1, 5),
                income: (2, 3, 5, 8, 18, 64),
                age: (20, 18, 34, 14, 14)),

            zip("94087", "Sunnyvale West",      lat: 37.368, lon: -122.038,
                dlat: 0.020, dlon: 0.024,
                pop: 42000, mhi: 145000, mAge: 37.5,
                race: (30, 10, 52, 3, 5),
                income: (3, 5, 8, 12, 24, 48),
                age: (16, 28, 38, 10, 8)),

            zip("94040", "Mountain View",       lat: 37.388, lon: -122.075,
                dlat: 0.020, dlon: 0.024,
                pop: 38000, mhi: 130000, mAge: 36.5,
                race: (38, 12, 42, 3, 5),
                income: (4, 6, 10, 14, 26, 40),
                age: (12, 32, 38, 10, 8)),

            zip("95125", "San Jose Willow Glen",lat: 37.298, lon: -121.900,
                dlat: 0.020, dlon: 0.024,
                pop: 45000, mhi: 115000, mAge: 39.0,
                race: (52, 22, 18, 4, 4),
                income: (5, 8, 12, 16, 26, 33),
                age: (18, 24, 34, 12, 12)),

            zip("95116", "San Jose East",       lat: 37.350, lon: -121.855,
                dlat: 0.020, dlon: 0.024,
                pop: 55000, mhi: 58000, mAge: 32.5,
                race: (8, 62, 22, 4, 4),
                income: (22, 28, 24, 14, 8, 4),
                age: (26, 32, 28, 8, 6)),

            zip("95110", "San Jose Downtown",   lat: 37.337, lon: -121.893,
                dlat: 0.018, dlon: 0.022,
                pop: 32000, mhi: 72000, mAge: 34.0,
                race: (18, 42, 28, 8, 4),
                income: (16, 22, 22, 16, 14, 10),
                age: (15, 38, 30, 10, 7)),

            zip("95120", "San Jose Almaden",    lat: 37.234, lon: -121.875,
                dlat: 0.026, dlon: 0.030,
                pop: 42000, mhi: 165000, mAge: 44.0,
                race: (55, 8, 30, 2, 5),
                income: (2, 3, 6, 10, 22, 57),
                age: (22, 16, 32, 16, 14)),

            // ── Contra Costa ──────────────────────────────────────────────
            zip("94596", "Walnut Creek",        lat: 37.908, lon: -122.065,
                dlat: 0.022, dlon: 0.028,
                pop: 35000, mhi: 115000, mAge: 44.5,
                race: (72, 7, 14, 3, 4),
                income: (4, 6, 10, 14, 24, 42),
                age: (14, 18, 30, 18, 20)),

            zip("94509", "Antioch",             lat: 37.996, lon: -121.808,
                dlat: 0.026, dlon: 0.030,
                pop: 75000, mhi: 72000, mAge: 34.0,
                race: (28, 32, 14, 20, 6),
                income: (14, 22, 24, 18, 14, 8),
                age: (26, 28, 28, 10, 8)),

            zip("94523", "Pleasant Hill",       lat: 37.948, lon: -122.062,
                dlat: 0.018, dlon: 0.022,
                pop: 28000, mhi: 98000, mAge: 40.0,
                race: (68, 10, 14, 4, 4),
                income: (6, 8, 14, 18, 26, 28),
                age: (18, 22, 32, 14, 14)),

            // ── Alameda County ────────────────────────────────────────────
            zip("94538", "Fremont Central",     lat: 37.548, lon: -121.982,
                dlat: 0.022, dlon: 0.026,
                pop: 52000, mhi: 118000, mAge: 38.0,
                race: (18, 18, 52, 6, 6),
                income: (4, 6, 10, 14, 28, 38),
                age: (18, 25, 36, 12, 9)),

            zip("94541", "Hayward North",       lat: 37.672, lon: -122.080,
                dlat: 0.020, dlon: 0.024,
                pop: 45000, mhi: 68000, mAge: 34.5,
                race: (15, 42, 22, 14, 7),
                income: (16, 24, 24, 16, 12, 8),
                age: (22, 32, 28, 10, 8)),

            zip("94577", "San Leandro",         lat: 37.725, lon: -122.158,
                dlat: 0.020, dlon: 0.024,
                pop: 38000, mhi: 78000, mAge: 38.5,
                race: (22, 30, 30, 12, 6),
                income: (10, 18, 22, 18, 18, 14),
                age: (18, 28, 32, 12, 10)),

            // ── Marin County ──────────────────────────────────────────────
            zip("94941", "Mill Valley",         lat: 37.906, lon: -122.545,
                dlat: 0.022, dlon: 0.026,
                pop: 18000, mhi: 185000, mAge: 46.0,
                race: (82, 5, 8, 2, 3),
                income: (2, 3, 5, 8, 16, 66),
                age: (18, 14, 30, 18, 20)),

            zip("94901", "San Rafael",          lat: 37.975, lon: -122.531,
                dlat: 0.022, dlon: 0.026,
                pop: 32000, mhi: 92000, mAge: 40.5,
                race: (58, 25, 10, 4, 3),
                income: (8, 12, 16, 16, 22, 26),
                age: (16, 24, 30, 14, 16)),
        ]
    }

    // Helper to build a rectangle polygon around a center
    private static func zip(
        _ code: String, _ city: String,
        lat: Double, lon: Double,
        dlat: Double, dlon: Double,
        pop: Int, mhi: Int, mAge: Double,
        race: (Double, Double, Double, Double, Double),
        income: (Double, Double, Double, Double, Double, Double),
        age: (Double, Double, Double, Double, Double)
    ) -> ZIPCodeRegion {
        let polygon = [
            CLLocationCoordinate2D(latitude: lat - dlat/2, longitude: lon - dlon/2),
            CLLocationCoordinate2D(latitude: lat + dlat/2, longitude: lon - dlon/2),
            CLLocationCoordinate2D(latitude: lat + dlat/2, longitude: lon + dlon/2),
            CLLocationCoordinate2D(latitude: lat - dlat/2, longitude: lon + dlon/2),
        ]
        let demo = ZIPDemographics(
            zip: code, city: city, totalPopulation: pop,
            medianHouseholdIncome: mhi, medianAge: mAge,
            white: race.0, hispanic: race.1, asian: race.2,
            black: race.3, other: race.4,
            incomeUnder25k: income.0, income25to50k: income.1,
            income50to75k: income.2, income75to100k: income.3,
            income100to150k: income.4, incomeOver150k: income.5,
            ageUnder18: age.0, age18to34: age.1,
            age35to54: age.2, age55to64: age.3, age65plus: age.4
        )
        return ZIPCodeRegion(
            id: code,
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            polygon: polygon,
            demographics: demo
        )
    }
}
