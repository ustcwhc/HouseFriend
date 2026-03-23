import SwiftUI
@_spi(Experimental) import MapboxMaps
import MapKit   // CLLocationCoordinate2D, MKCoordinateRegion (used by service types)
import Turf     // Feature, FeatureCollection, Point for GeoJSON sources

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

                // MARK: Polygon/polyline overlay layers
                fireLayerContent
                electricLayerContent
                odorLayerContent
                zipLayerContent
                noiseLayerContent

                // MARK: Crime HeatmapLayer + cluster markers (Plan 02.1-03)
                crimeHeatmapContent
                crimeClusterContent
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

// MARK: - Crime Heatmap Layer Content

extension HFMapView {

    /// GeoJSON source + HeatmapLayer for crime incidents — GPU-accelerated glow.
    /// Replaces the CPU pixel-by-pixel CrimeTileOverlay with Mapbox's native heatmap.
    @MapboxMaps.MapContentBuilder
    var crimeHeatmapContent: some MapboxMaps.MapContent {
        if selectedCategory == .crime, !crimeHotspots.isEmpty {
            // GeoJSON point source from crime hotspots
            GeoJSONSource(id: "crime-incidents")
                .data(.featureCollection(crimeHotspotsFeatureCollection))

            // GPU-accelerated heatmap layer with gas/glow color gradient
            HeatmapLayer(id: "crime-heat", source: "crime-incidents")
                .heatmapWeight(Exp(.get) { "weight" })
                .heatmapIntensity(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.zoom)
                    0; 1
                    9; 3
                })
                .heatmapRadius(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.zoom)
                    0; 2
                    9; 20
                    14; 30
                })
                .heatmapColor(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.heatmapDensity)
                    // Transparent → yellow → orange → red (gas/glow on dark tiles)
                    0;    "rgba(0,0,0,0)"
                    0.12; "rgba(255,220,100,0.1)"
                    0.25; "rgba(255,190,50,0.25)"
                    0.40; "rgba(255,100,10,0.4)"
                    0.55; "rgba(255,60,15,0.6)"
                    0.75; "rgba(255,30,30,0.75)"
                    1.0;  "rgba(255,30,30,0.85)"
                })
                .heatmapOpacity(0.85)
        }
    }

    /// Crime cluster markers — circles + count labels from DensityGrid.
    /// Visible when showCrimeDetails is toggled on.
    @MapboxMaps.MapContentBuilder
    var crimeClusterContent: some MapboxMaps.MapContent {
        if selectedCategory == .crime, showCrimeDetails, let grid = densityGrid {
            // GeoJSON source from density grid cells with count > 0
            GeoJSONSource(id: "crime-clusters")
                .data(.featureCollection(densityGridFeatureCollection(grid)))

            // White circles behind the count text
            CircleLayer(id: "crime-cluster-circles", source: "crime-clusters")
                .circleRadius(Exp(.step) {
                    Exp(.get) { "count" }
                    14  // default radius
                    5; 17
                    20; 20
                })
                .circleColor(.white)
                .circleStrokeWidth(2.0)
                .circleStrokeColor(Exp(.step) {
                    Exp(.get) { "count" }
                    "gray"
                    5; "orange"
                    10; "red"
                })

            // Count text labels on top of circles
            SymbolLayer(id: "crime-cluster-labels", source: "crime-clusters")
                .textField(Exp(.toString) { Exp(.get) { "count" } })
                .textSize(12.0)
                .textColor(Exp(.step) {
                    Exp(.get) { "count" }
                    "gray"
                    5; "orange"
                    10; "red"
                })
                .textFont(["DIN Pro Bold"])
                .textAllowOverlap(true)
        }
    }

    // MARK: - Fire Hazard Layer

    /// Fire hazard zones as colored fill polygons, severity-driven coloring.
    @MapboxMaps.MapContentBuilder
    var fireLayerContent: some MapboxMaps.MapContent {
        if selectedCategory == .fireHazard, !fireZones.isEmpty {
            GeoJSONSource(id: "fire-zones")
                .data(.featureCollection(fireZoneFeatureCollection))

            // Severity-colored fill: extreme=dark red, very high=orange-red, high=orange, default=yellow
            FillLayer(id: "fire-fill", source: "fire-zones")
                .fillColor(Exp(.match) {
                    Exp(.get) { "severity" }
                    "extreme";   "rgba(184,5,5,1)"
                    "very high"; "rgba(230,51,13,1)"
                    "high";      "rgba(242,128,26,1)"
                    "rgba(242,217,26,1)"  // default: yellow
                })
                .fillOpacity(0.40)

            // Thin stroke around each zone
            LineLayer(id: "fire-stroke", source: "fire-zones")
                .lineColor(Exp(.match) {
                    Exp(.get) { "severity" }
                    "extreme";   "rgba(184,5,5,0.7)"
                    "very high"; "rgba(230,51,13,0.7)"
                    "high";      "rgba(242,128,26,0.7)"
                    "rgba(242,217,26,0.7)"  // default
                })
                .lineWidth(1.5)
        }
    }

    // MARK: - Electric Lines Layer

    /// Electric transmission lines as yellow polylines.
    @MapboxMaps.MapContentBuilder
    var electricLayerContent: some MapboxMaps.MapContent {
        if selectedCategory == .electricLines, !electricLines.isEmpty {
            GeoJSONSource(id: "electric-lines")
                .data(.featureCollection(electricLineFeatureCollection))

            LineLayer(id: "electric-line", source: "electric-lines")
                .lineColor(UIColor.systemYellow.withAlphaComponent(0.75))
                .lineWidth(2.5)
        }
    }

    // MARK: - Odor Zones Layer

    /// Odor/air quality zones as brown-tinted fill polygons.
    @MapboxMaps.MapContentBuilder
    var odorLayerContent: some MapboxMaps.MapContent {
        if selectedCategory == .milpitasOdor, !odorZones.isEmpty {
            GeoJSONSource(id: "odor-zones")
                .data(.featureCollection(odorZoneFeatureCollection))

            FillLayer(id: "odor-fill", source: "odor-zones")
                .fillColor(UIColor.systemBrown.withAlphaComponent(0.30))

            LineLayer(id: "odor-stroke", source: "odor-zones")
                .lineColor(UIColor.systemBrown.withAlphaComponent(0.55))
                .lineWidth(1.0)
        }
    }

    // MARK: - ZIP Polygons Layer (Task 2)

    /// ZIP code polygons with labels and highlight — implemented in Task 2.
    @MapboxMaps.MapContentBuilder
    var zipLayerContent: some MapboxMaps.MapContent {
        // Placeholder — full implementation in Task 2
        if false { Puck2D() }
    }

    // MARK: - Noise Roads Layer (Task 3)

    /// Noise roads with stacked smoke/haze effect — implemented in Task 3.
    @MapboxMaps.MapContentBuilder
    var noiseLayerContent: some MapboxMaps.MapContent {
        // Placeholder — full implementation in Task 3
        if false { Puck2D() }
    }

    // MARK: - GeoJSON Helpers (Overlay Layers)

    /// Fire zones → FeatureCollection of Polygons with severity property.
    private var fireZoneFeatureCollection: FeatureCollection {
        let features = fireZones.map { zone -> Feature in
            var feature = Feature(geometry: .polygon(Polygon([zone.coordinates])))
            feature.properties = ["severity": .string(zone.severity)]
            return feature
        }
        return FeatureCollection(features: features)
    }

    /// Electric lines → FeatureCollection of LineStrings with voltage property.
    private var electricLineFeatureCollection: FeatureCollection {
        let features = electricLines.map { line -> Feature in
            var feature = Feature(geometry: .lineString(LineString(line.coordinates)))
            feature.properties = ["voltage": .number(Double(line.voltage))]
            return feature
        }
        return FeatureCollection(features: features)
    }

    /// Odor zones → FeatureCollection of Polygons with value property.
    private var odorZoneFeatureCollection: FeatureCollection {
        let features = odorZones.map { zone -> Feature in
            var feature = Feature(geometry: .polygon(Polygon([zone.coordinates])))
            feature.properties = ["value": .number(zone.value)]
            return feature
        }
        return FeatureCollection(features: features)
    }

    // MARK: - GeoJSON Helpers (Crime)

    /// Converts crimeHotspots array to a Turf FeatureCollection for the heatmap source.
    private var crimeHotspotsFeatureCollection: FeatureCollection {
        let features = crimeHotspots.map { hotspot -> Feature in
            var feature = Feature(
                geometry: .point(Point(CLLocationCoordinate2D(
                    latitude: hotspot.lat,
                    longitude: hotspot.lon
                )))
            )
            feature.properties = ["weight": .number(hotspot.weight)]
            return feature
        }
        return FeatureCollection(features: features)
    }

    /// Converts DensityGrid cells to a FeatureCollection for cluster markers.
    /// Each cell with count > 0 becomes a Point feature at the cell center.
    private func densityGridFeatureCollection(_ grid: DensityGrid) -> FeatureCollection {
        var features: [Feature] = []
        for row in 0..<grid.rows {
            for col in 0..<grid.cols {
                let count = grid.counts[row][col]
                guard count > 0 else { continue }
                let lat = grid.origin.latitude + (Double(row) + 0.5) * grid.cellSize
                let lon = grid.origin.longitude + (Double(col) + 0.5) * grid.cellSize
                var feature = Feature(
                    geometry: .point(Point(CLLocationCoordinate2D(latitude: lat, longitude: lon)))
                )
                feature.properties = ["count": .number(Double(count))]
                features.append(feature)
            }
        }
        return FeatureCollection(features: features)
    }
}
