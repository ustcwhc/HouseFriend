import SwiftUI
@_spi(Experimental) import MapboxMaps
import CoreLocation  // CLLocationCoordinate2D (MapKit no longer needed after Mapbox migration)
import Turf     // Feature, FeatureCollection, Point for GeoJSON sources

// Disambiguate MapContent/MapContentBuilder (exists in both MapboxMaps and _MapKit_SwiftUI)

// MARK: - HFMapView

struct HFMapView: View {

    // MARK: - Bindings / config
    @Binding var viewport: Viewport
    let selectedCategory: CategoryType
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
    let crimeHotspots: [CrimeHotspot]
    let crimeIncidents: [CrimeIncident]
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
    var onClusterTap: ([CrimeDetail]) -> Void = { _ in }

    // MARK: - Local state
    @State private var currentZoom: Double = 14.0
    @State private var iconsRegistered = false

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
                crimeAreaContent
                crimeHeatmapContent
                crimeClusterContent(proxy: proxy)
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
            .onStyleLoaded { _ in
                registerCrimeIcons(proxy: proxy)
            }
        }
    }

    /// Register SF Symbol images for crime category icons on the map style.
    private func registerCrimeIcons(proxy: MapProxy) {
        guard !iconsRegistered, let map = proxy.map else { return }
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        for (name, id) in [
            ("bolt.shield.fill", "crime-violent"),
            ("house.fill", "crime-property"),
            ("car.fill", "crime-vehicle"),
            ("circle.fill", "crime-other")
        ] {
            if let img = UIImage(systemName: name, withConfiguration: config) {
                try? map.addImage(img, id: id, sdf: true)
            }
        }
        iconsRegistered = true
    }

    private var mapStyleForCategory: MapboxMaps.MapStyle {
        selectedCategory == .crime ? .standard(lightPreset: .night) : .standard(lightPreset: .day)
    }
}

// MARK: - Crime Heatmap

extension HFMapView {

    @MapboxMaps.MapContentBuilder
    var crimeAreaContent: some MapboxMaps.MapContent {
        if selectedCategory == .crime, !tractCrimeDensities.isEmpty {
            GeoJSONSource(id: "crime-tracts")
                .data(.featureCollection(crimeTractFC))

            FillLayer(id: "crime-tract-fill", source: "crime-tracts")
                .fillColor(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.get) { "intensity" }
                    0.0; "rgba(34,197,94,0.10)"
                    0.20; "rgba(163,230,53,0.18)"
                    0.40; "rgba(250,204,21,0.24)"
                    0.60; "rgba(249,115,22,0.30)"
                    0.80; "rgba(239,68,68,0.36)"
                    1.0; "rgba(185,28,28,0.42)"
                })
                .fillOpacity(1.0)

