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

    /// Determine zoom tier from Mapbox camera zoom level (0-22 scale).
    init(zoom: Double) {
        switch zoom {
        case _ where zoom >= 14: self = .neighborhood
        case _ where zoom >= 11: self = .city
        case _ where zoom >= 8:  self = .county
        case _ where zoom >= 5:  self = .state
        default:                 self = .satellite
        }
    }

    static func < (lhs: ZoomTier, rhs: ZoomTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Layer Visibility

/// Per-layer visibility rules. Each layer defines which objects appear at each zoom tier.
/// Usage: `LayerVisibility.population.isVisible(at: tier)`
enum LayerVisibility {

    // MARK: - Population Layer

    enum Population {
        case zipPolygon             // County — yellow border, 445 ZIPs
        case zipLabel               // County — white label with ZIP ID

        var minimumTier: ZoomTier {
            switch self {
            case .zipPolygon, .zipLabel: return .county
            }
        }
    }

    // MARK: - Crime Layer

    enum Crime {
        case heatmap                // City — Gaussian model tiles
        case markerViolent          // Neighborhood — purple, clickable
        case markerProperty         // Neighborhood — cyan, clickable
        case markerVehicle          // Neighborhood — orange, clickable
        case markerVandalism        // Neighborhood — brown, clickable
        case markerOther            // Neighborhood — gray, clickable

        var minimumTier: ZoomTier {
            switch self {
            case .heatmap:
                return .city
            case .markerViolent, .markerProperty, .markerVehicle,
                 .markerVandalism, .markerOther:
                return .neighborhood
            }
        }
    }

    // MARK: - Noise Layer

    enum Noise {
        // Major roads — static bundled data, visible at City level
        case motorway               // 78 dB, 5pt
        case trunk                  // 74 dB, 5pt
        case primary                // 68 dB, 4pt
        case railway                // 75 dB, 4pt, dashed
        case lightRail              // 70 dB, 3.5pt, dashed

        // Detail streets — Overpass fetch, visible at Neighborhood level
        case secondary              // 63 dB, 3pt
        case tertiary               // 58 dB, 2.5pt
        case residential            // 52 dB, 2pt
        case service                // 47 dB, 1.5pt

        var minimumTier: ZoomTier {
            switch self {
            case .motorway, .trunk, .primary, .railway, .lightRail:
                return .city
            case .secondary, .tertiary, .residential, .service:
                return .neighborhood
            }
        }
    }

    // MARK: - Schools Layer

    enum Schools {
        case high                   // County — purple pin
        case middle                 // City — blue pin
        case elementary             // Neighborhood — green pin

        var minimumTier: ZoomTier {
            switch self {
            case .high:       return .county
            case .middle:     return .city
            case .elementary: return .neighborhood
            }
        }
    }

    // MARK: - Earthquake Layer

    enum Earthquake {
        case major                  // City — M >= 5.0, red
        case moderate               // City — M >= 4.0, orange
        case minor                  // City — M < 4.0, yellow

        var minimumTier: ZoomTier {
            return .city
        }
    }

    // MARK: - Fire Hazard Layer

    enum FireHazard {
        case extreme                // County — dark red polygon
        case veryHigh               // County — orange-red polygon
        case high                   // County — golden polygon
        case moderate               // County — yellow polygon

        var minimumTier: ZoomTier {
            return .county
        }
    }

    // MARK: - Electric Lines Layer

    enum ElectricLines {
        case line115kV              // County — yellow polyline
        case line60kV               // County — yellow polyline

        var minimumTier: ZoomTier {
            return .county
        }
    }

    // MARK: - Superfund Layer

    enum Superfund {
        case site                   // City — orange pin

        var minimumTier: ZoomTier {
            return .city
        }
    }

    // MARK: - Supportive Housing Layer

    enum SupportiveHousing {
        case shelter                // Neighborhood — teal pin
        case transitional           // Neighborhood — teal pin
        case permanent              // Neighborhood — teal pin

        var minimumTier: ZoomTier {
            return .neighborhood
        }
    }

    // MARK: - Air Quality / Odor Layer

    enum AirQuality {
        case odorZone               // Neighborhood — brown polygon

        var minimumTier: ZoomTier {
            return .neighborhood
        }
    }

    // MARK: - Global

    enum Global {
        case userPin                // Always visible — red mappin

        var minimumTier: ZoomTier {
            return .satellite
        }
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
