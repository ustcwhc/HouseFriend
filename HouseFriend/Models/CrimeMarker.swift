import Foundation
import CoreLocation
import SwiftUI

enum CrimeType: String, CaseIterable {
    case violent   = "Violent"
    case property  = "Property"
    case vehicle   = "Vehicle"
    case vandalism = "Vandalism"
    case other     = "Other"

    var systemImage: String {
        switch self {
        case .violent:   return "exclamationmark.triangle.fill"
        case .property:  return "house.fill"
        case .vehicle:   return "car.fill"
        case .vandalism: return "paintbrush.fill"
        case .other:     return "questionmark.circle.fill"
        }
    }

    var markerColor: Color {
        switch self {
        case .violent:   return .purple
        case .property:  return Color(red: 0.2, green: 0.7, blue: 0.75)
        case .vehicle:   return .orange
        case .vandalism: return .brown
        case .other:     return .gray
        }
    }
}

struct CrimeMarker: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: CrimeType
    let count: Int
    let daysAgo: Int
}
