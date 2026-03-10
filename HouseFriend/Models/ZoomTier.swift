import MapKit

// MARK: - Zoom Tier

/// Canonical zoom levels for controlling object visibility on the map.
///
/// Each tier corresponds to a real-world scale and determines which objects
/// are rendered. Objects hidden at the current tier are not added to the map,
/// saving computation and reducing visual clutter.
///
/// ```
/// satellite ─── 5.0° ─── state ─── 1.2° ─── county ─── 0.3° ─── city ─── 0.08° ─── neighborhood
/// ```
enum ZoomTier: Int, Comparable, CaseIterable {
    case satellite      // > 5°     — continents, countries
    case state          // 1.2°–5°  — state outlines, major cities
    case county         // 0.3°–1.2° — freeways, city boundaries
    case city           // 0.08°–0.3° — boulevards, arterials
    case neighborhood   // < 0.08°  — residential streets, buildings

    /// Determine the current zoom tier from the map's latitude span.
    init(span: CLLocationDegrees) {
        switch span {
        case _ where span > 5.0:  self = .satellite
        case _ where span > 1.2:  self = .state
        case _ where span > 0.3:  self = .county
        case _ where span > 0.08: self = .city
        default:                  self = .neighborhood
        }
    }

    /// Convenience init from a map region.
    init(region: MKCoordinateRegion) {
        self.init(span: region.span.latitudeDelta)
    }

    static func < (lhs: ZoomTier, rhs: ZoomTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Object Visibility

/// Every rendered map object and the minimum zoom tier at which it becomes visible.
/// Use `isVisible(at:)` to check whether an object should be rendered.
enum MapObject {

    // MARK: Population
    case zipPolygon                 // County
    case zipLabel                   // County

    // MARK: Crime
    case crimeHeatmap               // City
    case crimeMarkerViolent         // Neighborhood
    case crimeMarkerProperty        // Neighborhood
    case crimeMarkerVehicle         // Neighborhood
    case crimeMarkerVandalism       // Neighborhood
    case crimeMarkerOther           // Neighborhood

    // MARK: Noise — Major (static bundled data)
    case noiseMotorway              // City     — 78 dB, 5pt
    case noiseTrunk                 // City     — 74 dB, 5pt
    case noisePrimary               // City     — 68 dB, 4pt
    case noiseRailway               // City     — 75 dB, 4pt, dashed
    case noiseLightRail             // City     — 70 dB, 3.5pt, dashed

    // MARK: Noise — Detail (Overpass fetch)
    case noiseSecondary             // Neighborhood — 63 dB, 3pt
    case noiseTertiary              // Neighborhood — 58 dB, 2.5pt
    case noiseResidential           // Neighborhood — 52 dB, 2pt
    case noiseService               // Neighborhood — 47 dB, 1.5pt

    // MARK: Schools
    case schoolHigh                 // County   — purple pin
    case schoolMiddle               // City     — blue pin
    case schoolElementary           // Neighborhood — green pin

    // MARK: Earthquake
    case earthquakeMajor            // City     — M >= 5.0, red
    case earthquakeModerate         // City     — M >= 4.0, orange
    case earthquakeMinor            // City     — M < 4.0, yellow

    // MARK: Fire Hazard
    case fireZoneExtreme            // County   — dark red polygon
    case fireZoneVeryHigh           // County   — orange-red polygon
    case fireZoneHigh               // County   — golden polygon
    case fireZoneModerate           // County   — yellow polygon

    // MARK: Electric Lines
    case electricLine115kV          // County   — yellow polyline
    case electricLine60kV           // County   — yellow polyline

    // MARK: Superfund
    case superfundSite              // City     — orange pin

    // MARK: Supportive Housing
    case housingShelter             // Neighborhood — teal pin
    case housingTransitional        // Neighborhood — teal pin
    case housingPermanent           // Neighborhood — teal pin

    // MARK: Air Quality / Odor
    case odorZone                   // Neighborhood — brown polygon

    // MARK: Global
    case userPin                    // satellite (always visible)

    /// The minimum zoom tier at which this object becomes visible.
    var minimumTier: ZoomTier {
        switch self {
        // Always visible
        case .userPin:                                          return .satellite

        // County level — freeways visible
        case .zipPolygon, .zipLabel:                            return .county
        case .schoolHigh:                                       return .county
        case .fireZoneExtreme, .fireZoneVeryHigh,
             .fireZoneHigh, .fireZoneModerate:                  return .county
        case .electricLine115kV, .electricLine60kV:             return .county

        // City level — boulevards visible
        case .crimeHeatmap:                                     return .city
        case .noiseMotorway, .noiseTrunk, .noisePrimary,
             .noiseRailway, .noiseLightRail:                    return .city
        case .schoolMiddle:                                     return .city
        case .earthquakeMajor, .earthquakeModerate,
             .earthquakeMinor:                                  return .city
        case .superfundSite:                                    return .city

        // Neighborhood level — residential streets visible
        case .crimeMarkerViolent, .crimeMarkerProperty,
             .crimeMarkerVehicle, .crimeMarkerVandalism,
             .crimeMarkerOther:                                 return .neighborhood
        case .noiseSecondary, .noiseTertiary,
             .noiseResidential, .noiseService:                  return .neighborhood
        case .schoolElementary:                                 return .neighborhood
        case .housingShelter, .housingTransitional,
             .housingPermanent:                                 return .neighborhood
        case .odorZone:                                         return .neighborhood
        }
    }

    /// Whether this object should be rendered at the given zoom tier.
    func isVisible(at tier: ZoomTier) -> Bool {
        tier >= minimumTier
    }
}

// MARK: - Convenience helpers for layers

extension ZoomTier {

    /// Whether any noise roads should be rendered at this tier.
    var showsNoiseRoads: Bool { self >= .city }

    /// Whether Overpass detail streets (secondary/residential) should be fetched.
    var showsNoiseDetail: Bool { self >= .neighborhood }

    /// Whether crime heatmap tiles should be rendered.
    var showsCrimeHeatmap: Bool { self >= .city }

    /// Whether individual crime markers should be rendered.
    var showsCrimeMarkers: Bool { self >= .neighborhood }

    /// Filter school level based on current tier.
    func schoolLevelsToShow() -> Set<SchoolLevel> {
        switch self {
        case .satellite, .state:    return []
        case .county:               return [.high]
        case .city:                 return [.high, .middle]
        case .neighborhood:         return [.high, .middle, .elementary]
        }
    }

    /// Whether annotation-based layers should render (superfund, earthquake, etc.)
    var showsCityAnnotations: Bool { self >= .city }

    /// Whether neighborhood-only annotations should render (housing, etc.)
    var showsNeighborhoodAnnotations: Bool { self >= .neighborhood }

    /// Whether polygon overlays should render (ZIP, fire, electric).
    var showsCountyOverlays: Bool { self >= .county }
}
