# Testing Patterns

**Analysis Date:** 2026-03-21

## Test Framework

**Unit Test Runner:**
- Swift Testing (new `@Test` / `#expect` API, not XCTest)
- Target: `HouseFriendTests`
- Config: Xcode scheme — no separate config file

**UI Test Runner:**
- XCTest (`XCTestCase`)
- Target: `HouseFriendUITests`

**Assertion Library:**
- Unit tests: `#expect(...)` from Swift Testing
- UI tests: `XCTAssert` family from XCTest

**Run Commands:**
```bash
# Run unit tests via Xcode
xcodebuild test -scheme HouseFriend -destination 'platform=iOS Simulator,name=iPhone 16'

# Run from Xcode: Cmd+U
```

## Test File Organization

**Location:**
- Unit tests: `HouseFriendTests/HouseFriendTests.swift` — single file, all tests co-located
- UI tests: `HouseFriendUITests/HouseFriendUITests.swift` and `HouseFriendUITests/HouseFriendUITestsLaunchTests.swift`

**Naming:**
- Test struct named after the service under test: `ScoringServiceTests`
- Test methods named descriptively without `test` prefix (Swift Testing convention): `earthquakeNoEvents()`, `airQualityGood()`, `pointInsidePolygon()`

**Structure:**
```
HouseFriendTests/
└── HouseFriendTests.swift     # All unit tests in ScoringServiceTests struct

HouseFriendUITests/
├── HouseFriendUITests.swift              # App launch + stub UI test
└── HouseFriendUITestsLaunchTests.swift   # Launch performance + screenshot
```

## Test Structure

**Suite Organization:**
```swift
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
}
```

**Patterns:**
- No `setUp` / `tearDown` — each test constructs its own data inline
- No shared fixtures — test data is created locally in each test function
- Tests are synchronous (no async/await) — all tested functions are pure/static
- `@testable import HouseFriend` used to access `internal` types

## Mocking

**Framework:** None — no mocking library used.

**Patterns:**
- Services are not mocked; only `ScoringService` (which is a pure static enum) is tested directly
- Test inputs are constructed inline as value types:
  ```swift
  let data = AirQualityData(aqi: 30, category: "Good", pollutant: "PM2.5")
  let result = ScoringService.airQualityScore(data: data)
  ```
- `nil` inputs test fallback/default behavior:
  ```swift
  let result = ScoringService.airQualityScore(data: nil)
  #expect(result.score == 75)
  ```

**What to Mock:**
- Not applicable in current test suite — only pure functions are tested

**What NOT to Mock:**
- `CLLocationCoordinate2D` — use real coordinate values
- `ScoringService` static methods — test them directly, not through view models

## Fixtures and Factories

**Test Data:** Constructed inline; no shared factory functions.

```swift
// Inline construction pattern
let events = (0..<5).map { i in
    EarthquakeEvent(
        magnitude: 3.0,
        place: "Test \(i)",
        coordinate: CLLocationCoordinate2D(latitude: 37.45 + Double(i) * 0.01, longitude: -122.05),
        date: Date()
    )
}
```

`CrimeService.mockIncidents(lat:lon:count:)` exists as a static helper but is primarily for app fallback data, not for testing.

**Location:**
- No separate fixtures directory — all test data lives in `HouseFriendTests/HouseFriendTests.swift`

## Coverage

**Requirements:** None enforced — no minimum coverage threshold configured.

**View Coverage:**
```bash
# Enable in Xcode: Edit Scheme → Test → Options → Gather coverage for all targets
```

**Current coverage areas:**
- `ScoringService` — well covered across all scoring methods
- `GeoJSONParser` — not tested
- All `*Service` network classes — not tested (require mocking URLSession)
- All SwiftUI views — not tested
- `ZoomTier` — not tested (pure enum logic, testable)
- `NoiseService.parseBundledJSON` / `parseOSMResponse` — not tested (static parsers, testable)

## Test Types

**Unit Tests:**
- Scope: Pure/static scoring functions in `ScoringService`
- Approach: Call static method with inline data, assert `ScoreResult.score` and `ScoreResult.label`
- File: `HouseFriendTests/HouseFriendTests.swift`

**Integration Tests:**
- Not present

**E2E / UI Tests:**
- Framework: XCTest + `XCUIApplication`
- Scope: Minimal — launch smoke test and launch performance measurement only
- File: `HouseFriendUITests/HouseFriendUITests.swift`, `HouseFriendUITestsLaunchTests.swift`
- The UI test stubs (`testExample`, `testLaunch`) are Xcode-generated scaffolding with no assertions beyond app launch

## Common Patterns

**Boundary / edge case testing:**
```swift
// Zero items
@Test func earthquakeNoEvents() {
    let result = ScoringService.earthquakeScore(events: [], coord: coord)
    #expect(result.score == 100)
}

// Maximum load
@Test func earthquakeManyNearbyEvents() {
    // expected score in comment: max(20, 100 - 5*12)
    #expect(result.score == 40)
}

// Far/irrelevant items (no impact on score)
@Test func earthquakeFarEvents() {
    #expect(result.score == 100)
}
```

**Nil/optional fallback testing:**
```swift
@Test func airQualityNilFallback() {
    let result = ScoringService.airQualityScore(data: nil)
    #expect(result.score == 75) // AQI 55 → falls in 51-100 range
}
```

**Geometry testing:**
```swift
@Test func pointInsidePolygon() {
    let polygon = [
        CLLocationCoordinate2D(latitude: 0, longitude: 0),
        CLLocationCoordinate2D(latitude: 0, longitude: 10),
        CLLocationCoordinate2D(latitude: 10, longitude: 10),
        CLLocationCoordinate2D(latitude: 10, longitude: 0),
    ]
    #expect(ScoringService.pointInPolygon(inside, polygon: polygon) == true)
}
```

**Score arithmetic comments:** Tests include comments with the expected formula so reviewers can verify without re-implementing:
```swift
#expect(result.score == 40) // max(20, 100 - 5*12)
#expect(result.score == 60) // avgRating=6, 6*10=60
```

## Gaps to Be Aware Of

- `ZoomTier` init and computed properties are untested despite being pure logic
- `NoiseService.parseBundledJSON` and `parseOSMResponse` are static and fully testable but have no tests
- All `ObservableObject` services with network calls (`CrimeService`, `EarthquakeService`, `AirQualityService`, etc.) are untested — would require URLSession injection or protocol abstraction
- SwiftUI views are not tested

---

*Testing analysis: 2026-03-21*
