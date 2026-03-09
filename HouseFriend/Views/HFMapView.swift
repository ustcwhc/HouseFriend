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

    // MARK: - Callbacks → ContentView
    var onCameraChange: (MKCoordinateRegion) -> Void = { _ in }
    var onSchoolTap: (School) -> Void = { _ in }
    var onSuperfundTap: (SuperfundSite) -> Void = { _ in }
    var onHousingTap: (SupportiveHousingFacility) -> Void = { _ in }
    var onZIPTap: (ZIPCodeRegion) -> Void = { _ in }
    var onMapTap: (CLLocationCoordinate2D) -> Void = { _ in }
    var onNoiseFetchCancel: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = false
        map.setRegion(region, animated: false)

        // Tap to pin a location (pass through to ContentView)
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)

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
        private var crimeTileOverlay: CrimeTileOverlay?
        private var noisePolylines: [MKPolyline] = []
        private var lastNoiseCount = 0

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

            // For all other categories: only rebuild when category changes
            guard cat != activeCategory else { return }

            map.removeOverlays(map.overlays)
            noisePolylines = []
            lastNoiseCount = -1   // B1 fix: reset so noise rebuild works if we return
            crimeTileOverlay = nil
            zipRenderers = [:]
            activeCategory = cat

            switch cat {
            case .crime:
                let overlay = CrimeTileOverlay()
                crimeTileOverlay = overlay
                map.addOverlay(overlay, level: .aboveRoads)

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
            let roads = Array(parent.noiseRoads.prefix(200))
            // Skip if nothing changed
            guard roads.count != lastNoiseCount else { return }
            map.removeOverlays(noisePolylines)
            noisePolylines = []
            lastNoiseCount = roads.count
            for road in roads {
                let poly = MKPolyline(coordinates: road.coordinates,
                                      count: road.coordinates.count)
                poly.title = "noise:\(road.dbLevel):\(road.lineWidth)"
                map.addOverlay(poly, level: .aboveRoads)
                noisePolylines.append(poly)
            }
        }

        // MARK: - Annotation management

        func updateAnnotations(_ map: MKMapView) {
            var wanted: [String: HFAnnotation] = [:]

            switch parent.selectedCategory {
            case .schools:
                for s in parent.schools {
                    let key = "school-\(s.id)"
                    wanted[key] = annotationMap[key]
                        ?? HFAnnotation(coordinate: s.coordinate, data: .school(s), key: key)
                }
            case .superfund:
                for s in parent.superfundSites {
                    let key = "sfund-\(s.id)"
                    wanted[key] = annotationMap[key]
                        ?? HFAnnotation(coordinate: s.coordinate, data: .superfund(s), key: key)
                }
            case .supportiveHome:
                for h in parent.housingFacilities {
                    let key = "house-\(h.id)"
                    wanted[key] = annotationMap[key]
                        ?? HFAnnotation(coordinate: h.coordinate, data: .housing(h), key: key)
                }
            case .earthquake:
                for e in parent.earthquakes {
                    let key = "quake-\(e.id)"
                    wanted[key] = annotationMap[key]
                        ?? HFAnnotation(coordinate: e.coordinate, data: .earthquake(e), key: key)
                }
            case .population:
                for r in parent.zipRegions {
                    let key = "zip-\(r.id)"
                    wanted[key] = annotationMap[key]
                        ?? HFAnnotation(coordinate: r.center, data: .zip(r), key: key)
                }
            case .crime:
                if parent.showCrimeDetails {
                    for m in parent.crimeMarkers {
                        let key = "cm-\(m.id)"
                        wanted[key] = annotationMap[key]
                            ?? HFAnnotation(coordinate: m.coordinate, data: .crimeMarker(m), key: key)
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
                    let parts = title.split(separator: ":")
                    let db = Int(Double(parts[safe: 1] ?? "") ?? 55)
                    let lw  = CGFloat(Double(parts[safe: 2] ?? "") ?? 2)
                    r.strokeColor = UIColor(NoiseService.color(for: db))
                    r.lineWidth   = lw
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
                } else if title.hasPrefix("zip:") {
                    let zipId = String(title.dropFirst(4))
                    applyZipStyle(r, selected: zipId == parent.highlightedZIPId)
                    zipRenderers[zipId] = r
                }
                return r
            }

            return MKOverlayRenderer(overlay: overlay)
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
            default:                break
            }
        }

        // MARK: - Tap gesture

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView,
                  gesture.state == .ended else { return }
            let pt = gesture.location(in: map)
            // Do NOT fire onMapTap when the user tapped an annotation view —
            // that is handled by mapView(_:didSelect:). Firing both causes
            // rapid double state-mutation that dismisses the sheet immediately.
            let hitAnnotation = map.annotations.contains { ann in
                guard let view = map.view(for: ann) else { return false }
                // Expand hit area slightly for small labels
                return view.frame.insetBy(dx: -8, dy: -8).contains(pt)
            }
            guard !hitAnnotation else { return }
            let coord = map.convert(pt, toCoordinateFrom: map)
            parent.onMapTap(coord)
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
