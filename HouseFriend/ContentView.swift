import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var locationService   = LocationService()
    @StateObject private var earthquakeService = EarthquakeService()
    @StateObject private var superfundService  = SuperfundService()
    @StateObject private var airQualityService = AirQualityService()
    @StateObject private var crimeService      = CrimeService()
    @StateObject private var fireService       = FireDataService()
    @StateObject private var schoolService     = SchoolService()
    @StateObject private var electricService   = ElectricLinesService()
    @StateObject private var housingService    = SupportiveHousingService()
    @StateObject private var noiseService      = NoiseService()

    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.3861, longitude: -121.9552),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )
    @State private var selectedCategory: CategoryType = .crime
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var currentSpan = MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
    @State private var currentCenter = CLLocationCoordinate2D(latitude: 37.3861, longitude: -121.9552)
    @State private var pinnedLocation: CLLocationCoordinate2D?

    var body: some View {
        ZStack {
            mapLayer

            // Top: NavBar + Search
            VStack(spacing: 0) {
                navBar
                searchBar
                if !searchResults.isEmpty { searchDropdown }
                Spacer()
            }

            // Right sidebar
            HStack {
                Spacer()
                sideBar.padding(.top, 110)
            }

            // Bottom-left legend + Bottom-right controls
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    // Legend
                    LegendView(category: selectedCategory)
                        .padding(.leading, 12)
                        .padding(.bottom, 30)

                    Spacer()

                    // Right controls: zoom + location
                    VStack(spacing: 10) {
                        // Zoom buttons
                        VStack(spacing: 0) {
                            Button { zoom(in: true) } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 42, height: 42)
                            }
                            Divider().frame(width: 28)
                            Button { zoom(in: false) } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 42, height: 42)
                            }
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 3)

                        // My location
                        Button {
                            if let loc = locationService.location {
                                position = .region(MKCoordinateRegion(
                                    center: loc.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                                ))
                                loadAllData(coord: loc.coordinate)
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.title3).foregroundColor(.blue)
                                .frame(width: 42, height: 42)
                                .background(.regularMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 30)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            locationService.requestPermission()
            loadAllData(coord: CLLocationCoordinate2D(latitude: 37.3861, longitude: -121.9552))
        }
    }

    // MARK: - Zoom
    func zoom(in zoomIn: Bool) {
        let factor: Double = zoomIn ? 0.5 : 2.0
        currentSpan = MKCoordinateSpan(
            latitudeDelta: max(0.002, min(180, currentSpan.latitudeDelta * factor)),
            longitudeDelta: max(0.002, min(360, currentSpan.longitudeDelta * factor))
        )
        position = .region(MKCoordinateRegion(center: currentCenter, span: currentSpan))
    }

    // MARK: - Map
    var mapLayer: some View {
        Map(position: $position) {
            if let loc = pinnedLocation {
                Annotation("", coordinate: loc) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title).foregroundColor(.red).shadow(radius: 2)
                }
            }
            UserAnnotation()

            if selectedCategory == .noise {
                ForEach(noiseService.zones) { zone in
                    let (r, g, b) = NoiseService.color(for: zone.dbLevel)
                    MapPolygon(coordinates: zone.polygon)
                        .foregroundStyle(Color(red: r, green: g, blue: b).opacity(0.55))
                        .stroke(Color(red: r, green: g, blue: b), lineWidth: 1)
                }
            }

            if selectedCategory == .crime {
                ForEach(crimeMapZones()) { zone in
                    MapPolygon(coordinates: zone.coordinates)
                        .foregroundStyle(crimeColor(zone.value).opacity(0.45))
                        .stroke(crimeColor(zone.value), lineWidth: 0.5)
                }
            }

            if selectedCategory == .milpitasOdor {
                ForEach(odorMapZones()) { zone in
                    MapPolygon(coordinates: zone.coordinates)
                        .foregroundStyle(odorColor(Int(zone.value)).opacity(0.4))
                        .stroke(odorColor(Int(zone.value)), lineWidth: 1)
                }
            }

            if selectedCategory == .electricLines {
                ForEach(electricService.lines) { line in
                    MapPolyline(coordinates: line.coordinates)
                        .stroke(electricColor(line.voltage), lineWidth: line.voltage >= 115 ? 3 : 2)
                }
            }

            if selectedCategory == .schools {
                ForEach(schoolService.schools) { school in
                    Annotation(school.name, coordinate: school.coordinate) {
                        SchoolMarkerView(school: school)
                    }
                }
            }

            if selectedCategory == .supportiveHome {
                ForEach(housingService.facilities) { facility in
                    Annotation(facility.name, coordinate: facility.coordinate) {
                        HousingMarkerView(facility: facility)
                    }
                }
            }

            if selectedCategory == .superfund {
                ForEach(superfundService.sites) { site in
                    Annotation(site.name, coordinate: site.coordinate) {
                        SuperfundMarkerView(site: site)
                    }
                }
            }

            if selectedCategory == .earthquake {
                ForEach(earthquakeService.events) { event in
                    Annotation("M\(String(format:"%.1f", event.magnitude))", coordinate: event.coordinate) {
                        Circle()
                            .fill(event.magnitude > 4.5 ? Color.red.opacity(0.75) : Color.orange.opacity(0.6))
                            .frame(width: CGFloat(max(10, event.magnitude * 8)),
                                   height: CGFloat(max(10, event.magnitude * 8)))
                    }
                }
            }

            if selectedCategory == .fireHazard {
                MapPolygon(coordinates: fireHighRisk())
                    .foregroundStyle(Color.red.opacity(0.35))
                    .stroke(Color.red, lineWidth: 1.5)
                MapPolygon(coordinates: fireMedRisk())
                    .foregroundStyle(Color.orange.opacity(0.3))
                    .stroke(Color.orange, lineWidth: 1)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Nav Bar
    var navBar: some View {
        ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea(edges: .top)
            HStack {
                Text("HF")
                    .font(.headline).foregroundColor(.blue).padding(.leading, 16)
                Spacer()
                Text(selectedCategory.rawValue).font(.headline)
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.primary).padding(.trailing, 16)
                    .opacity([CategoryType.crime, .schools].contains(selectedCategory) ? 1 : 0)
            }
        }
        .frame(height: 50)
        .padding(.top, 50)
    }

    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Search here", text: $searchText)
                .autocorrectionDisabled()
                .onSubmit { performSearch() }
                .onChange(of: searchText) { _, v in
                    if v.count > 3 { performSearch() }
                    if v.isEmpty { searchResults = [] }
                }
            Spacer()
            Button {} label: {
                Image(systemName: "square.3.layers.3d").foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.regularMaterial)
        .shadow(radius: 2)
    }

    var searchDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(searchResults.prefix(5), id: \.self) { item in
                Button { selectItem(item) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "").font(.subheadline).fontWeight(.medium).foregroundColor(.primary)
                        Text(item.placemark.title ?? "").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
            }
        }
        .background(.regularMaterial).shadow(radius: 2)
    }

    // MARK: - Right Sidebar
    var sideBar: some View {
        VStack(spacing: 4) {
            ForEach(NeighborhoodCategory.all) { cat in
                SidebarButton(category: cat, isSelected: selectedCategory == cat.id) {
                    selectedCategory = cat.id
                }
            }
        }
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.trailing, 8)
    }

    // MARK: - Actions
    func performSearch() {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = searchText
        MKLocalSearch(request: req).start { resp, _ in searchResults = resp?.mapItems ?? [] }
    }

    func selectItem(_ item: MKMapItem) {
        let c = item.placemark.coordinate
        pinnedLocation = c
        searchText = item.name ?? ""
        searchResults = []
        currentCenter = c
        currentSpan = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        position = .region(MKCoordinateRegion(center: c, span: currentSpan))
        loadAllData(coord: c)
    }

    func loadAllData(coord: CLLocationCoordinate2D) {
        earthquakeService.fetch()
        superfundService.fetchNear(lat: coord.latitude, lon: coord.longitude)
        airQualityService.fetch(lat: coord.latitude, lon: coord.longitude)
        crimeService.fetchNear(lat: coord.latitude, lon: coord.longitude)
        fireService.fetchFireData()
        schoolService.fetch()
        electricService.fetch()
        housingService.fetch()
        noiseService.fetch()
    }

    // MARK: - Zone Generators
    func crimeMapZones() -> [MapZone] {
        [
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.360, longitude: -121.910),
                CLLocationCoordinate2D(latitude: 37.340, longitude: -121.880),
                CLLocationCoordinate2D(latitude: 37.320, longitude: -121.870),
                CLLocationCoordinate2D(latitude: 37.315, longitude: -121.840),
                CLLocationCoordinate2D(latitude: 37.335, longitude: -121.830),
                CLLocationCoordinate2D(latitude: 37.360, longitude: -121.860),
                CLLocationCoordinate2D(latitude: 37.375, longitude: -121.895),
            ], value: 0.9),
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.400, longitude: -121.970),
                CLLocationCoordinate2D(latitude: 37.385, longitude: -121.960),
                CLLocationCoordinate2D(latitude: 37.370, longitude: -121.950),
                CLLocationCoordinate2D(latitude: 37.360, longitude: -121.965),
                CLLocationCoordinate2D(latitude: 37.375, longitude: -121.980),
                CLLocationCoordinate2D(latitude: 37.395, longitude: -121.988),
            ], value: 0.5),
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.360, longitude: -122.060),
                CLLocationCoordinate2D(latitude: 37.330, longitude: -122.040),
                CLLocationCoordinate2D(latitude: 37.310, longitude: -122.020),
                CLLocationCoordinate2D(latitude: 37.300, longitude: -122.050),
                CLLocationCoordinate2D(latitude: 37.325, longitude: -122.075),
                CLLocationCoordinate2D(latitude: 37.355, longitude: -122.080),
            ], value: 0.15),
        ]
    }

    func odorMapZones() -> [MapZone] {
        [
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.450, longitude: -121.920),
                CLLocationCoordinate2D(latitude: 37.440, longitude: -121.960),
                CLLocationCoordinate2D(latitude: 37.430, longitude: -121.990),
                CLLocationCoordinate2D(latitude: 37.420, longitude: -121.980),
                CLLocationCoordinate2D(latitude: 37.430, longitude: -121.950),
                CLLocationCoordinate2D(latitude: 37.445, longitude: -121.915),
            ], value: 3),
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.430, longitude: -122.010),
                CLLocationCoordinate2D(latitude: 37.410, longitude: -122.030),
                CLLocationCoordinate2D(latitude: 37.390, longitude: -122.000),
                CLLocationCoordinate2D(latitude: 37.400, longitude: -121.970),
                CLLocationCoordinate2D(latitude: 37.420, longitude: -121.980),
            ], value: 2),
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.480, longitude: -122.010),
                CLLocationCoordinate2D(latitude: 37.460, longitude: -122.040),
                CLLocationCoordinate2D(latitude: 37.440, longitude: -122.050),
                CLLocationCoordinate2D(latitude: 37.420, longitude: -122.040),
                CLLocationCoordinate2D(latitude: 37.440, longitude: -122.010),
                CLLocationCoordinate2D(latitude: 37.465, longitude: -121.990),
            ], value: 1),
        ]
    }

    func crimeColor(_ intensity: Double) -> Color {
        Color(red: min(1.0, intensity * 1.2), green: max(0.0, 0.4 - intensity * 0.4), blue: 0.0)
    }
    func odorColor(_ level: Int) -> Color {
        switch level {
        case 3: return Color(red: 1.0, green: 0.5, blue: 0.1)
        case 2: return Color(red: 1.0, green: 0.8, blue: 0.3)
        default: return Color(red: 0.5, green: 0.8, blue: 1.0)
        }
    }
    func electricColor(_ voltage: Int) -> Color {
        if voltage >= 115 { return .purple }
        if voltage >= 60  { return Color(red: 0.7, green: 0.1, blue: 0.8) }
        return Color(red: 0.85, green: 0.5, blue: 0.9)
    }
    func fireHighRisk() -> [CLLocationCoordinate2D] {
        [CLLocationCoordinate2D(latitude: 37.350, longitude: -122.100),
         CLLocationCoordinate2D(latitude: 37.330, longitude: -122.080),
         CLLocationCoordinate2D(latitude: 37.305, longitude: -122.060),
         CLLocationCoordinate2D(latitude: 37.290, longitude: -122.090),
         CLLocationCoordinate2D(latitude: 37.310, longitude: -122.110),
         CLLocationCoordinate2D(latitude: 37.340, longitude: -122.120)]
    }
    func fireMedRisk() -> [CLLocationCoordinate2D] {
        [CLLocationCoordinate2D(latitude: 37.380, longitude: -122.080),
         CLLocationCoordinate2D(latitude: 37.355, longitude: -122.060),
         CLLocationCoordinate2D(latitude: 37.335, longitude: -122.040),
         CLLocationCoordinate2D(latitude: 37.320, longitude: -122.060),
         CLLocationCoordinate2D(latitude: 37.340, longitude: -122.090),
         CLLocationCoordinate2D(latitude: 37.365, longitude: -122.095)]
    }
}

