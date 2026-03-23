import SwiftUI
@_spi(Experimental) import MapboxMaps
import MapKit   // CLLocationCoordinate2D, MKCoordinateRegion (used by service types)
import Turf     // Feature, FeatureCollection, Point for GeoJSON sources

// Disambiguate MapContent/MapContentBuilder (exists in both MapboxMaps and _MapKit_SwiftUI)

// MARK: - HFMapView

struct HFMapView: View {

    // MARK: - Bindings / config
    @Binding var viewport: Viewport
    let selectedCategory: CategoryType
    let showCrimeDetails: Bool
    let pinnedLocation: CLLocationCoordinate2D?

    // MARK: - Layer data
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

    // MARK: - Callbacks
    var onCameraChange: (CLLocationCoordinate2D, Double) -> Void = { _, _ in }
    var onSchoolTap: (School) -> Void = { _ in }
    var onSuperfundTap: (SuperfundSite) -> Void = { _ in }
    var onHousingTap: (SupportiveHousingFacility) -> Void = { _ in }
    var onZIPTap: (ZIPCodeRegion) -> Void = { _ in }
    var onMapTap: (CLLocationCoordinate2D) -> Void = { _ in }
    var onNoiseFetchCancel: () -> Void = {}
    var onMapLongPress: (CLLocationCoordinate2D) -> Void = { _ in }

    // MARK: - Local state
    @State private var currentZoom: Double = 14.0

    // MARK: - Body

    var body: some View {
        MapboxMaps.MapReader { proxy in
            MapboxMaps.Map(viewport: $viewport) {
                Puck2D(bearing: .heading)
                fireLayerContent
                electricLayerContent
                odorLayerContent
                zipLayerContent
                noiseLayerContent
                crimeHeatmapContent
                crimeClusterContent
                annotationContent
            }
            .mapStyle(mapStyleForCategory)
            .onMapTapGesture { context in onMapTap(context.coordinate) }
            .onMapLongPressGesture { context in onMapLongPress(context.coordinate) }
            .onCameraChanged { context in
                let center = context.cameraState.center
                let zoom = context.cameraState.zoom
                currentZoom = zoom
                onCameraChange(center, zoom)
            }
        }
    }

    private var mapStyleForCategory: MapboxMaps.MapStyle {
        selectedCategory == .crime ? .standard(lightPreset: .night) : .standard(lightPreset: .day)
    }
}

// MARK: - Crime Heatmap

extension HFMapView {

    @MapboxMaps.MapContentBuilder
    var crimeHeatmapContent: some MapboxMaps.MapContent {
        if selectedCategory == .crime, !crimeHotspots.isEmpty {
            GeoJSONSource(id: "crime-incidents")
                .data(.featureCollection(crimeHotspotsFC))

            HeatmapLayer(id: "crime-heat", source: "crime-incidents")
                .heatmapWeight(Exp(.get) { "weight" })
                .heatmapIntensity(Exp(.interpolate) {
                    Exp(.linear); Exp(.zoom); 0; 1; 9; 3
                })
                .heatmapRadius(Exp(.interpolate) {
                    Exp(.linear); Exp(.zoom); 0; 2; 9; 20; 14; 30
                })
                .heatmapColor(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.heatmapDensity)
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

    @MapboxMaps.MapContentBuilder
    var crimeClusterContent: some MapboxMaps.MapContent {
        if selectedCategory == .crime, showCrimeDetails, let grid = densityGrid {
            GeoJSONSource(id: "crime-clusters")
                .data(.featureCollection(densityGridFC(grid)))

            CircleLayer(id: "crime-cluster-circles", source: "crime-clusters")
                .circleRadius(Exp(.step) {
                    Exp(.get) { "count" }; 14; 5; 17; 20; 20
                })
                .circleColor(StyleColor(.white))
                .circleStrokeWidth(2.0)
                .circleStrokeColor(Exp(.step) {
                    Exp(.get) { "count" }; "gray"; 5; "orange"; 10; "red"
                })

            SymbolLayer(id: "crime-cluster-labels", source: "crime-clusters")
                .textField(Exp(.toString) { Exp(.get) { "count" } })
                .textSize(12.0)
                .textColor(Exp(.step) {
                    Exp(.get) { "count" }; "gray"; 5; "orange"; 10; "red"
                })
                .textFont(["DIN Pro Bold"])
                .textAllowOverlap(true)
        }
    }
}

// MARK: - Annotations

extension HFMapView {

    @MapboxMaps.MapContentBuilder
    var annotationContent: some MapboxMaps.MapContent {
        if selectedCategory == .schools {
            let levels = ZoomTier(zoom: currentZoom).schoolLevelsToShow()
            ForEvery(schools.filter { levels.contains($0.level) }, id: \.id) { school in
                MapViewAnnotation(coordinate: school.coordinate) {
                    Image(systemName: "graduationcap.fill")
                        .foregroundStyle(schoolColor(school.level))
                        .font(.title3)
                        .onTapGesture { onSchoolTap(school) }
                }
            }
        }

        if selectedCategory == .superfund, ZoomTier(zoom: currentZoom).showsCityAnnotations {
            ForEvery(superfundSites, id: \.id) { site in
                MapViewAnnotation(coordinate: site.coordinate) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                        .onTapGesture { onSuperfundTap(site) }
                }
            }
        }

        if selectedCategory == .earthquake, ZoomTier(zoom: currentZoom).showsCityAnnotations {
            ForEvery(earthquakes, id: \.id) { event in
                MapViewAnnotation(coordinate: event.coordinate) {
                    Text(String(format: "%.1f", event.magnitude))
                        .font(.caption.bold())
                        .foregroundStyle(earthquakeColor(event.magnitude))
                        .padding(4)
                        .background(Circle().fill(.white.opacity(0.85)))
                }
            }
        }

        if selectedCategory == .supportiveHome, ZoomTier(zoom: currentZoom).showsNeighborhoodAnnotations {
            ForEvery(housingFacilities, id: \.id) { facility in
                MapViewAnnotation(coordinate: facility.coordinate) {
                    Image(systemName: "house.fill")
                        .foregroundStyle(.teal)
                        .font(.title3)
                        .onTapGesture { onHousingTap(facility) }
                }
            }
        }

        if let pin = pinnedLocation {
            MapViewAnnotation(coordinate: pin) {
                Image(systemName: "mappin")
                    .foregroundStyle(.red)
                    .font(.title)
            }
        }
    }

    private func schoolColor(_ level: SchoolLevel) -> Color {
        switch level {
        case .elementary: return .green
        case .middle:     return .blue
        case .high:       return .purple
        }
    }

    private func earthquakeColor(_ magnitude: Double) -> Color {
        if magnitude >= 5.0 { return .red }
        if magnitude >= 4.0 { return .orange }
        return .yellow
    }
}

// MARK: - Overlay Layers (Plan 02.1-02)

extension HFMapView {

