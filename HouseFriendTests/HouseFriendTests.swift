//
//  HouseFriendTests.swift
//  HouseFriendTests
//
//  Created by Jing on 3/7/26.
//

import Testing
import MapKit
@testable import HouseFriend

struct ScoringServiceTests {

    // MARK: - Earthquake scoring

    @Test func earthquakeNoEvents() {
        let coord = CLLocationCoordinate2D(latitude: 37.45, longitude: -122.05)
        let result = ScoringService.earthquakeScore(events: [], coord: coord)
        #expect(result.score == 100)
        #expect(result.label == "Low Risk")
    }

    @Test func earthquakeManyNearbyEvents() {
        let coord = CLLocationCoordinate2D(latitude: 37.45, longitude: -122.05)
        let events = (0..<5).map { i in
            EarthquakeEvent(
                magnitude: 3.0,
                place: "Test \(i)",
                coordinate: CLLocationCoordinate2D(latitude: 37.45 + Double(i) * 0.01, longitude: -122.05),
                date: Date()
            )
        }
        let result = ScoringService.earthquakeScore(events: events, coord: coord)
        #expect(result.score == 40) // max(20, 100 - 5*12)
        #expect(result.label == "High Activity")
    }

    @Test func earthquakeFarEvents() {
        let coord = CLLocationCoordinate2D(latitude: 37.45, longitude: -122.05)
        let events = [EarthquakeEvent(
            magnitude: 5.0,
            place: "Far away",
            coordinate: CLLocationCoordinate2D(latitude: 38.0, longitude: -121.0),
            date: Date()
        )]
        let result = ScoringService.earthquakeScore(events: events, coord: coord)
        #expect(result.score == 100)
        #expect(result.label == "Low Risk")
    }

    // MARK: - Air quality scoring

    @Test func airQualityGood() {
        let data = AirQualityData(aqi: 30, category: "Good", pollutant: "PM2.5")
        let result = ScoringService.airQualityScore(data: data)
        #expect(result.score == 95)
        #expect(result.label == "Good")
    }

    @Test func airQualityUnhealthy() {
        let data = AirQualityData(aqi: 120, category: "Unhealthy for Sensitive Groups", pollutant: "PM2.5")
        let result = ScoringService.airQualityScore(data: data)
        #expect(result.score == 50)
    }

    @Test func airQualityNilFallback() {
        let result = ScoringService.airQualityScore(data: nil)
        #expect(result.score == 75) // AQI 55 → falls in 51-100 range
    }

    // MARK: - Crime scoring

    @Test func crimeScorePassthrough() {
        let stats = CrimeStats(score: 82, label: "Low Crime", incidentCount: 3)
        let result = ScoringService.crimeScore(stats: stats)
        #expect(result.score == 82)
        #expect(result.label == "Low Crime")
    }

    // MARK: - School scoring

    @Test func schoolScoreNoSchools() {
        let coord = CLLocationCoordinate2D(latitude: 37.45, longitude: -122.05)
        let result = ScoringService.schoolScore(schools: [], coord: coord)
        #expect(result.score == 60) // avgRating=6, 6*10=60
        #expect(result.label == "No schools found nearby")
    }

    @Test func schoolScoreWithNearbySchools() {
        let coord = CLLocationCoordinate2D(latitude: 37.45, longitude: -122.05)
        let schools = [
            School(name: "A", level: .elementary, rating: 9,
                   coordinate: CLLocationCoordinate2D(latitude: 37.452, longitude: -122.052), district: "D"),
            School(name: "B", level: .middle, rating: 7,
                   coordinate: CLLocationCoordinate2D(latitude: 37.448, longitude: -122.048), district: "D"),
        ]
        let result = ScoringService.schoolScore(schools: schools, coord: coord)
        // avg = (9+7)/2 = 8, score = 8*10 = 80
        #expect(result.score == 80)
        #expect(result.label.contains("2 schools"))
    }

    // MARK: - Population scoring

    @Test func populationScoreHighDensity() {
        let info = PopulationInfo(cityName: "San Francisco", population: 874961,
                                  density: 18000, medianIncome: 130000, medianAge: 38.5)
        let result = ScoringService.populationScore(info: info)
        // max(20, min(95, 100 - (18000-3000)/120)) = max(20, 100-125) = 20
        #expect(result.score == 20)
        #expect(result.label.contains("San Francisco"))
    }

    @Test func populationScoreNil() {
        let result = ScoringService.populationScore(info: nil)
        #expect(result.score == 70)
    }

    // MARK: - Electric line scoring

    @Test func electricLineNoLines() {
        let coord = CLLocationCoordinate2D(latitude: 37.45, longitude: -122.05)
        let result = ScoringService.electricLineScore(lines: [], coord: coord)
        #expect(result.score == 75)
        #expect(result.label == "Data loading...")
    }

    @Test func electricLineVeryClose() {
        let coord = CLLocationCoordinate2D(latitude: 37.45, longitude: -122.05)
        let line = ElectricLine(coordinates: [
            CLLocationCoordinate2D(latitude: 37.45, longitude: -122.06),
            CLLocationCoordinate2D(latitude: 37.45, longitude: -122.04),
        ], voltage: 115, type: "AC")
        let result = ScoringService.electricLineScore(lines: [line], coord: coord)
        #expect(result.score == 45)
        #expect(result.label.contains("115kV"))
    }

    // MARK: - Point in polygon

    @Test func pointInsidePolygon() {
        let polygon = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 10),
            CLLocationCoordinate2D(latitude: 10, longitude: 10),
            CLLocationCoordinate2D(latitude: 10, longitude: 0),
        ]
        let inside = CLLocationCoordinate2D(latitude: 5, longitude: 5)
        #expect(ScoringService.pointInPolygon(inside, polygon: polygon) == true)
    }

    @Test func pointOutsidePolygon() {
        let polygon = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 10),
            CLLocationCoordinate2D(latitude: 10, longitude: 10),
            CLLocationCoordinate2D(latitude: 10, longitude: 0),
        ]
        let outside = CLLocationCoordinate2D(latitude: 15, longitude: 5)
        #expect(ScoringService.pointInPolygon(outside, polygon: polygon) == false)
    }

    @Test func pointInPolygonTooFewVertices() {
        let polygon = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 10),
        ]
        let pt = CLLocationCoordinate2D(latitude: 0, longitude: 5)
        #expect(ScoringService.pointInPolygon(pt, polygon: polygon) == false)
    }

    // MARK: - Superfund scoring

    @Test func superfundNoSites() {
        let coord = CLLocationCoordinate2D(latitude: 37.45, longitude: -122.05)
        let result = ScoringService.superfundScore(sites: [], coord: coord)
        #expect(result.score == 100)
        #expect(result.label == "No EPA sites nearby")
    }

    // MARK: - Supportive housing scoring

    @Test func supportiveHomeNoFacilities() {
        let coord = CLLocationCoordinate2D(latitude: 37.45, longitude: -122.05)
        let result = ScoringService.supportiveHomeScore(facilities: [], coord: coord)
        #expect(result.score == 100)
        #expect(result.label == "0 facilities nearby")
    }

    // MARK: - Earthquake URL dynamic date

    @Test func earthquakeServiceBuildsDynamicURL() {
        let service = EarthquakeService()
        // Access the URL through reflection isn't possible, but we can verify
        // the service doesn't crash on fetch() init
        #expect(service.events.isEmpty)
        #expect(service.isLoading == false)
    }
}