// MARK: - Sidebar Button
struct SidebarButton: View {
    let category: NeighborhoodCategory
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: category.icon)
                .font(.system(size: 17))
                .foregroundColor(isSelected ? .white : category.color)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? category.color : Color.clear))
        }
    }
}

// MARK: - School Marker
struct SchoolMarkerView: View {
    let school: School
    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(levelColor).frame(width: 26, height: 26)
                Text(school.level.rawValue).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
            }
            Text("(\(school.rating))").font(.system(size: 9, weight: .medium)).foregroundColor(.primary)
        }
    }
    var levelColor: Color {
        switch school.level {
        case .elementary: return .green
        case .middle:     return .blue
        case .high:       return Color(red: 0.4, green: 0.0, blue: 0.7)
        }
    }
}

// MARK: - Housing Marker
struct HousingMarkerView: View {
    let facility: SupportiveHousingFacility
    var body: some View {
        Image(systemName: "house.fill")
            .font(.title3)
            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
            .shadow(radius: 1)
    }
}

// MARK: - Superfund Marker
struct SuperfundMarkerView: View {
    let site: SuperfundSite
    var body: some View {
        Image(systemName: "flask.fill")
            .font(.title3)
            .foregroundColor(severityColor)
            .shadow(radius: 1)
    }
    var severityColor: Color {
        guard let dist = site.distanceMiles else { return .orange }
        if dist < 1 { return .red }
        if dist < 3 { return .orange }
        return .green
    }
}