    @MapboxMaps.MapContentBuilder
    var fireLayerContent: some MapboxMaps.MapContent {
        if selectedCategory == .fireHazard, !fireZones.isEmpty {
            GeoJSONSource(id: "fire-zones")
                .data(.featureCollection(fireZoneFC))

            FillLayer(id: "fire-fill", source: "fire-zones")
                .fillColor(Exp(.match) {
                    Exp(.get) { "severity" }
                    "extreme";   "rgba(184,5,5,1.0)"
                    "very high"; "rgba(230,51,13,1.0)"
                    "high";      "rgba(242,128,26,1.0)"
                    "rgba(242,217,26,1.0)"
                })
                .fillOpacity(0.40)

            LineLayer(id: "fire-stroke", source: "fire-zones")
                .lineColor(Exp(.match) {
                    Exp(.get) { "severity" }
                    "extreme";   "rgba(184,5,5,0.7)"
                    "very high"; "rgba(230,51,13,0.7)"
                    "high";      "rgba(242,128,26,0.7)"
                    "rgba(242,217,26,0.7)"
                })
                .lineWidth(1.5)
        }
    }

    @MapboxMaps.MapContentBuilder
    var electricLayerContent: some MapboxMaps.MapContent {
        if selectedCategory == .electricLines, !electricLines.isEmpty {
            GeoJSONSource(id: "electric-lines")
                .data(.featureCollection(electricLineFC))

            LineLayer(id: "electric-line", source: "electric-lines")
                .lineColor(StyleColor(UIColor.systemYellow.withAlphaComponent(0.75)))
                .lineWidth(2.5)
        }
    }

    @MapboxMaps.MapContentBuilder
    var odorLayerContent: some MapboxMaps.MapContent {
        if selectedCategory == .milpitasOdor, !odorZones.isEmpty {
            GeoJSONSource(id: "odor-zones")
                .data(.featureCollection(odorZoneFC))

            FillLayer(id: "odor-fill", source: "odor-zones")
                .fillColor(StyleColor(UIColor.systemBrown.withAlphaComponent(0.30)))

            LineLayer(id: "odor-stroke", source: "odor-zones")
                .lineColor(StyleColor(UIColor.systemBrown.withAlphaComponent(0.55)))
                .lineWidth(1.0)
        }
    }

    @MapboxMaps.MapContentBuilder
    var zipLayerContent: some MapboxMaps.MapContent {
        if false { Puck2D() }
    }

    @MapboxMaps.MapContentBuilder
    var noiseLayerContent: some MapboxMaps.MapContent {
        if false { Puck2D() }
    }
}

// MARK: - GeoJSON Helpers

extension HFMapView {

    private var fireZoneFC: FeatureCollection {
        FeatureCollection(features: fireZones.map { zone in
            var f = Feature(geometry: .polygon(Polygon([zone.coordinates])))
            f.properties = ["severity": .string(zone.severity)]
            return f
        })
    }

    private var electricLineFC: FeatureCollection {
        FeatureCollection(features: electricLines.map { line in
            var f = Feature(geometry: .lineString(LineString(line.coordinates)))
            f.properties = ["voltage": .number(Double(line.voltage))]
            return f
        })
    }

    private var odorZoneFC: FeatureCollection {
        FeatureCollection(features: odorZones.map { zone in
            var f = Feature(geometry: .polygon(Polygon([zone.coordinates])))
            f.properties = ["value": .number(zone.value)]
            return f
        })
    }

    private var crimeHotspotsFC: FeatureCollection {
        FeatureCollection(features: crimeHotspots.map { h in
            var f = Feature(geometry: .point(Point(
                CLLocationCoordinate2D(latitude: h.lat, longitude: h.lon)
            )))
            f.properties = ["weight": .number(h.weight)]
            return f
        })
    }

    private func densityGridFC(_ grid: DensityGrid) -> FeatureCollection {
        var features: [Feature] = []
        for row in 0..<grid.rows {
            for col in 0..<grid.cols {
                let count = grid.counts[row][col]
                guard count > 0 else { continue }
                let lat = grid.origin.latitude + (Double(row) + 0.5) * grid.cellSize
                let lon = grid.origin.longitude + (Double(col) + 0.5) * grid.cellSize
                var f = Feature(geometry: .point(Point(
                    CLLocationCoordinate2D(latitude: lat, longitude: lon)
                )))
                f.properties = ["count": .number(Double(count))]
                features.append(f)
            }
        }
        return FeatureCollection(features: features)
    }
}
