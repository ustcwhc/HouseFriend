import SwiftUI
import MapboxMaps
import MapKit   // CLLocationCoordinate2D, MKCoordinateRegion (used by service types)

// MARK: - HFMapView
// Mapbox SwiftUI Map wrapper replacing the UIViewRepresentable MKMapView.
// Layers/annotations are stub placeholders — Plans 02.1-02 and 02.1-03 add them.

struct HFMapView: View {

    // MARK: - Bindings / config
    @Binding var viewport: Viewport
    let selectedCategory: CategoryType
    let showCrimeDetails: Bool
    let pinnedLocation: CLLocationCoordinate2D?

    // MARK: - Layer data (passed in from ContentView @StateObject services)
    let noiseRoads: [NoiseRoad]
    let earthquakes: [EarthquakeEvent]
    let schools: [School]
    let superfundSites: [SuperfundSite]
    let housingFacilities: [SupportiveHousingFacility]
    let fireZones: [FireHazardZone]
    let electricLines: [ElectricLine]
    let odorZones: [MapZone]
    let zipRegions: [ZIPCodeRegion]
    let highlightedZIPId: String?
    let crimeMarkers: [CrimeMarker]
    let densityGrid: DensityGrid?
    let crimeHotspots: [CrimeTileOverlay.Hotspot]
    let tractCrimeDensities: [String: Double]
    let censusTracts: [CensusTract]

    // MARK: - Callbacks -> ContentView
    var onCameraChange: (CLLocationCoordinate2D, Double) -> Void = { _, _ in }
    var onSchoolTap: (School) -> Void = { _ in }
    var onSuperfundTap: (SuperfundSite) -> Void = { _ in }
    var onHousingTap: (SupportiveHousingFacility) -> Void = { _ in }
    var onZIPTap: (ZIPCodeRegion) -> Void = { _ in }
    var onMapTap: (CLLocationCoordinate2D) -> Void = { _ in }
    var onNoiseFetchCancel: () -> Void = {}
    var onMapLongPress: (CLLocationCoordinate2D) -> Void = { _ in }

    // MARK: - Body

    var body: some View {
        MapboxMaps.MapReader { proxy in
            MapboxMaps.Map(viewport: $viewport) {
                // User location puck
                Puck2D(bearing: .heading)

                // TODO: (Plan 02.1-02) Polygon/polyline layers:
                //   - Fire hazard zones (FillLayer)
                //   - Electric lines (LineLayer)
                //   - Odor zones (FillLayer)
                //   - ZIP code regions (FillLayer + SymbolLayer labels)
                //   - Noise roads (stacked LineLayer with blur)

                // TODO: (Plan 02.1-03) Annotations and heatmap:
                //   - Crime HeatmapLayer
                //   - School PointAnnotations
                //   - Superfund PointAnnotations
                //   - Earthquake PointAnnotations
                //   - Housing PointAnnotations
                //   - Crime cluster annotations
                //   - Pinned location marker
            }
            .mapStyle(mapStyleForCategory)
            .onMapTapGesture { context in
                onMapTap(context.coordinate)
            }
            .onMapLongPressGesture { context in
                onMapLongPress(context.coordinate)
            }
            .onCameraChanged { context in
                let center = context.cameraState.center
                let zoom = context.cameraState.zoom
                onCameraChange(center, zoom)
            }
        }
    }

    // MARK: - Map Style

    /// Day style for most layers; night preset for the crime heatmap (dark tiles
    /// make the gas/glow effect visible).
    private var mapStyleForCategory: MapboxMaps.MapStyle {
        if selectedCategory == .crime {
            return .standard(lightPreset: .night)
        }
        return .standard(lightPreset: .day)
    }
}

// MARK: - HFAnnotation (stable UIKit annotation — kept for backward compat until Plan 03)

enum HFAnnotationData {
    case school(School)
    case superfund(SuperfundSite)
    case housing(SupportiveHousingFacility)
    case earthquake(EarthquakeEvent)
    case zip(ZIPCodeRegion)
    case crimeMarker(CrimeMarker)
    case crimeCluster(coordinate: CLLocationCoordinate2D, count: Int)
    case pin
}

class HFAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let data: HFAnnotationData
    let key: String
    var title: String? { nil }

    init(coordinate: CLLocationCoordinate2D, data: HFAnnotationData, key: String) {
        self.coordinate = coordinate
        self.data = data
        self.key = key
    }
}
