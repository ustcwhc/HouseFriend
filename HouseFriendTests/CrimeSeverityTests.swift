import Testing
@testable import HouseFriend

struct CrimeSeverityTests {

    // MARK: - Violent classification

    @Test func testViolentClassification() {
        #expect(CrimeSeverity.from(category: "assault") == .violent)
        #expect(CrimeSeverity.from(category: "homicide") == .violent)
        #expect(CrimeSeverity.from(category: "robbery") == .violent)
        #expect(CrimeSeverity.from(category: "rape") == .violent)
        #expect(CrimeSeverity.from(category: "weapon offense") == .violent)
        #expect(CrimeSeverity.from(category: "Aggravated Assault") == .violent)
        #expect(CrimeSeverity.from(category: "kidnapping") == .violent)
        #expect(CrimeSeverity.from(category: "battery") == .violent)
        #expect(CrimeSeverity.from(category: "manslaughter") == .violent)
        #expect(CrimeSeverity.from(category: "sex offense") == .violent)
    }

    // MARK: - Property classification

    @Test func testPropertyClassification() {
        #expect(CrimeSeverity.from(category: "burglary") == .property)
        #expect(CrimeSeverity.from(category: "theft") == .property)
        #expect(CrimeSeverity.from(category: "arson") == .property)
        #expect(CrimeSeverity.from(category: "shoplifting") == .property)
        #expect(CrimeSeverity.from(category: "Larceny Theft") == .property)
        #expect(CrimeSeverity.from(category: "stolen property") == .property)
        #expect(CrimeSeverity.from(category: "Breaking and Entering") == .property)
    }

    // MARK: - Vehicle classification

    @Test func testVehicleClassification() {
        #expect(CrimeSeverity.from(category: "auto theft") == .vehicle)
        #expect(CrimeSeverity.from(category: "vehicle break-in") == .vehicle)
        #expect(CrimeSeverity.from(category: "Vehicle Theft") == .vehicle)
    }

    // MARK: - Other classification

    @Test func testOtherClassification() {
        #expect(CrimeSeverity.from(category: "vandalism") == .other)
        #expect(CrimeSeverity.from(category: "trespassing") == .other)
        #expect(CrimeSeverity.from(category: "unknown category xyz") == .other)
        #expect(CrimeSeverity.from(category: "disorderly conduct") == .other)
    }

    @Test func testEmptyStringClassification() {
        #expect(CrimeSeverity.from(category: "") == .other)
    }

    // MARK: - Vehicle before property priority

    @Test func testVehicleBeforeProperty() {
        // "vehicle theft" contains both "vehicle" and "theft" -- must map to .vehicle
        #expect(CrimeSeverity.from(category: "vehicle theft") == .vehicle)
        #expect(CrimeSeverity.from(category: "Motor Vehicle Theft") == .vehicle)
    }

    // MARK: - Weight values

    @Test func testWeightValues() {
        #expect(CrimeSeverity.violent.weight == 3.0)
        #expect(CrimeSeverity.property.weight == 2.0)
        #expect(CrimeSeverity.vehicle.weight == 1.5)
        #expect(CrimeSeverity.other.weight == 1.0)
    }

    // MARK: - Icon names

    @Test func testIconNames() {
        #expect(CrimeSeverity.violent.iconName == "bolt.shield.fill")
        #expect(CrimeSeverity.property.iconName == "house.fill")
        #expect(CrimeSeverity.vehicle.iconName == "car.fill")
        #expect(CrimeSeverity.other.iconName == "circle.fill")
    }

    // MARK: - Key values

    @Test func testKeyValues() {
        #expect(CrimeSeverity.violent.key == "violent")
        #expect(CrimeSeverity.property.key == "property")
        #expect(CrimeSeverity.vehicle.key == "vehicle")
        #expect(CrimeSeverity.other.key == "other")
    }
}
