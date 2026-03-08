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
    @State private var currentSpan   = MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
    @State private var currentCenter = CLLocationCoordinate2D(latitude: 37.3861, longitude: -121.9552)
    @State private var pinnedLocation: CLLocationCoordinate2D?
    @State private var pinnedAddress  = ""
    @State private var categories     = NeighborhoodCategory.all
    @State private var isLoadingScores = false

    var body: some View {
        ZStack {
            mapLayer

            // Top: NavBar + Search
            VStack(spacing: 0) {
                navBar
                searchBar
                if !searchResults.isEmpty { searchDropdown }
                Spacer()
                // Bottom panel when location pinned
                if pinnedLocation != nil {
                    bottomPanel
                }
            }

            // Right sidebar (above bottom panel)
            HStack {
                Spacer()
                VStack {
                    sideBar.padding(.top, 110)
                    Spacer()
                        .frame(height: pinnedLocation != nil ? 260 : 60)
                }
            }

            // Zoom + location buttons (bottom-right, above panel)
            VStack {
                Spacer()
                HStack {
                    // Legend bottom-left
                    LegendView(category: selectedCategory)
                        .padding(.leading, 12)
                        .padding(.bottom, pinnedLocation != nil ? 270 : 30)
                    Spacer()
                    VStack(spacing: 10) {
                        zoomControls
                        locationButton
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, pinnedLocation != nil ? 270 : 30)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            locationService.requestPermission()
            loadAllData(coord: currentCenter)
        }
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
                // Concentric circles per highway source point → smoke/haze gradient
                ForEach(noiseService.rings) { ring in
                    let (r, g, b) = NoiseService.color(for: ring.dbLevel)
                    // Larger rings = lower opacity (fade effect)
                    let opacity = max(0.04, 0.38 - (ring.radiusMeters / 2200.0) * 0.34)
                    MapCircle(center: ring.center, radius: ring.radiusMeters)
                        .foregroundStyle(Color(red: r, green: g, blue: b).opacity(opacity))
                        .stroke(.clear, lineWidth: 0)
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
                    .foregroundStyle(Color.red.opacity(0.35)).stroke(Color.red, lineWidth: 1.5)
                MapPolygon(coordinates: fireMedRisk())
                    .foregroundStyle(Color.orange.opacity(0.3)).stroke(Color.orange, lineWidth: 1)
            }
        }
        .ignoresSafeArea()
        .onTapGesture { } // allow map tap to propagate
    }

    // MARK: - Nav Bar
    var navBar: some View {
        ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea(edges: .top)
            HStack {
                Text("🏡")
                    .font(.title3).padding(.leading, 16)
                Text("HouseFriend")
                    .font(.headline).fontWeight(.bold)
                Spacer()
                Text(selectedCategory.rawValue)
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.trailing, 16)
            }
        }
        .frame(height: 50)
        .padding(.top, 50)
    }

    // MARK: - Search Bar
    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Search address or place...", text: $searchText)
                .autocorrectionDisabled()
                .onSubmit { performSearch() }
                .onChange(of: searchText) { _, v in
                    if v.count > 2 { performSearch() }
                    if v.isEmpty { searchResults = [] }
                }
            if !searchText.isEmpty {
                Button { searchText = ""; searchResults = [] } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.regularMaterial)
        .shadow(color: .black.opacity(0.08), radius: 3)
    }

    var searchDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(searchResults.prefix(5), id: \.self) { item in
                Button { selectItem(item) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle").foregroundColor(.red).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "").font(.subheadline).fontWeight(.medium).foregroundColor(.primary)
                            Text(item.placemark.title ?? "").font(.caption).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                }
                Divider().padding(.leading, 44)
            }
        }
        .background(.regularMaterial)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }

    // MARK: - Right Sidebar
    var sideBar: some View {
        VStack(spacing: 2) {
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

    // MARK: - Bottom Panel
    var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Handle
            HStack {
                Capsule().fill(Color.secondary.opacity(0.4)).frame(width: 36, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            // Address + overall score
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Neighborhood Report")
                        .font(.headline).fontWeight(.semibold)
                    Text(pinnedAddress)
                        .font(.caption).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer()
                overallScoreBadge
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)

            Divider()

            // Category score cards
            if isLoadingScores {
                HStack {
                    Spacer()
                    ProgressView("Analyzing...")
                        .padding()
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach($categories) { $cat in
                            ScoreCardView(category: $cat, isSelected: selectedCategory == cat.id)
                                .onTapGesture { selectedCategory = cat.id }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(.regularMaterial)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.12), radius: 10, y: -4)
    }

    var overallScoreBadge: some View {
        let scores = categories.compactMap(\.score)
        let avg = scores.isEmpty ? 0 : scores.reduce(0, +) / scores.count
        return VStack(spacing: 0) {
            Text("\(avg)")
                .font(.title2).fontWeight(.bold)
                .foregroundColor(scoreColor(avg))
            Text("/ 100")
                .font(.system(size: 10)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(scoreColor(avg).opacity(0.12))
        .cornerRadius(10)
    }

    // MARK: - Controls
    var zoomControls: some View {
        VStack(spacing: 0) {
            Button { zoom(in: true) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
                    .frame(width: 42, height: 42)
            }
            Divider().frame(width: 28)
            Button { zoom(in: false) } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
                    .frame(width: 42, height: 42)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 3)
    }

    var locationButton: some View {
        Button {
            if let loc = locationService.location {
                currentCenter = loc.coordinate
                currentSpan = MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                position = .region(MKCoordinateRegion(center: currentCenter, span: currentSpan))
                loadAllData(coord: currentCenter)
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

    // MARK: - Zoom
    func zoom(in zoomIn: Bool) {
        let factor: Double = zoomIn ? 0.5 : 2.0
        currentSpan = MKCoordinateSpan(
            latitudeDelta: max(0.002, min(180, currentSpan.latitudeDelta * factor)),
            longitudeDelta: max(0.002, min(360, currentSpan.longitudeDelta * factor))
        )
        position = .region(MKCoordinateRegion(center: currentCenter, span: currentSpan))
    }

    // MARK: - Score helpers
    func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60...79:  return .orange
        case 40...59:  return Color(red: 0.9, green: 0.5, blue: 0)
        default:       return .red
        }
    }

    // MARK: - Actions
    func performSearch() {
        guard !searchText.isEmpty else { return }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = searchText
        MKLocalSearch(request: req).start { resp, _ in
            DispatchQueue.main.async { searchResults = resp?.mapItems ?? [] }
        }
    }

    func selectItem(_ item: MKMapItem) {
        let c = item.placemark.coordinate
        pinnedLocation = c
        pinnedAddress = [item.name, item.placemark.thoroughfare, item.placemark.locality]
            .compactMap { $0 }.joined(separator: ", ")
        searchText = item.name ?? ""
        searchResults = []
        currentCenter = c
        currentSpan = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        position = .region(MKCoordinateRegion(center: c, span: currentSpan))
        loadAllData(coord: c)
        computeScores(coord: c)
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

    func computeScores(coord: CLLocationCoordinate2D) {
        isLoadingScores = true
        // Reset scores first
        for i in categories.indices { categories[i].score = nil; categories[i].scoreLabel = nil }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            for i in categories.indices {
                switch categories[i].id {
                case .earthquake:
                    let nearby = earthquakeService.events.filter {
                        abs($0.coordinate.latitude - coord.latitude) < 0.2 &&
                        abs($0.coordinate.longitude - coord.longitude) < 0.25
                    }.count
                    categories[i].score = max(20, 100 - nearby * 12)
                    categories[i].scoreLabel = nearby == 0 ? "Low Risk" : nearby < 3 ? "Some Activity" : "High Activity"
                case .superfund:
                    let nearby = superfundService.sites.filter {
                        abs($0.coordinate.latitude - coord.latitude) < 0.12 &&
                        abs($0.coordinate.longitude - coord.longitude) < 0.15
                    }.count
                    categories[i].score = max(10, 100 - nearby * 28)
                    categories[i].scoreLabel = nearby == 0 ? "Clear" : "\(nearby) site(s) nearby"
                case .milpitasOdor:
                    let aqi = airQualityService.data?.aqi ?? 55
                    categories[i].score = max(0, 100 - aqi)
                    categories[i].scoreLabel = airQualityService.data?.category ?? "Moderate"
                case .crime:
                    let cnt = crimeService.incidents.count
                    let score = max(20, 100 - cnt * 4)
                    categories[i].score = score
                    categories[i].scoreLabel = score > 70 ? "Safe" : score > 45 ? "Moderate" : "High Crime"
                case .fireHazard:
                    let inHills = coord.latitude < 37.35 && coord.longitude < -122.05
                    categories[i].score = inHills ? 42 : 74
                    categories[i].scoreLabel = inHills ? "Moderate Risk" : "Low Risk"
                case .schools:
                    let nearbySchools = schoolService.schools.filter {
                        abs($0.coordinate.latitude - coord.latitude) < 0.05 &&
                        abs($0.coordinate.longitude - coord.longitude) < 0.06
                    }
                    let avgRating = nearbySchools.isEmpty ? 7 :
                        nearbySchools.map(\.rating).reduce(0, +) / nearbySchools.count
                    categories[i].score = avgRating * 10
                    categories[i].scoreLabel = "\(nearbySchools.count) schools nearby"
                case .noise:
                    let nearHighway = abs(coord.latitude - 37.355) < 0.03 // near 101/280
                    categories[i].score = nearHighway ? 52 : 72
                    categories[i].scoreLabel = nearHighway ? "Moderate (~65dB)" : "Quiet (~52dB)"
                case .electricLines:
                    let nearLine = electricService.lines.first {
                        $0.coordinates.contains { abs($0.latitude - coord.latitude) < 0.02 }
                    }
                    categories[i].score = nearLine != nil ? 60 : 85
                    categories[i].scoreLabel = nearLine != nil ? "Lines nearby" : "Low Exposure"
                case .population:
                    categories[i].score = 70
                    categories[i].scoreLabel = "~35k / sq mi"
                case .supportiveHome:
                    let cnt = housingService.facilities.filter {
                        abs($0.coordinate.latitude - coord.latitude) < 0.05 &&
                        abs($0.coordinate.longitude - coord.longitude) < 0.06
                    }.count
                    categories[i].score = max(40, 100 - cnt * 15)
                    categories[i].scoreLabel = "\(cnt) facilities nearby"
                }
            }
            isLoadingScores = false
        }
    }

    // MARK: - Zone Data
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

    func crimeColor(_ v: Double) -> Color { Color(red: min(1, v*1.2), green: max(0, 0.4-v*0.4), blue: 0) }
    func odorColor(_ l: Int) -> Color {
        switch l {
        case 3: return Color(red: 1, green: 0.5, blue: 0.1)
        case 2: return Color(red: 1, green: 0.8, blue: 0.3)
        default: return Color(red: 0.5, green: 0.8, blue: 1)
        }
    }
    func electricColor(_ v: Int) -> Color {
        v >= 115 ? .purple : v >= 60 ? Color(red:0.7,green:0.1,blue:0.8) : Color(red:0.85,green:0.5,blue:0.9)
    }
    func fireHighRisk() -> [CLLocationCoordinate2D] {
        [.init(latitude:37.350,longitude:-122.100),.init(latitude:37.330,longitude:-122.080),
         .init(latitude:37.305,longitude:-122.060),.init(latitude:37.290,longitude:-122.090),
         .init(latitude:37.310,longitude:-122.110),.init(latitude:37.340,longitude:-122.120)]
    }
    func fireMedRisk() -> [CLLocationCoordinate2D] {
        [.init(latitude:37.380,longitude:-122.080),.init(latitude:37.355,longitude:-122.060),
         .init(latitude:37.335,longitude:-122.040),.init(latitude:37.320,longitude:-122.060),
         .init(latitude:37.340,longitude:-122.090),.init(latitude:37.365,longitude:-122.095)]
    }
}

// MARK: - Score Card View
struct ScoreCardView: View {
    @Binding var category: NeighborhoodCategory
    var isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(isSelected ? 0.25 : 0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(category.color)
            }
            Text(category.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 68)

            if let score = category.score {
                Text("\(score)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(scoreColor(score))
                if let label = category.scoreLabel {
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(width: 68)
                }
            } else {
                ProgressView().scaleEffect(0.55).frame(height: 14)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 5)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? category.color.opacity(0.13) : Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(isSelected ? 0.12 : 0.05), radius: isSelected ? 5 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? category.color : .clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    func scoreColor(_ s: Int) -> Color {
        s >= 80 ? .green : s >= 60 ? .orange : s >= 40 ? Color(red:0.9,green:0.5,blue:0) : .red
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
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .white : category.color)
                .frame(width: 38, height: 38)
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
                RoundedRectangle(cornerRadius: 5).fill(levelColor).frame(width: 24, height: 24)
                Text(school.level.rawValue).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
            }
            Text("(\(school.rating))").font(.system(size: 9, weight: .medium)).foregroundColor(.primary)
        }
    }
    var levelColor: Color {
        switch school.level {
        case .elementary: return .green
        case .middle:     return .blue
        case .high:       return Color(red: 0.4, green: 0, blue: 0.7)
        }
    }
}

struct HousingMarkerView: View {
    let facility: SupportiveHousingFacility
    var body: some View {
        Image(systemName: "house.fill").font(.title3)
            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6)).shadow(radius: 1)
    }
}

struct SuperfundMarkerView: View {
    let site: SuperfundSite
    var body: some View {
        Image(systemName: "flask.fill").font(.title3)
            .foregroundColor(severityColor).shadow(radius: 1)
    }
    var severityColor: Color {
        guard let d = site.distanceMiles else { return .orange }
        return d < 1 ? .red : d < 3 ? .orange : .green
    }
}

// MARK: - Corner Radius extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
