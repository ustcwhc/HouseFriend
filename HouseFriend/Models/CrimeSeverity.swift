import Foundation
import SwiftUI

// MARK: - CrimeSeverity

/// Four-tier severity classification for crime incidents.
/// Used by heatmap (weight), clusters (aggregation), and detail UI (icon/color).
enum CrimeSeverity: String, CaseIterable {
    case violent
    case property
    case vehicle
    case other

    // MARK: - Classification

    /// Maps a raw crime category string (from SODA API) to a severity tier.
    /// Uses keyword-based matching; checks vehicle BEFORE property so
    /// "vehicle theft" maps to .vehicle, not .property.
    static func from(category: String) -> CrimeSeverity {
        let lower = category.lowercased()

        // Violent -- check first (highest severity)
        let violentKeywords = [
            "homicide", "assault", "robbery", "rape", "weapon",
            "kidnap", "battery", "manslaughter", "sex offense"
        ]
        for keyword in violentKeywords {
            if lower.contains(keyword) { return .violent }
        }

        // Vehicle -- check before property so "vehicle theft" maps here
        let vehicleKeywords = ["vehicle", "auto theft", "car break"]
        for keyword in vehicleKeywords {
            if lower.contains(keyword) { return .vehicle }
        }

        // Property
        let propertyKeywords = [
            "burglary", "theft", "arson", "larceny",
            "stolen", "shoplifting", "breaking and entering"
        ]
        for keyword in propertyKeywords {
            if lower.contains(keyword) { return .property }
        }

        return .other
    }

    // MARK: - Properties

    /// Heatmap/cluster weight multiplier: violent crimes produce hotter glow
    var weight: Double {
        switch self {
        case .violent:  return 3.0
        case .property: return 2.0
        case .vehicle:  return 1.5
        case .other:    return 1.0
        }
    }

    /// SF Symbol name for map markers and detail sheets
    var iconName: String {
        switch self {
        case .violent:  return "bolt.shield.fill"
        case .property: return "house.fill"
        case .vehicle:  return "car.fill"
        case .other:    return "circle.fill"
        }
    }

    /// Stable string key for GeoJSON properties and matching expressions
    var key: String { rawValue }

    /// UI color for severity-coded rendering
    var color: Color {
        switch self {
        case .violent:  return .red
        case .property: return .orange
        case .vehicle:  return .yellow
        case .other:    return .gray
        }
    }
}

// MARK: - CrimeDetail

/// Individual crime incident data for bottom sheet display.
/// Extracted from GeoJSON feature properties after cluster leaf query.
struct CrimeDetail: Identifiable {
    let id = UUID()
    let category: String
    let description: String
    let date: String
    let severity: CrimeSeverity
}