            LineLayer(id: "crime-tract-stroke", source: "crime-tracts")
                .lineColor(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.get) { "intensity" }
                    0.0; "rgba(34,197,94,0.15)"
                    0.40; "rgba(250,204,21,0.28)"
                    0.70; "rgba(249,115,22,0.35)"
                    1.0; "rgba(185,28,28,0.45)"
                })
                .lineWidth(0.8)
        }
    }

    @MapboxMaps.MapContentBuilder
    var crimeHeatmapContent: some MapboxMaps.MapContent {
        if selectedCategory == .crime, !crimeIncidents.isEmpty {
            GeoJSONSource(id: "crime-incidents")
                .data(.featureCollection(crimeIncidentFC))

            // Severity-weighted heatmap: violent crimes produce hotter glow (D-12)
            // Green-to-red gradient (D-13), wide spread ~500m at z14 (D-14)
            HeatmapLayer(id: "crime-heat", source: "crime-incidents")
                .heatmapWeight(Exp(.get) { "weight" })
                .heatmapIntensity(Exp(.interpolate) {
                    Exp(.linear); Exp(.zoom)
                    0; 0.35
                    9; 1.1
                    14; 1.8
                })
                .heatmapRadius(Exp(.interpolate) {
                    Exp(.linear); Exp(.zoom)
                    0; 8
                    9; 32
                    14; 58
                })
                .heatmapColor(Exp(.interpolate) {
                    Exp(.linear)
                    Exp(.heatmapDensity)
                    0;    "rgba(0,0,0,0)"
                    0.12; "rgba(34,197,94,0.12)"
                    0.26; "rgba(163,230,53,0.18)"
                    0.42; "rgba(250,204,21,0.24)"
                    0.58; "rgba(251,146,60,0.34)"
                    0.78; "rgba(239,68,68,0.46)"
                    1.0;  "rgba(127,29,29,0.58)"
                })
                .heatmapOpacity(0.75)
        }
    }

    /// Clustered GeoJSON source — Mapbox merges nearby points at lower zooms
    /// Aggregates severity weight sum for color/size scaling
    private var crimeClusterSource: GeoJSONSource {
        var src = GeoJSONSource(id: "crime-clusters")
        src.cluster = true
        src.clusterRadius = 50
        src.clusterMaxZoom = 14
        src.clusterProperties = [
            "severity_sum": Exp(.accumulated) {
                Exp(.sum) {}
                Exp(.get) { "weight" }
            }
        ]
        return src
    }

    /// Cluster circles + individual crime icons (always visible when crime layer active)
    @MapboxMaps.MapContentBuilder
    func crimeClusterContent(proxy: MapProxy) -> some MapboxMaps.MapContent {
        if selectedCategory == .crime, !crimeIncidents.isEmpty {
            crimeClusterSource
                .data(.featureCollection(crimeIncidentFC))

            // Cluster badges should communicate "how many incidents are here" first,
            // while color still conveys weighted danger.
            CircleLayer(id: "crime-cluster-circles", source: "crime-clusters")
                .filter(Exp(.has) { "point_count" })
                .circleRadius(Exp(.step) {
                    Exp(.get) { "point_count" }; 18; 10; 22; 25; 26; 60; 30
                })
                .circleColor(Exp(.interpolate) {
                    Exp(.linear); Exp(.get) { "severity_sum" }
                    0;   "rgba(180,180,180,1)"   // gray (low)
                    15;  "rgba(251,146,60,1)"    // orange (moderate)
                    40;  "rgba(239,68,68,1)"     // red (high)
                })
                .circleStrokeWidth(2.0)
                .circleStrokeColor(StyleColor(.white))
                .circleEmissiveStrength(1.0)

            // -- Cluster labels: show rounded severity_sum --
            SymbolLayer(id: "crime-cluster-labels", source: "crime-clusters")
                .filter(Exp(.has) { "point_count" })
                .textField(Exp(.coalesce) {
                    Exp(.get) { "point_count_abbreviated" }
                    Exp(.toString) { Exp(.get) { "point_count" } }
                })
                .textSize(13.0)
                .textColor(StyleColor(.white))
                .textFont(["DIN Pro Bold"])
                .textAllowOverlap(true)

            // -- Individual crime icons (unclustered, visible at z15+) --
            makeCrimeSingleIconLayer()

            // -- Tap interactions --
            TapInteraction(.layer("crime-cluster-circles")) { feature, _ in
                handleClusterTap(feature: feature, proxy: proxy)
                return true
            }

            TapInteraction(.layer("crime-single-icons")) { feature, _ in
                handleSingleCrimeTap(feature: feature)
                return true
            }
        }
    }

    /// SymbolLayer for individual unclustered crime icons using pre-registered SF Symbols.
    private func makeCrimeSingleIconLayer() -> SymbolLayer {
        var layer = SymbolLayer(id: "crime-single-icons", source: "crime-clusters")
        layer.filter = Exp(.not) { Exp(.has) { "point_count" } }
        layer.iconImage = .expression(Exp(.match) {
            Exp(.get) { "severity" }
            "violent";  "crime-violent"
            "property"; "crime-property"
            "vehicle";  "crime-vehicle"
            "crime-other"
        })
        layer.iconSize = .constant(1.0)
        layer.iconAllowOverlap = .constant(true)
        // Tint icons by severity color for visual clarity
        layer.iconColor = .expression(Exp(.match) {
            Exp(.get) { "severity" }
            "violent";  "rgba(239,68,68,1)"
            "property"; "rgba(251,146,60,1)"
            "vehicle";  "rgba(234,179,8,1)"
            "rgba(156,163,175,1)"
        })
        layer.iconEmissiveStrength = .constant(1.0)
        return layer
    }

    // MARK: - Cluster tap handlers

    /// Query cluster leaves and surface crime details via onClusterTap callback.
    private func handleClusterTap(feature: FeaturesetFeature, proxy: MapProxy) {
        guard let map = proxy.map else { return }
        // Reconstruct Turf.Feature from public API (geoJsonFeature is internal)
        var clusterFeature = Feature(geometry: feature.geometry)
        clusterFeature.properties = feature.properties
        map.getGeoJsonClusterLeaves(
            forSourceId: "crime-clusters",
            feature: clusterFeature,
            limit: 100,
            offset: 0
        ) { result in
            switch result {
            case .success(let extensionValue):
                let crimes = (extensionValue.features ?? []).compactMap { f -> CrimeDetail? in
                    guard let p = f.properties,
                          case let .string(cat) = p["category"],
                          case let .string(desc) = p["description"],
                          case let .string(date) = p["date"],
                          case let .string(sev) = p["severity"] else { return nil }
                    return CrimeDetail(
                        category: cat, description: desc, date: date,
                        severity: CrimeSeverity(rawValue: sev) ?? .other
                    )
                }
                if !crimes.isEmpty {
                    DispatchQueue.main.async { onClusterTap(crimes) }
                }
            case .failure(let error):
                AppLogger.map.error("Failed to get cluster leaves: \(error)")
            }
        }
    }

    /// Extract single crime detail from an unclustered feature.
    private func handleSingleCrimeTap(feature: FeaturesetFeature) {
        let p = feature.properties
        guard case let .string(cat) = p["category"],
              case let .string(desc) = p["description"],
              case let .string(date) = p["date"],
              case let .string(sev) = p["severity"] else { return }
        let detail = CrimeDetail(
            category: cat, description: desc, date: date,
            severity: CrimeSeverity(rawValue: sev) ?? .other
        )
        DispatchQueue.main.async { onClusterTap([detail]) }
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
        if selectedCategory == .population, !zipRegions.isEmpty {
            GeoJSONSource(id: "zip-polygons")
                .data(.featureCollection(zipPolygonFC))

            FillLayer(id: "zip-fill", source: "zip-polygons")
                .fillColor(Exp(.match) {
                    Exp(.get) { "isHighlighted" }
                    "true";  "rgba(255,45,85,0.28)"
                    "rgba(255,235,77,0.06)"
                })
                .fillOpacity(1.0)

            LineLayer(id: "zip-stroke", source: "zip-polygons")
                .lineColor(Exp(.match) {
                    Exp(.get) { "isHighlighted" }
                    "true";  "rgba(255,45,85,0.85)"
                    "rgba(212,175,55,0.70)"
                })
                .lineWidth(Exp(.match) {
                    Exp(.get) { "isHighlighted" }
                    "true";  2.5
                    1.5
                })

            GeoJSONSource(id: "zip-labels")
                .data(.featureCollection(zipLabelFC))

            SymbolLayer(id: "zip-labels", source: "zip-labels")
                .textField(Exp(.get) { "zipId" })
                .textSize(10.0)
                .textColor(StyleColor(UIColor.darkText))
                .textHaloColor(StyleColor(UIColor.white.withAlphaComponent(0.75)))
                .textHaloWidth(1.0)
                .textAllowOverlap(false)
        }
    }

    @MapboxMaps.MapContentBuilder
    var noiseLayerContent: some MapboxMaps.MapContent {
        if selectedCategory == .noise, !noiseRoads.isEmpty {
            GeoJSONSource(id: "noise-roads")
                .data(.featureCollection(noiseRoadFC))

            // Layer 1: Wide outer haze
            LineLayer(id: "noise-haze-outer", source: "noise-roads")
                .lineWidth(Exp(.product) { Exp(.get) { "lineWidth" }; 12.0 })
                .lineColor(StyleColor(UIColor(white: 0.08, alpha: 1.0)))
                .lineOpacity(Exp(.product) { 0.025; Exp(.get) { "intensity" } })
                .lineBlur(8.0)
                .lineCap(.round)
                .lineJoin(.round)

            // Layer 2: Mid haze
            LineLayer(id: "noise-haze-mid", source: "noise-roads")
                .lineWidth(Exp(.product) { Exp(.get) { "lineWidth" }; 6.0 })
                .lineColor(StyleColor(UIColor(white: 0.10, alpha: 1.0)))
                .lineOpacity(Exp(.product) { 0.06; Exp(.get) { "intensity" } })
                .lineBlur(4.0)
                .lineCap(.round)
                .lineJoin(.round)

            // Layer 3: Inner smoke
            LineLayer(id: "noise-smoke-inner", source: "noise-roads")
                .lineWidth(Exp(.product) { Exp(.get) { "lineWidth" }; 3.0 })
                .lineColor(StyleColor(UIColor(white: 0.12, alpha: 1.0)))
                .lineOpacity(Exp(.product) { 0.12; Exp(.get) { "intensity" } })
                .lineBlur(2.0)
                .lineCap(.round)
                .lineJoin(.round)

            // Layer 4: Core colored line (non-railway roads)
            makeNoiseCoreLayer()

            // Layer 5: Railway dashed overlay
            makeNoiseRailwayLayer()
        }
    }

    /// Core noise line with filter. Helper because `filter` isn't chainable.
    private func makeNoiseCoreLayer() -> LineLayer {
        var layer = LineLayer(id: "noise-core", source: "noise-roads")
        layer.lineWidth = .expression(Exp(.get) { "lineWidth" })
        layer.lineColor = .expression(noiseDbColorExp)
        layer.lineOpacity = .constant(0.75)
        layer.lineCap = .constant(.round)
        layer.lineJoin = .constant(.round)
        layer.filter = Exp(.eq) { Exp(.get) { "isRailway" }; "false" }
        return layer
    }

    /// Railway segments with dashed pattern.
    private func makeNoiseRailwayLayer() -> LineLayer {
        var layer = LineLayer(id: "noise-railway", source: "noise-roads")
        layer.lineWidth = .expression(Exp(.get) { "lineWidth" })
        layer.lineColor = .expression(noiseDbColorExp)
        layer.lineOpacity = .constant(0.75)
        layer.lineCap = .constant(.round)
        layer.lineJoin = .constant(.round)
        layer.lineDasharray = .constant([3.0, 2.0])
        layer.filter = Exp(.eq) { Exp(.get) { "isRailway" }; "true" }
        return layer
    }

    /// Step expression: dB level -> color matching NoiseService.color(for:).
    private var noiseDbColorExp: Exp {
        Exp(.step) {
            Exp(.get) { "dbLevel" }
            "rgba(102,217,102,1)"       // <50: green
            50; "rgba(255,235,26,1)"    // 50-54: yellow
            55; "rgba(255,184,0,1)"     // 55-59: orange
            60; "rgba(255,115,0,1)"     // 60-64: dark orange
            65; "rgba(235,26,77,1)"     // 65-69: red-pink
            70; "rgba(153,0,184,1)"     // 70-77: purple
            78; "rgba(71,0,128,1)"      // 78+: dark purple
        }
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

    private var zipPolygonFC: FeatureCollection {
        FeatureCollection(features: zipRegions.map { region in
            var f = Feature(geometry: .polygon(Polygon([region.polygon])))
            f.properties = [
                "zipId": .string(region.id),
                "isHighlighted": .string(region.id == highlightedZIPId ? "true" : "false")
            ]
            return f
        })
    }

    private var zipLabelFC: FeatureCollection {
        FeatureCollection(features: zipRegions.map { region in
            var f = Feature(geometry: .point(Point(region.center)))
            f.properties = ["zipId": .string(region.id)]
            return f
        })
    }

    private var noiseRoadFC: FeatureCollection {
        FeatureCollection(features: noiseRoads.map { road in
            var f = Feature(geometry: .lineString(LineString(road.coordinates)))
            let intensity = min(max(Double(road.dbLevel) - 40.0, 0), 38.0) / 38.0
            f.properties = [
                "dbLevel": .number(Double(road.dbLevel)),
                "lineWidth": .number(road.lineWidth),
                "isRailway": .string(road.isRailway ? "true" : "false"),
                "intensity": .number(intensity)
            ]
            return f
        })
    }

    private var crimeTractFC: FeatureCollection {
        FeatureCollection(features: censusTracts.compactMap { tract in
            guard let intensity = tractCrimeDensities[tract.id] else { return nil }
            var f = Feature(geometry: .polygon(Polygon([tract.polygon])))
            f.properties = ["intensity": .number(intensity)]
            return f
        })
    }

    /// Builds GeoJSON from raw crime incidents with severity properties.
    /// Each feature carries weight, severity key, category, description, and date
    /// for both heatmap rendering and future cluster detail sheets.
    private var crimeIncidentFC: FeatureCollection {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return FeatureCollection(features: crimeIncidents.map { incident in
            let severity = CrimeSeverity.from(category: incident.category)
            var f = Feature(geometry: .point(Point(incident.coordinate)))
            f.properties = [
                "weight": .number(severity.weight),
                "severity": .string(severity.key),
                "category": .string(incident.category),
                "description": .string(incident.description),
                "date": .string(df.string(from: incident.date))
            ]
            return f
        })
    }

}
