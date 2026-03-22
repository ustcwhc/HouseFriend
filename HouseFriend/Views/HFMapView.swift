import SwiftUI
import MapKit

// MARK: - HFMapView
// Replaces SwiftUI Map{} to unlock full MapKit overlay capabilities:
//   • CrimeTileOverlay  — follows map perfectly, MapKit-cached
//   • MKPolyline        — UIKit renderer for noise roads (no SwiftUI ForEach lag)
//   • MKPolygon         — fire, zip, odor zones
//   • MKAnnotationView  — schools, superfund, earthquake, housing, crime markers

struct HFMapView: UIViewRepresentable {

    // MARK: - Bindings / config
    @Binding var region: MKCoordinateRegion
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

    // MARK: - Callbacks → ContentView
    var onCameraChange: (MKCoordinateRegion) -> Void = { _ in }
    var onSchoolTap: (School) -> Void = { _ in }
    var onSuperfundTap: (SuperfundSite) -> Void = { _ in }
    var onHousingTap: (SupportiveHousingFacility) -> Void = { _ in }
    var onZIPTap: (ZIPCodeRegion) -> Void = { _ in }
    var onMapTap: (CLLocationCoordinate2D) -> Void = { _ in }
    var onNoiseFetchCancel: () -> Void = {}
    var onMapLongPress: (CLLocationCoordinate2D) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = false
        map.setRegion(region, animated: false)

        // Tap: annotation selection / ZIP polygon detection
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)

        // Long press: drop GPS pin + open neighborhood report
        let lp = UILongPressGestureRecognizer(target: context.coordinator,
                                              action: #selector(Coordinator.handleLongPress(_:)))
        lp.minimumPressDuration = 0.45
        lp.delegate = context.coordinator
        map.addGestureRecognizer(lp)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncRegion(map)
        context.coordinator.updateOverlays(map)
        context.coordinator.updateAnnotations(map)
        context.coordinator.updateZIPHighlight(map)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: HFMapView

        // Track active overlays to diff efficiently
        private var activeCategory: CategoryType?
        private var lastZoomTier: ZoomTier?
        private var crimeTileOverlay: CrimeTileOverlay?
        private var crimePolygonRenderers: [String: MKPolygonRenderer] = [:]
        private var lastCrimeDensityCount = 0
        private var noisePolylines: [MKPolyline] = []
        private var lastNoiseHash = 0

        // Annotations: stable IDs → avoid flicker on re-render
        private var annotationMap: [String: HFAnnotation] = [:]

        // ZIP polygon renderers — stored so we can update highlight color without
        // removing/re-adding overlays (which would flicker)
        private var zipRenderers: [String: MKPolygonRenderer] = [:]
        private var lastHighlightedZIPId: String? = nil

        // Debounce: don't push region changes back while we're animating programmatically
        private var suppressRegionCallback = false

        init(_ parent: HFMapView) { self.parent = parent }

        // MARK: - Region sync

        func syncRegion(_ map: MKMapView) {
            let cur = map.region
            let new = parent.region
            // Only animate if difference is significant (avoids jitter from rounding)
            let latDiff = abs(cur.center.latitude  - new.center.latitude)
            let lonDiff = abs(cur.center.longitude - new.center.longitude)
            let spanDiff = abs(cur.span.latitudeDelta - new.span.latitudeDelta)
            if latDiff > 0.0005 || lonDiff > 0.0005 || spanDiff > 0.005 {
                suppressRegionCallback = true
                map.setRegion(new, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.suppressRegionCallback = false
                }
            }
        }

        // MARK: - Overlay management

        func updateOverlays(_ map: MKMapView) {
            let cat = parent.selectedCategory

            // Noise roads: update whenever road list changes (even same category)
            if cat == .noise {
                if cat != activeCategory {
                    // Switching to noise: remove everything else first
                    map.removeOverlays(map.overlays)
                    noisePolylines = []
                    crimeTileOverlay = nil
                    activeCategory = cat
                }
                updateNoisePolylines(map)
                return
            }

            // Crime: check if density grid changed and needs tile refresh
            if cat == .crime && cat == activeCategory {
                // Refresh visible tracts on pan/zoom or when densities change
                addVisibleCrimeTracts(map)
                return
            }

            // For all other categories: only rebuild when category changes
            guard cat != activeCategory else { return }

            map.removeOverlays(map.overlays)
            noisePolylines = []
            lastNoiseHash = 0   // B1 fix: reset so noise rebuild works if we return
            crimeTileOverlay = nil
            crimePolygonRenderers = [:]
            lastCrimeDensityCount = 0
            zipRenderers = [:]
            activeCategory = cat

            switch cat {
            case .crime:
                // Polygon-based crime heatmap — only add tracts visible in current viewport
                // to avoid Metal buffer overflow (1,772 tracts is too many for MapKit at once)
                addVisibleCrimeTracts(map)

            case .fireHazard:
                for zone in parent.fireZones {
                    let poly = MKPolygon(coordinates: zone.coordinates,
                                        count: zone.coordinates.count)
                    poly.title = "fire:\(zone.severity)"
                    map.addOverlay(poly, level: .aboveRoads)
                }

            case .electricLines:
                for line in parent.electricLines {
                    let poly = MKPolyline(coordinates: line.coordinates,
                                         count: line.coordinates.count)
                    poly.title = "electric:\(line.voltage)"
                    map.addOverlay(poly, level: .aboveRoads)
                }

            case .milpitasOdor:
                for zone in parent.odorZones {
                    let poly = MKPolygon(coordinates: zone.coordinates,
                                        count: zone.coordinates.count)
                    poly.title = "odor:\(zone.value)"
                    map.addOverlay(poly, level: .aboveRoads)
                }

            case .population:
                for region in parent.zipRegions {
                    let poly = MKPolygon(coordinates: region.polygon,
                                        count: region.polygon.count)
                    poly.title = "zip:\(region.id)"
                    map.addOverlay(poly, level: .aboveRoads)
                }

            default:
                break   // annotation-only layers (schools, superfund, quake, housing)
            }
        }

        private func updateNoisePolylines(_ map: MKMapView) {
            let roads = parent.noiseRoads
            // Skip if nothing changed (hash on count + first/last wayId)
            var hasher = Hasher()
            hasher.combine(roads.count)
            if let first = roads.first { hasher.combine(first.wayId) }
            if let last = roads.last { hasher.combine(last.wayId) }
            let hash = hasher.finalize()
            guard hash != lastNoiseHash else { return }
            map.removeOverlays(noisePolylines)
            noisePolylines = []
            lastNoiseHash = hash
            for road in roads {
                let poly = MKPolyline(coordinates: road.coordinates,
                                      count: road.coordinates.count)
                // rail flag: "r" suffix triggers dashed rendering
                let railFlag = road.isRailway ? ":r" : ""
                poly.title = "noise:\(road.dbLevel):\(road.lineWidth)\(railFlag)"
                map.addOverlay(poly, level: .aboveRoads)
                noisePolylines.append(poly)
            }
        }

        // MARK: - Annotation management

        func updateAnnotations(_ map: MKMapView) {
            let tier = ZoomTier(region: map.region)
            var wanted: [String: HFAnnotation] = [:]

            switch parent.selectedCategory {
            case .schools:
                let levels = tier.schoolLevelsToShow()
                for s in parent.schools where levels.contains(s.level) {
                    let key = "school-\(s.id)"
                    wanted[key] = annotationMap[key]
                        ?? HFAnnotation(coordinate: s.coordinate, data: .school(s), key: key)
                }
            case .superfund:
                if tier.showsCityAnnotations {
                    for s in parent.superfundSites {
                        let key = "sfund-\(s.id)"
                        wanted[key] = annotationMap[key]
                            ?? HFAnnotation(coordinate: s.coordinate, data: .superfund(s), key: key)
                    }
                }
            case .supportiveHome:
                if tier.showsNeighborhoodAnnotations {
                    for h in parent.housingFacilities {
                        let key = "house-\(h.id)"
                        wanted[key] = annotationMap[key]
                            ?? HFAnnotation(coordinate: h.coordinate, data: .housing(h), key: key)
                    }
                }
            case .earthquake:
                if tier.showsCityAnnotations {
                    for e in parent.earthquakes {
                        let key = "quake-\(e.id)"
                        wanted[key] = annotationMap[key]
                            ?? HFAnnotation(coordinate: e.coordinate, data: .earthquake(e), key: key)
                    }
                }
            case .population:
                if tier.showsCountyOverlays {
                    for r in parent.zipRegions {
                        let key = "zip-\(r.id)"
                        wanted[key] = annotationMap[key]
                            ?? HFAnnotation(coordinate: r.center, data: .zip(r), key: key)
                    }
                }
            case .crime:
                if parent.showCrimeDetails, let grid = parent.densityGrid, tier.showsCrimeMarkers {
                    for row in 0..<grid.rows {
                        for col in 0..<grid.cols {
                            let count = grid.counts[row][col]
                            guard count > 0 else { continue }
                            let lat = grid.origin.latitude + Double(row) * grid.cellSize + grid.cellSize / 2
                            let lon = grid.origin.longitude + Double(col) * grid.cellSize + grid.cellSize / 2
                            let key = "crime-cluster-\(row)-\(col)"
                            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            wanted[key] = annotationMap[key]
                                ?? HFAnnotation(coordinate: coord, data: .crimeCluster(coordinate: coord, count: count), key: key)
                        }
                    }
                }
            default:
                break
            }

            // Pin
            if let pin = parent.pinnedLocation {
                let key = "pin"
                wanted[key] = annotationMap[key]
                    ?? HFAnnotation(coordinate: pin, data: .pin, key: key)
            }

            // Diff: remove stale, add new
            let currentKeys = Set(annotationMap.keys)
            let wantedKeys  = Set(wanted.keys)
            let toRemove = currentKeys.subtracting(wantedKeys).compactMap { annotationMap[$0] }
            let toAdd    = wantedKeys.subtracting(currentKeys).compactMap { wanted[$0] }
            if !toRemove.isEmpty { map.removeAnnotations(toRemove) }
            if !toAdd.isEmpty    { map.addAnnotations(toAdd) }
            annotationMap = wanted
        }

        // MARK: - MKMapViewDelegate

        // B2: cancel in-flight Overpass requests when user starts panning
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            if parent.selectedCategory == .noise {
                parent.onNoiseFetchCancel()
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard !suppressRegionCallback else { return }
            parent.onCameraChange(mapView.region)

            // Refresh annotations when zoom tier changes (show/hide by level)
            let tier = ZoomTier(region: mapView.region)
            if tier != lastZoomTier {
                lastZoomTier = tier
                updateAnnotations(mapView)
            }
        }

        func mapView(_ mapView: MKMapView,
                     rendererFor overlay: MKOverlay) -> MKOverlayRenderer {

            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }

            if let polyline = overlay as? MKPolyline,
               let title = polyline.title {
                let r = MKPolylineRenderer(polyline: polyline)
                if title.hasPrefix("noise:") {
                    // Smoke renderer handles noise polylines
                    let parts = title.split(separator: ":")
                    let db = Int(Double(parts[safe: 1] ?? "") ?? 55)
                    let lw  = CGFloat(Double(parts[safe: 2] ?? "") ?? 2)
                    let rail = parts.count >= 4 && parts[3] == "r"
                    return NoiseSmokeRenderer(polyline: polyline,
                                              dbLevel: db,
                                              lineWidth: lw,
                                              isRailway: rail)
                } else if title.hasPrefix("electric:") {
                    r.strokeColor = UIColor.systemYellow.withAlphaComponent(0.75)
                    r.lineWidth   = 2.5
                }
                return r
            }

            if let polygon = overlay as? MKPolygon,
               let title = polygon.title {
                let r = MKPolygonRenderer(polygon: polygon)
                if title.hasPrefix("fire:") {
                    let severity = String(title.dropFirst(5))
                    let col = fireUIColor(severity)
                    r.fillColor   = col.withAlphaComponent(0.40)
                    r.strokeColor = col.withAlphaComponent(0.70)
                    r.lineWidth   = 1.5
                } else if title.hasPrefix("odor:") {
                    r.fillColor   = UIColor.systemBrown.withAlphaComponent(0.30)
                    r.strokeColor = UIColor.systemBrown.withAlphaComponent(0.55)
                    r.lineWidth   = 1
                } else if title.hasPrefix("crime:") {
                    let zipId = String(title.dropFirst(6))
                    applyCrimeStyle(r, zipId: zipId)
                    crimePolygonRenderers[zipId] = r
                } else if title.hasPrefix("zip:") {
                    let zipId = String(title.dropFirst(4))
                    applyZipStyle(r, selected: zipId == parent.highlightedZIPId)
                    zipRenderers[zipId] = r
                }
                return r
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: - Crime tract management (viewport-based)

        /// Adds/removes crime tract polygons based on viewport visibility.
        /// Only tracts whose center is within the visible map region (+ padding) are added.
        /// This prevents Metal buffer overflow from adding all 1,772 tracts at once.
        private func addVisibleCrimeTracts(_ map: MKMapView) {
            let region = map.region
            let padding = 0.05  // Extra margin around viewport
            let minLat = region.center.latitude - region.span.latitudeDelta / 2 - padding
            let maxLat = region.center.latitude + region.span.latitudeDelta / 2 + padding
            let minLon = region.center.longitude - region.span.longitudeDelta / 2 - padding
            let maxLon = region.center.longitude + region.span.longitudeDelta / 2 + padding

            // Determine which tracts should be visible
            var wantedIds = Set<String>()
            for tract in parent.censusTracts {
                let lat = tract.center.latitude
                let lon = tract.center.longitude
                if lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon {
                    wantedIds.insert(tract.id)
                }
            }

            // Remove tracts that scrolled out of view
            let currentIds = Set(crimePolygonRenderers.keys)
            let toRemove = currentIds.subtracting(wantedIds)
            if !toRemove.isEmpty {
                for overlay in map.overlays {
                    if let poly = overlay as? MKPolygon,
                       let title = poly.title, title.hasPrefix("crime:") {
                        let id = String(title.dropFirst(6))
                        if toRemove.contains(id) {
                            map.removeOverlay(poly)
                            crimePolygonRenderers.removeValue(forKey: id)
                        }
                    }
                }
            }

            // Add tracts that scrolled into view
            let toAdd = wantedIds.subtracting(currentIds)
            for tract in parent.censusTracts where toAdd.contains(tract.id) {
                let poly = MKPolygon(coordinates: tract.polygon, count: tract.polygon.count)
                poly.title = "crime:\(tract.id)"
                map.addOverlay(poly, level: .aboveRoads)
            }

            // Update colors if densities changed
            let newCount = parent.tractCrimeDensities.count
            if newCount != lastCrimeDensityCount {
                lastCrimeDensityCount = newCount
                for (id, renderer) in crimePolygonRenderers {
                    applyCrimeStyle(renderer, zipId: id)
                    renderer.setNeedsDisplay()
                }
            }
        }

        // MARK: - Crime polygon styling

        private func applyCrimeStyle(_ r: MKPolygonRenderer, zipId: String) {
            let intensity = parent.tractCrimeDensities[zipId] ?? 0.0

            if intensity <= 0.0 {
                // No crime data for this ZIP — very light transparent fill
                r.fillColor = UIColor(red: 0.95, green: 0.93, blue: 0.85, alpha: 0.15)
                r.strokeColor = UIColor(red: 0.85, green: 0.82, blue: 0.75, alpha: 0.25)
                r.lineWidth = 0.5
            } else {
                // Color gradient matching the competitor: beige → orange → red
                let (red, green, blue) = crimeRGB(intensity)
                let fillAlpha = 0.25 + intensity * 0.45  // 0.25-0.70
                let strokeAlpha = 0.40 + intensity * 0.40  // 0.40-0.80
                r.fillColor = UIColor(red: red, green: green, blue: blue, alpha: fillAlpha)
                r.strokeColor = UIColor(red: red, green: green, blue: blue, alpha: strokeAlpha)
                r.lineWidth = 1.0
            }
        }

        /// Crime intensity to RGB color (beige → amber → orange → red)
        private func crimeRGB(_ v: Double) -> (CGFloat, CGFloat, CGFloat) {
            if v >= 0.8 { return (191/255.0,  13/255.0,  13/255.0) }  // Dark red
            if v >= 0.6 { return (235/255.0,  64/255.0,  20/255.0) }  // Orange-red
            if v >= 0.4 { return (250/255.0, 133/255.0,  38/255.0) }  // Orange
            if v >= 0.25 { return (254/255.0, 184/255.0,  89/255.0) }  // Amber
            if v >= 0.1 { return (255/255.0, 219/255.0, 153/255.0) }  // Light amber
            return              (255/255.0, 238/255.0, 200/255.0)      // Beige
        }

        // MARK: - ZIP highlight

        private func applyZipStyle(_ r: MKPolygonRenderer, selected: Bool) {
            if selected {
                r.fillColor   = UIColor.systemPink.withAlphaComponent(0.28)
                r.strokeColor = UIColor.systemPink.withAlphaComponent(0.85)
                r.lineWidth   = 2.5
            } else {
                // Light yellow border — clearly visible against map streets (gray)
                r.fillColor   = UIColor(red: 1.0, green: 0.92, blue: 0.3, alpha: 0.06)
                r.strokeColor = UIColor(red: 0.88, green: 0.72, blue: 0.0, alpha: 0.70)
                r.lineWidth   = 1.5
            }
        }

        func updateZIPHighlight(_ map: MKMapView) {
            guard parent.highlightedZIPId != lastHighlightedZIPId else { return }
            let newId = parent.highlightedZIPId
            lastHighlightedZIPId = newId
            for (zipId, renderer) in zipRenderers {
                applyZipStyle(renderer, selected: zipId == newId)
                renderer.setNeedsDisplay()
            }
        }

        private func fireUIColor(_ severity: String) -> UIColor {
            switch severity.lowercased() {
            case "extreme":   return UIColor(red: 0.72, green: 0.02, blue: 0.02, alpha: 1)
            case "very high": return UIColor(red: 0.90, green: 0.20, blue: 0.05, alpha: 1)
            case "high":      return UIColor(red: 0.95, green: 0.50, blue: 0.10, alpha: 1)
            default:          return UIColor(red: 0.95, green: 0.85, blue: 0.10, alpha: 1)
            }
        }

        // MARK: - Annotation views

        func mapView(_ mapView: MKMapView,
                     viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let ann = annotation as? HFAnnotation else { return nil }

            switch ann.data {

            case .school(let s):
                let v = dequeue(mapView, id: "school", as: MKMarkerAnnotationView.self)
                v.annotation    = ann
                v.glyphImage    = UIImage(systemName: "graduationcap.fill")
                v.markerTintColor = s.level == .elementary ? .systemGreen
                                  : s.level == .middle     ? .systemBlue
                                                           : .systemPurple
                v.canShowCallout = true
                v.titleVisibility = .hidden
                return v

            case .superfund:
                let v = dequeue(mapView, id: "sfund", as: MKMarkerAnnotationView.self)
                v.annotation      = ann
                v.glyphImage      = UIImage(systemName: "exclamationmark.triangle.fill")
                v.markerTintColor = .systemOrange
                v.canShowCallout  = true
                return v

            case .earthquake(let e):
                let v = dequeue(mapView, id: "quake", as: MKMarkerAnnotationView.self)
                v.annotation      = ann
                v.glyphText       = String(format: "%.1f", e.magnitude)
                v.markerTintColor = e.magnitude >= 5 ? .systemRed
                                  : e.magnitude >= 4 ? .systemOrange : .systemYellow
                v.canShowCallout  = true
                return v

            case .housing:
                let v = dequeue(mapView, id: "house", as: MKMarkerAnnotationView.self)
                v.annotation      = ann
                v.glyphImage      = UIImage(systemName: "house.fill")
                v.markerTintColor = .systemTeal
                v.canShowCallout  = true
                return v

            case .zip(let region):
                let reuseId = "zip"
                let v = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
                    ?? MKAnnotationView(annotation: ann, reuseIdentifier: reuseId)
                v.annotation = ann
                // Clear old subviews
                v.subviews.forEach { $0.removeFromSuperview() }
                let label = UILabel()
                label.text = region.id
                label.font = .systemFont(ofSize: 10, weight: .medium)
                label.textColor = .darkText
                label.backgroundColor = UIColor.white.withAlphaComponent(0.75)
                label.layer.cornerRadius = 3
                label.layer.masksToBounds = true
                label.textAlignment = .center
                label.sizeToFit()
                label.frame = label.frame.insetBy(dx: -4, dy: -2)
                v.addSubview(label)
                v.frame = label.frame
                v.centerOffset = .zero
                return v

            case .crimeMarker(let m):
                let v = dequeue(mapView, id: "crime", as: MKMarkerAnnotationView.self)
                v.annotation      = ann
                v.glyphImage      = UIImage(systemName: m.type.systemImage)
                v.markerTintColor = UIColor(m.type.markerColor)
                return v

            case .crimeCluster(_, let count):
                let v = dequeue(mapView, id: "crimeCluster", as: MKAnnotationView.self)
                v.annotation = ann
                let size: CGFloat = count > 20 ? 40 : count > 5 ? 34 : 28
                let color: UIColor = count > 10 ? .systemRed : count > 5 ? .systemOrange : .systemGray
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                v.image = renderer.image { ctx in
                    color.setFill()
                    ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                    UIColor.white.setFill()
                    ctx.cgContext.fillEllipse(in: CGRect(x: 2, y: 2, width: size - 4, height: size - 4))
                    let text = "\(count)" as NSString
                    let font = UIFont.boldSystemFont(ofSize: size > 34 ? 14 : 11)
                    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                    let textSize = text.size(withAttributes: attrs)
                    let textRect = CGRect(x: (size - textSize.width) / 2,
                                          y: (size - textSize.height) / 2,
                                          width: textSize.width, height: textSize.height)
                    text.draw(in: textRect, withAttributes: attrs)
                }
                v.canShowCallout = false
                return v

            case .pin:
                let v = dequeue(mapView, id: "pin", as: MKMarkerAnnotationView.self)
                v.annotation      = ann
                v.glyphImage      = UIImage(systemName: "mappin")
                v.markerTintColor = .systemRed
                return v
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let ann = view.annotation as? HFAnnotation else { return }
            mapView.deselectAnnotation(ann, animated: false)
            switch ann.data {
            case .school(let s):    parent.onSchoolTap(s)
            case .superfund(let s): parent.onSuperfundTap(s)
            case .housing(let h):   parent.onHousingTap(h)
            case .zip(let z):       parent.onZIPTap(z)
            case .crimeCluster(let coord, _):
                let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                let region = MKCoordinateRegion(center: coord, span: span)
                mapView.setRegion(region, animated: true)
            default:                break
            }
        }

        // MARK: - Tap gesture

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView,
                  gesture.state == .ended else { return }
            let pt = gesture.location(in: map)
            // Skip if annotation view was hit — handled by mapView(_:didSelect:)
            let hitAnnotation = map.annotations.contains { ann in
                guard let view = map.view(for: ann) else { return false }
                return view.frame.insetBy(dx: -8, dy: -8).contains(pt)
            }
            guard !hitAnnotation else { return }
            let coord = map.convert(pt, toCoordinateFrom: map)

            // Population layer: tap anywhere in a ZIP polygon → show ZIP info
            // (not the generic neighborhood report)
            if parent.selectedCategory == .population {
                if let zip = parent.zipRegions.first(where: {
                    coordinateInsidePolygon(coord, polygon: $0.polygon)
                }) {
                    parent.onZIPTap(zip)
                }
                // Tapped outside every ZIP → do nothing (no pin/score)
                return
            }

            parent.onMapTap(coord)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let map = gesture.view as? MKMapView else { return }
            let pt    = gesture.location(in: map)
            let coord = map.convert(pt, toCoordinateFrom: map)
            // Long press always opens GPS neighborhood report, regardless of layer
            parent.onMapLongPress(coord)
        }

        // Ray-casting point-in-polygon (works in lon/lat space — fine for small areas)
        private func coordinateInsidePolygon(_ pt: CLLocationCoordinate2D,
                                             polygon: [CLLocationCoordinate2D]) -> Bool {
            var inside = false
            let n = polygon.count
            guard n >= 3 else { return false }
            var j = n - 1
            for i in 0..<n {
                let xi = polygon[i].longitude, yi = polygon[i].latitude
                let xj = polygon[j].longitude, yj = polygon[j].latitude
                if ((yi > pt.latitude) != (yj > pt.latitude)) &&
                   (pt.longitude < (xj - xi) * (pt.latitude - yi) / (yj - yi) + xi) {
                    inside = !inside
                }
                j = i
            }
            return inside
        }

        // UIGestureRecognizerDelegate — let map's built-in gestures coexist
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        // MARK: - Helpers

        private func dequeue<T: MKAnnotationView>(_ map: MKMapView, id: String, as _: T.Type) -> T {
            (map.dequeueReusableAnnotationView(withIdentifier: id) as? T)
                ?? T(annotation: nil, reuseIdentifier: id)
        }
    }
}

// MARK: - HFAnnotation (stable UIKit annotation)

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

// MARK: - Array safe subscript helper

private extension Array where Element == Substring {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
