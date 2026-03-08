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
    @StateObject private var populationService = PopulationService()

    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.650, longitude: -122.150),
            span: MKCoordinateSpan(latitudeDelta: 0.85, longitudeDelta: 0.85)
        )
    )
    @State private var selectedCategory: CategoryType = .crime
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var currentSpan   = MKCoordinateSpan(latitudeDelta: 0.85, longitudeDelta: 0.85)
    @State private var currentCenter = CLLocationCoordinate2D(latitude: 37.650, longitude: -122.150)
    @State private var pinnedLocation: CLLocationCoordinate2D?
    @State private var pinnedAddress  = ""
    @State private var categories     = NeighborhoodCategory.all
    @State private var isLoadingScores = false
    @State private var selectedSchool: School?
    @State private var selectedSuperfund: SuperfundSite?
    @State private var selectedHousing: SupportiveHousingFacility?

    var body: some View {
        ZStack {
            mapLayer

            // Top: NavBar + Search
            VStack(spacing: 0) {
                navBar
                searchBar
                if !searchResults.isEmpty { searchDropdown }
                Spacer()
                // Empty state hint or bottom panel
                if pinnedLocation != nil {
                    bottomPanel
                } else {
                    emptyStateHint
                }
            }

            // Right sidebar (vertically centered, with safe area)
            VStack {
                Spacer().frame(height: 110)
                HStack(alignment: .center) {
                    Spacer()
                    sideBar
                }
                Spacer().frame(height: pinnedLocation != nil ? 280 : 120)
            }

            // Zoom + location buttons (bottom-right, above panel)
            VStack {
                Spacer()
                HStack {
                    // Legend bottom-left
                    LegendView(category: selectedCategory)
                        .padding(.leading, 12)
                        .padding(.bottom, pinnedLocation != nil ? 320 : 90)
                    Spacer()
                    VStack(spacing: 10) {
                        zoomControls
                        locationButton
                    }
                    .padding(.trailing, 6)
                    .padding(.bottom, pinnedLocation != nil ? 320 : 90)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            locationService.requestPermission()
            // Load bay-area-wide data on launch
            noiseService.fetch()
            fireService.fetchFireData()
            earthquakeService.fetch()
            electricService.fetch()
            housingService.fetch()
        }
        .sheet(item: $selectedSchool) { school in SchoolDetailSheet(school: school) }
        .sheet(item: $selectedSuperfund) { site in SuperfundDetailSheet(site: site) }
        .sheet(item: $selectedHousing) { f in HousingDetailSheet(facility: f) }
    }

    // MARK: - Map
    var mapLayer: some View {
        Map(position: $position) {
            if let loc = pinnedLocation {
                Annotation("", coordinate: loc) {
                    VStack(spacing: 2) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title).foregroundColor(.red).shadow(radius: 2)
                        Text("Analysis Point")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.regularMaterial)
                            .cornerRadius(6)
                    }
                }
            }
            UserAnnotation()

            if selectedCategory == .noise {
                // Road-following buffer strips — outermost (quiet) drawn first,
                // innermost (loud) painted on top → smooth gradient along streets
                ForEach(noiseService.zones) { zone in
                    let (r, g, b) = NoiseService.color(for: zone.dbLevel)
                    let opacity = min(0.55, max(0.12, Double(zone.dbLevel - 40) / 45.0))
                    MapPolygon(coordinates: zone.polygon)
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
                            .onTapGesture { selectedSchool = school }
                    }
                }
            }
            if selectedCategory == .supportiveHome {
                ForEach(housingService.facilities) { facility in
                    Annotation(facility.name, coordinate: facility.coordinate) {
                        HousingMarkerView(facility: facility)
                            .onTapGesture { selectedHousing = facility }
                    }
                }
            }
            if selectedCategory == .superfund {
                ForEach(superfundService.sites) { site in
                    Annotation(site.name, coordinate: site.coordinate) {
                        SuperfundMarkerView(site: site)
                            .onTapGesture { selectedSuperfund = site }
                    }
                }
            }
            if selectedCategory == .earthquake {
                ForEach(earthquakeService.events) { event in
                    Annotation("", coordinate: event.coordinate) {
                        ZStack {
                            Circle()
                                .fill(event.magnitude >= 5.0 ? Color.red.opacity(0.8) :
                                      event.magnitude >= 4.0 ? Color.orange.opacity(0.75) :
                                      Color(red:1.0,green:0.75,blue:0.0).opacity(0.65))
                                .frame(width: CGFloat(max(12, event.magnitude * 9)),
                                       height: CGFloat(max(12, event.magnitude * 9)))
                            Text(String(format:"%.1f", event.magnitude))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            if selectedCategory == .fireHazard {
                ForEach(fireService.hazardZones) { zone in
                    let col = FireDataService.colorForSeverity(zone.severity)
                    MapPolygon(coordinates: zone.coordinates)
                        .foregroundStyle(Color(red: col.r, green: col.g, blue: col.b).opacity(col.opacity))
                        .stroke(Color(red: col.r, green: col.g, blue: col.b), lineWidth: 1.5)
                }
            }
        }
        .ignoresSafeArea()
        .onMapCameraChange { context in
            currentCenter = context.region.center
            currentSpan   = context.region.span
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // Drop pin at current map center (long-press center)
            let coord = currentCenter
            pinnedLocation = coord
            pinnedAddress = String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
            // Reverse geocode
            let geocoder = CLGeocoder()
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
                if let p = placemarks?.first {
                    let parts = [p.name, p.thoroughfare, p.locality].compactMap { $0 }
                    pinnedAddress = parts.joined(separator: ", ")
                }
            }
            loadAllData(coord: coord)
            computeScores(coord: coord)
        }
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
                // Active layer chip
                HStack(spacing: 5) {
                    let cat = NeighborhoodCategory.all.first { $0.id == selectedCategory }
                    Image(systemName: cat?.icon ?? "map")
                        .font(.caption)
                        .foregroundColor(cat?.color ?? .blue)
                    Text(selectedCategory.rawValue)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(cat?.color ?? .blue)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background((NeighborhoodCategory.all.first { $0.id == selectedCategory }?.color ?? .blue).opacity(0.12))
                .cornerRadius(20)
                .padding(.trailing, 10)
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 1) {
                ForEach(NeighborhoodCategory.all) { cat in
                    SidebarButton(category: cat, isSelected: selectedCategory == cat.id) {
                        selectedCategory = cat.id
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 380)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.trailing, 6)
    }

    // MARK: - Empty State
    var emptyStateHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.title2).foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Search any address")
                        .font(.subheadline).fontWeight(.semibold)
                    Text("Get a full neighborhood safety report")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Image(systemName: "hand.tap.fill")
                    .font(.title2).foregroundColor(.purple)
                Text("Or long-press anywhere on the map to analyze that location")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 8, y: -3)
        .padding(.horizontal, 12)
        .padding(.bottom, 30)
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
                    ProgressView("Analyzing neighborhood...")
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

                // Category-specific detail list
                if let pinnedCoord = pinnedLocation {
                    categoryDetailSection(for: selectedCategory, coord: pinnedCoord)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 20)
                }
            }
        }
        .background(.regularMaterial)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.12), radius: 10, y: -4)
    }

    // MARK: - Category Detail Section
    @ViewBuilder
    func categoryDetailSection(for cat: CategoryType, coord: CLLocationCoordinate2D) -> some View {
        switch cat {
        case .schools:
            let nearby = schoolService.schools.filter {
                abs($0.coordinate.latitude - coord.latitude) < 0.05 &&
                abs($0.coordinate.longitude - coord.longitude) < 0.06
            }.sorted {
                pow($0.coordinate.latitude-coord.latitude,2)+pow($0.coordinate.longitude-coord.longitude,2) <
                pow($1.coordinate.latitude-coord.latitude,2)+pow($1.coordinate.longitude-coord.longitude,2)
            }
            if !nearby.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Nearest Schools").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                        Spacer()
                        Text("\(nearby.count) total").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.bottom, 6)
                    ForEach(nearby.prefix(5)) { school in
                        Button { selectedSchool = school } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(school.level == .elementary ? Color.green :
                                              school.level == .middle ? Color.blue : Color(red:0.4,green:0,blue:0.7))
                                        .frame(width: 22, height: 22)
                                    Text(school.level.rawValue).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(school.name).font(.caption).foregroundColor(.primary).lineLimit(1)
                                    Text(school.district).font(.system(size: 9)).foregroundColor(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { j in
                                        Image(systemName: j < school.rating/2 ? "star.fill" : "star")
                                            .font(.system(size: 8))
                                            .foregroundColor(.orange)
                                    }
                                    Text("\(school.rating)/10").font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(school.rating >= 8 ? .green : school.rating >= 6 ? .orange : .red)
                                }
                                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        if school.id != nearby.prefix(5).last?.id { Divider() }
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }

        case .superfund:
            let nearby = superfundService.sites.prefix(5)
            if !nearby.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Nearby EPA Superfund Sites").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                        Spacer()
                        Text("\(superfundService.sites.count) found").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.bottom, 6)
                    ForEach(Array(nearby)) { site in
                        Button { selectedSuperfund = site } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "flask.fill")
                                    .foregroundColor(site.distanceMiles.map { $0 < 1 ? Color.red : $0 < 3 ? Color.orange : Color.green } ?? .orange)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(site.name).font(.caption).foregroundColor(.primary).lineLimit(1)
                                    Text(site.contaminants).font(.system(size: 9)).foregroundColor(.secondary).lineLimit(1)
                                }
                                Spacer()
                                if let d = site.distanceMiles {
                                    Text(String(format: "%.1f mi", d))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(d < 1 ? .red : d < 3 ? .orange : .green)
                                }
                                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        if site.id != nearby.last?.id { Divider() }
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }

        case .earthquake:
            let recent = earthquakeService.events.sorted { $0.magnitude > $1.magnitude }.prefix(5)
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Recent Earthquakes (Bay Area)").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                        .padding(.bottom, 6)
                    ForEach(Array(recent)) { event in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(event.magnitude >= 5.0 ? Color.red :
                                          event.magnitude >= 4.0 ? Color.orange : Color.yellow)
                                    .frame(width: 28, height: 28)
                                Text(String(format: "%.1f", event.magnitude))
                                    .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.place).font(.caption).foregroundColor(.primary).lineLimit(1)
                                Text(event.magnitude >= 5.0 ? "Strong" : event.magnitude >= 4.0 ? "Moderate" : "Minor")
                                    .font(.system(size: 9)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("M\(String(format: "%.1f", event.magnitude))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(event.magnitude >= 5.0 ? .red : event.magnitude >= 4.0 ? .orange : .primary)
                        }
                        .padding(.vertical, 5)
                        if event.id != recent.last?.id { Divider() }
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }

        case .fireHazard:
            let zones = fireService.hazardZones
            if !zones.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("CAL FIRE Hazard Zones Nearby").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                        .padding(.bottom, 6)
                    ForEach(zones) { zone in
                        HStack(spacing: 10) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(zone.severity == "Extreme" ? .red : zone.severity == "Very High" ? .orange : Color(red:1,green:0.65,blue:0))
                                .frame(width: 22)
                            Text(zone.name).font(.caption).foregroundColor(.primary).lineLimit(1)
                            Spacer()
                            Text(zone.severity)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(zone.severity == "Extreme" ? .red : zone.severity == "Very High" ? .orange : Color(red:1,green:0.65,blue:0))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background((zone.severity == "Extreme" ? Color.red : zone.severity == "Very High" ? Color.orange : Color.yellow).opacity(0.15))
                                .cornerRadius(5)
                        }
                        .padding(.vertical, 5)
                        if zone.id != zones.last?.id { Divider() }
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }

        case .supportiveHome:
            let nearby = housingService.facilities.filter {
                abs($0.coordinate.latitude - coord.latitude) < 0.05 &&
                abs($0.coordinate.longitude - coord.longitude) < 0.06
            }
            if !nearby.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Supportive Housing Nearby").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                        Spacer()
                        Text("\(nearby.count) facilities").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.bottom, 6)
                    ForEach(nearby.prefix(4)) { facility in
                        Button { selectedHousing = facility } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "house.fill")
                                    .foregroundColor(Color(red:0.4,green:0.2,blue:0.6))
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(facility.name.replacingOccurrences(of: "\n", with: " "))
                                        .font(.caption).foregroundColor(.primary).lineLimit(1)
                                    Text(facility.type).font(.system(size: 9)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        if facility.id != nearby.prefix(4).last?.id { Divider() }
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }

        default:
            EmptyView()
        }
    }

    var overallScoreBadge: some View {
        let scores = categories.compactMap(\.score)
        let avg = scores.isEmpty ? 0 : scores.reduce(0, +) / scores.count
        let grade = avg >= 80 ? "A" : avg >= 70 ? "B" : avg >= 60 ? "C" : avg >= 40 ? "D" : "F"
        return VStack(spacing: 2) {
            Text(grade)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(scoreColor(avg))
            Text("\(avg)/100")
                .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
            Text("Safety Score")
                .font(.system(size: 8)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(scoreColor(avg).opacity(0.10))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(scoreColor(avg).opacity(0.3), lineWidth: 1))
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
        populationService.fetch(lat: coord.latitude, lon: coord.longitude)
        earthquakeService.fetch()
        superfundService.fetchNear(lat: coord.latitude, lon: coord.longitude)
        airQualityService.fetch(lat: coord.latitude, lon: coord.longitude)
        crimeService.fetchNear(lat: coord.latitude, lon: coord.longitude)
        fireService.fetchFireData()
        schoolService.fetchNear(lat: coord.latitude, lon: coord.longitude)
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
                    let nearbySites = superfundService.sites.filter {
                        abs($0.coordinate.latitude - coord.latitude) < 0.12 &&
                        abs($0.coordinate.longitude - coord.longitude) < 0.15
                    }.sorted { ($0.distanceMiles ?? 99) < ($1.distanceMiles ?? 99) }
                    let sfScore = max(10, 100 - nearbySites.count * 22)
                    categories[i].score = sfScore
                    if nearbySites.isEmpty {
                        categories[i].scoreLabel = "No EPA sites nearby"
                    } else if let closest = nearbySites.first, let dist = closest.distanceMiles {
                        categories[i].scoreLabel = "\(nearbySites.count) sites · closest \(String(format:"%.1f",dist))mi"
                    } else {
                        categories[i].scoreLabel = "\(nearbySites.count) EPA site(s) nearby"
                    }
                case .milpitasOdor:
                    let aqi = airQualityService.data?.aqi ?? 55
                    let aqiScore = aqi <= 50 ? 95 : aqi <= 100 ? 75 : aqi <= 150 ? 50 : 25
                    categories[i].score = aqiScore
                    categories[i].scoreLabel = airQualityService.data?.category ?? "Moderate"
                case .crime:
                    categories[i].score = crimeService.stats.score
                    categories[i].scoreLabel = crimeService.stats.label
                case .fireHazard:
                    // Find nearest fire hazard zone using point-in-polygon or proximity
                    var worstSeverity = "None"
                    var minDist = Double.infinity
                    for zone in fireService.hazardZones {
                        // Check proximity to zone polygon vertices
                        for pt in zone.coordinates {
                            let d = sqrt(pow(pt.latitude - coord.latitude, 2) + pow(pt.longitude - coord.longitude, 2))
                            if d < minDist {
                                minDist = d
                                worstSeverity = zone.severity
                            }
                        }
                    }
                    // Also check point-in-polygon for each zone
                    for zone in fireService.hazardZones {
                        if pointInPolygon(coord, polygon: zone.coordinates) {
                            worstSeverity = zone.severity
                            minDist = 0
                            break
                        }
                    }
                    let fireScore: Int
                    let fireLabel: String
                    switch worstSeverity {
                    case "Extreme":
                        fireScore = 25; fireLabel = "Extreme Fire Risk"
                    case "Very High":
                        fireScore = minDist < 0.05 ? 40 : 55; fireLabel = "Very High Fire Risk"
                    case "High":
                        fireScore = minDist < 0.05 ? 60 : 72; fireLabel = "High Fire Risk"
                    default:
                        fireScore = 88; fireLabel = "Low Fire Risk"
                    }
                    categories[i].score = fireScore
                    categories[i].scoreLabel = fireLabel
                case .schools:
                    let nearbySchools = schoolService.schools.filter {
                        abs($0.coordinate.latitude - coord.latitude) < 0.05 &&
                        abs($0.coordinate.longitude - coord.longitude) < 0.06
                    }.sorted {
                        let d0 = pow($0.coordinate.latitude-coord.latitude,2)+pow($0.coordinate.longitude-coord.longitude,2)
                        let d1 = pow($1.coordinate.latitude-coord.latitude,2)+pow($1.coordinate.longitude-coord.longitude,2)
                        return d0 < d1
                    }
                    let avgRating = nearbySchools.isEmpty ? 6 :
                        nearbySchools.map(\.rating).reduce(0,+) / nearbySchools.count
                    let schoolScore = min(100, avgRating * 10 + (nearbySchools.count > 5 ? 5 : 0))
                    categories[i].score = schoolScore
                    if let top = nearbySchools.first {
                        categories[i].scoreLabel = "\(nearbySchools.count) schools · avg \(avgRating)/10"
                    } else {
                        categories[i].scoreLabel = "No schools found nearby"
                    }
                case .noise:
                    // Find loudest noise zone containing or nearest to coordinate
                    var loudestDb = 40
                    for zone in noiseService.zones {
                        if pointInPolygon(coord, polygon: zone.polygon) {
                            if zone.dbLevel > loudestDb { loudestDb = zone.dbLevel }
                        }
                    }
                    // If not inside any zone, find nearest zone
                    if loudestDb == 40 {
                        var nearestDist = Double.infinity
                        for zone in noiseService.zones {
                            for pt in zone.polygon {
                                let d = sqrt(pow(pt.latitude - coord.latitude, 2) + pow(pt.longitude - coord.longitude, 2))
                                if d < nearestDist { nearestDist = d; loudestDb = max(loudestDb, zone.dbLevel - Int(nearestDist * 500)) }
                            }
                        }
                    }
                    let noiseScore = max(10, 100 - max(0, loudestDb - 40) * 2)
                    let noiseLabel: String
                    switch loudestDb {
                    case 75...: noiseLabel = "Very Loud (>\(loudestDb)dB)"
                    case 65...: noiseLabel = "Loud (~\(loudestDb)dB)"
                    case 55...: noiseLabel = "Moderate (~\(loudestDb)dB)"
                    default:    noiseLabel = "Quiet (<55dB)"
                    }
                    categories[i].score = noiseScore
                    categories[i].scoreLabel = noiseLabel
                case .electricLines:
                    // Find minimum distance to any transmission line segment
                    var minLineDistDeg = Double.infinity
                    var closestVoltage = 0
                    for line in electricService.lines {
                        let coords = line.coordinates
                        for j in 0..<max(0, coords.count-1) {
                            let p1 = coords[j]; let p2 = coords[j+1]
                            let dx = p2.longitude - p1.longitude
                            let dy = p2.latitude  - p1.latitude
                            let lenSq = dx*dx + dy*dy
                            let t = lenSq > 0 ? max(0, min(1, ((coord.longitude-p1.longitude)*dx + (coord.latitude-p1.latitude)*dy)/lenSq)) : 0
                            let nearLat = p1.latitude + t*dy
                            let nearLon = p1.longitude + t*dx
                            let d = sqrt(pow(coord.latitude-nearLat,2) + pow(coord.longitude-nearLon,2))
                            if d < minLineDistDeg { minLineDistDeg = d; closestVoltage = line.voltage }
                        }
                    }
                    let distMilesElec = minLineDistDeg * 69.0
                    let elecScore: Int
                    let elecLabel: String
                    if distMilesElec < 0.1 {
                        elecScore = 45; elecLabel = "Very Close (\(closestVoltage)kV line)"
                    } else if distMilesElec < 0.3 {
                        elecScore = 62; elecLabel = "Nearby (\(closestVoltage)kV, \(String(format:"%.1f",distMilesElec))mi)"
                    } else if distMilesElec < 1.0 {
                        elecScore = 78; elecLabel = "\(String(format:"%.1f",distMilesElec))mi to nearest line"
                    } else {
                        elecScore = 92; elecLabel = "Low Exposure (>\(Int(distMilesElec))mi)"
                    }
                    categories[i].score = elecScore
                    categories[i].scoreLabel = elecLabel
                case .population:
                    if let pop = populationService.info {
                        let densityScore = max(20, min(95, 100 - (pop.density - 3000) / 120))
                        categories[i].score = densityScore
                        let densityK = String(format: "%.1f", Double(pop.density) / 1000.0)
                        categories[i].scoreLabel = "\(densityK)k/sq mi · \(pop.cityName)"
                    } else {
                        categories[i].score = 70
                        categories[i].scoreLabel = "~5k / sq mi"
                    }
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

    // MARK: - Geometry Helpers
    /// Ray-casting point-in-polygon test
    func pointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude; let yi = polygon[i].latitude
            let xj = polygon[j].longitude; let yj = polygon[j].latitude
            if ((yi > point.latitude) != (yj > point.latitude)) &&
               (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
                inside = !inside
            }
            j = i
        }
        return inside
    }

    // MARK: - Zone Data
    func crimeMapZones() -> [MapZone] {
        [
            // ─── HIGH CRIME ZONES ────────────────────────────────────────────
            // East San Jose (highest crime in SCC)
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.360, longitude: -121.910),
                CLLocationCoordinate2D(latitude: 37.340, longitude: -121.880),
                CLLocationCoordinate2D(latitude: 37.320, longitude: -121.870),
                CLLocationCoordinate2D(latitude: 37.315, longitude: -121.840),
                CLLocationCoordinate2D(latitude: 37.335, longitude: -121.830),
                CLLocationCoordinate2D(latitude: 37.360, longitude: -121.860),
                CLLocationCoordinate2D(latitude: 37.375, longitude: -121.895),
            ], value: 0.88),
            // Downtown Oakland / West Oakland
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.830, longitude: -122.310),
                CLLocationCoordinate2D(latitude: 37.812, longitude: -122.285),
                CLLocationCoordinate2D(latitude: 37.798, longitude: -122.268),
                CLLocationCoordinate2D(latitude: 37.792, longitude: -122.280),
                CLLocationCoordinate2D(latitude: 37.800, longitude: -122.300),
                CLLocationCoordinate2D(latitude: 37.815, longitude: -122.318),
                CLLocationCoordinate2D(latitude: 37.828, longitude: -122.322),
            ], value: 0.92),
            // East Oakland (Fruitvale / San Antonio)
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.778, longitude: -122.228),
                CLLocationCoordinate2D(latitude: 37.762, longitude: -122.215),
                CLLocationCoordinate2D(latitude: 37.748, longitude: -122.218),
                CLLocationCoordinate2D(latitude: 37.745, longitude: -122.235),
                CLLocationCoordinate2D(latitude: 37.755, longitude: -122.248),
                CLLocationCoordinate2D(latitude: 37.772, longitude: -122.245),
            ], value: 0.85),
            // Richmond (Iron Triangle)
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.942, longitude: -122.372),
                CLLocationCoordinate2D(latitude: 37.928, longitude: -122.355),
                CLLocationCoordinate2D(latitude: 37.918, longitude: -122.358),
                CLLocationCoordinate2D(latitude: 37.915, longitude: -122.375),
                CLLocationCoordinate2D(latitude: 37.925, longitude: -122.390),
                CLLocationCoordinate2D(latitude: 37.938, longitude: -122.388),
            ], value: 0.90),
            // SF Tenderloin / SoMa
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.785, longitude: -122.418),
                CLLocationCoordinate2D(latitude: 37.778, longitude: -122.408),
                CLLocationCoordinate2D(latitude: 37.772, longitude: -122.412),
                CLLocationCoordinate2D(latitude: 37.775, longitude: -122.425),
                CLLocationCoordinate2D(latitude: 37.782, longitude: -122.430),
            ], value: 0.88),
            // SF Mission / Bayview
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.758, longitude: -122.418),
                CLLocationCoordinate2D(latitude: 37.742, longitude: -122.405),
                CLLocationCoordinate2D(latitude: 37.732, longitude: -122.395),
                CLLocationCoordinate2D(latitude: 37.728, longitude: -122.408),
                CLLocationCoordinate2D(latitude: 37.738, longitude: -122.425),
                CLLocationCoordinate2D(latitude: 37.752, longitude: -122.428),
            ], value: 0.78),
            // Antioch / Pittsburg
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 38.012, longitude: -121.832),
                CLLocationCoordinate2D(latitude: 37.998, longitude: -121.815),
                CLLocationCoordinate2D(latitude: 37.988, longitude: -121.820),
                CLLocationCoordinate2D(latitude: 37.985, longitude: -121.840),
                CLLocationCoordinate2D(latitude: 37.995, longitude: -121.855),
                CLLocationCoordinate2D(latitude: 38.008, longitude: -121.850),
            ], value: 0.75),
            // Hayward East
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.678, longitude: -122.090),
                CLLocationCoordinate2D(latitude: 37.662, longitude: -122.075),
                CLLocationCoordinate2D(latitude: 37.648, longitude: -122.078),
                CLLocationCoordinate2D(latitude: 37.648, longitude: -122.098),
                CLLocationCoordinate2D(latitude: 37.662, longitude: -122.108),
                CLLocationCoordinate2D(latitude: 37.676, longitude: -122.105),
            ], value: 0.72),

            // ─── MODERATE CRIME ZONES ─────────────────────────────────────────
            // Central San Jose / Downtown
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.400, longitude: -121.970),
                CLLocationCoordinate2D(latitude: 37.385, longitude: -121.960),
                CLLocationCoordinate2D(latitude: 37.370, longitude: -121.950),
                CLLocationCoordinate2D(latitude: 37.360, longitude: -121.965),
                CLLocationCoordinate2D(latitude: 37.375, longitude: -121.980),
                CLLocationCoordinate2D(latitude: 37.395, longitude: -121.988),
            ], value: 0.50),
            // North Oakland / Temescal
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.842, longitude: -122.272),
                CLLocationCoordinate2D(latitude: 37.832, longitude: -122.262),
                CLLocationCoordinate2D(latitude: 37.822, longitude: -122.265),
                CLLocationCoordinate2D(latitude: 37.820, longitude: -122.278),
                CLLocationCoordinate2D(latitude: 37.830, longitude: -122.288),
                CLLocationCoordinate2D(latitude: 37.840, longitude: -122.285),
            ], value: 0.52),
            // San Jose North (Willow Glen area)
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.325, longitude: -121.925),
                CLLocationCoordinate2D(latitude: 37.308, longitude: -121.912),
                CLLocationCoordinate2D(latitude: 37.295, longitude: -121.918),
                CLLocationCoordinate2D(latitude: 37.298, longitude: -121.938),
                CLLocationCoordinate2D(latitude: 37.312, longitude: -121.948),
                CLLocationCoordinate2D(latitude: 37.325, longitude: -121.942),
            ], value: 0.45),
            // Concord / Central CC
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.985, longitude: -122.052),
                CLLocationCoordinate2D(latitude: 37.972, longitude: -122.038),
                CLLocationCoordinate2D(latitude: 37.960, longitude: -122.042),
                CLLocationCoordinate2D(latitude: 37.958, longitude: -122.062),
                CLLocationCoordinate2D(latitude: 37.970, longitude: -122.075),
                CLLocationCoordinate2D(latitude: 37.982, longitude: -122.070),
            ], value: 0.48),
            // San Rafael
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.978, longitude: -122.538),
                CLLocationCoordinate2D(latitude: 37.965, longitude: -122.525),
                CLLocationCoordinate2D(latitude: 37.958, longitude: -122.530),
                CLLocationCoordinate2D(latitude: 37.960, longitude: -122.548),
                CLLocationCoordinate2D(latitude: 37.972, longitude: -122.555),
            ], value: 0.42),

            // ─── LOW CRIME ZONES ──────────────────────────────────────────────
            // Cupertino / Sunnyvale (very safe)
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.360, longitude: -122.060),
                CLLocationCoordinate2D(latitude: 37.330, longitude: -122.040),
                CLLocationCoordinate2D(latitude: 37.310, longitude: -122.020),
                CLLocationCoordinate2D(latitude: 37.300, longitude: -122.050),
                CLLocationCoordinate2D(latitude: 37.325, longitude: -122.075),
                CLLocationCoordinate2D(latitude: 37.355, longitude: -122.080),
            ], value: 0.10),
            // Saratoga / Los Gatos
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.288, longitude: -122.048),
                CLLocationCoordinate2D(latitude: 37.268, longitude: -122.028),
                CLLocationCoordinate2D(latitude: 37.252, longitude: -122.015),
                CLLocationCoordinate2D(latitude: 37.248, longitude: -122.038),
                CLLocationCoordinate2D(latitude: 37.260, longitude: -122.058),
                CLLocationCoordinate2D(latitude: 37.278, longitude: -122.065),
            ], value: 0.08),
            // Palo Alto / Menlo Park
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.458, longitude: -122.178),
                CLLocationCoordinate2D(latitude: 37.438, longitude: -122.158),
                CLLocationCoordinate2D(latitude: 37.418, longitude: -122.148),
                CLLocationCoordinate2D(latitude: 37.410, longitude: -122.168),
                CLLocationCoordinate2D(latitude: 37.425, longitude: -122.188),
                CLLocationCoordinate2D(latitude: 37.448, longitude: -122.195),
            ], value: 0.10),
            // Marin (Mill Valley / Tiburon)
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.912, longitude: -122.558),
                CLLocationCoordinate2D(latitude: 37.895, longitude: -122.538),
                CLLocationCoordinate2D(latitude: 37.882, longitude: -122.542),
                CLLocationCoordinate2D(latitude: 37.882, longitude: -122.562),
                CLLocationCoordinate2D(latitude: 37.895, longitude: -122.572),
                CLLocationCoordinate2D(latitude: 37.910, longitude: -122.570),
            ], value: 0.08),
            // Piedmont / Oakland Hills
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.832, longitude: -122.242),
                CLLocationCoordinate2D(latitude: 37.820, longitude: -122.228),
                CLLocationCoordinate2D(latitude: 37.812, longitude: -122.235),
                CLLocationCoordinate2D(latitude: 37.812, longitude: -122.252),
                CLLocationCoordinate2D(latitude: 37.822, longitude: -122.262),
                CLLocationCoordinate2D(latitude: 37.830, longitude: -122.258),
            ], value: 0.12),
            // Orinda / Moraga / Lafayette
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.892, longitude: -122.188),
                CLLocationCoordinate2D(latitude: 37.872, longitude: -122.165),
                CLLocationCoordinate2D(latitude: 37.855, longitude: -122.158),
                CLLocationCoordinate2D(latitude: 37.848, longitude: -122.178),
                CLLocationCoordinate2D(latitude: 37.860, longitude: -122.205),
                CLLocationCoordinate2D(latitude: 37.878, longitude: -122.212),
            ], value: 0.10),
            // Dublin / Pleasanton / San Ramon (Tri-Valley safe suburbs)
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.722, longitude: -121.958),
                CLLocationCoordinate2D(latitude: 37.698, longitude: -121.935),
                CLLocationCoordinate2D(latitude: 37.668, longitude: -121.898),
                CLLocationCoordinate2D(latitude: 37.658, longitude: -121.920),
                CLLocationCoordinate2D(latitude: 37.672, longitude: -121.952),
                CLLocationCoordinate2D(latitude: 37.698, longitude: -121.968),
                CLLocationCoordinate2D(latitude: 37.718, longitude: -121.978),
            ], value: 0.12),
            // SF Pacific Heights / Marina / Noe Valley
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.800, longitude: -122.442),
                CLLocationCoordinate2D(latitude: 37.792, longitude: -122.428),
                CLLocationCoordinate2D(latitude: 37.782, longitude: -122.432),
                CLLocationCoordinate2D(latitude: 37.782, longitude: -122.448),
                CLLocationCoordinate2D(latitude: 37.790, longitude: -122.458),
                CLLocationCoordinate2D(latitude: 37.798, longitude: -122.455),
            ], value: 0.18),
        ]
    }

    func odorMapZones() -> [MapZone] {
        [
            // Newby Island Landfill (Milpitas) — worst odor source
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.462, longitude: -121.912),
                CLLocationCoordinate2D(latitude: 37.448, longitude: -121.908),
                CLLocationCoordinate2D(latitude: 37.435, longitude: -121.918),
                CLLocationCoordinate2D(latitude: 37.435, longitude: -121.938),
                CLLocationCoordinate2D(latitude: 37.448, longitude: -121.948),
                CLLocationCoordinate2D(latitude: 37.462, longitude: -121.932),
            ], value: 3),
            // Milpitas / North SJ downwind plume
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.430, longitude: -121.990),
                CLLocationCoordinate2D(latitude: 37.420, longitude: -121.970),
                CLLocationCoordinate2D(latitude: 37.430, longitude: -121.950),
                CLLocationCoordinate2D(latitude: 37.445, longitude: -121.915),
                CLLocationCoordinate2D(latitude: 37.462, longitude: -121.912),
                CLLocationCoordinate2D(latitude: 37.462, longitude: -121.932),
                CLLocationCoordinate2D(latitude: 37.448, longitude: -121.948),
            ], value: 2),
            // Fremont / Newark industrial corridor
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.548, longitude: -122.010),
                CLLocationCoordinate2D(latitude: 37.528, longitude: -122.000),
                CLLocationCoordinate2D(latitude: 37.508, longitude: -121.990),
                CLLocationCoordinate2D(latitude: 37.498, longitude: -122.008),
                CLLocationCoordinate2D(latitude: 37.515, longitude: -122.025),
                CLLocationCoordinate2D(latitude: 37.538, longitude: -122.030),
            ], value: 2),
            // Richmond refinery corridor (Chevron, Marathon)
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.952, longitude: -122.408),
                CLLocationCoordinate2D(latitude: 37.938, longitude: -122.388),
                CLLocationCoordinate2D(latitude: 37.925, longitude: -122.378),
                CLLocationCoordinate2D(latitude: 37.915, longitude: -122.388),
                CLLocationCoordinate2D(latitude: 37.922, longitude: -122.412),
                CLLocationCoordinate2D(latitude: 37.938, longitude: -122.425),
            ], value: 3),
            // Vallejo / Benicia industrial
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 38.118, longitude: -122.248),
                CLLocationCoordinate2D(latitude: 38.102, longitude: -122.232),
                CLLocationCoordinate2D(latitude: 38.088, longitude: -122.238),
                CLLocationCoordinate2D(latitude: 38.088, longitude: -122.258),
                CLLocationCoordinate2D(latitude: 38.102, longitude: -122.268),
                CLLocationCoordinate2D(latitude: 38.115, longitude: -122.262),
            ], value: 2),
            // SF Bayview / Hunters Point industrial
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.732, longitude: -122.378),
                CLLocationCoordinate2D(latitude: 37.718, longitude: -122.362),
                CLLocationCoordinate2D(latitude: 37.708, longitude: -122.368),
                CLLocationCoordinate2D(latitude: 37.712, longitude: -122.388),
                CLLocationCoordinate2D(latitude: 37.722, longitude: -122.395),
                CLLocationCoordinate2D(latitude: 37.732, longitude: -122.390),
            ], value: 2),
            // East Bay flatlands / port area
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.812, longitude: -122.302),
                CLLocationCoordinate2D(latitude: 37.798, longitude: -122.285),
                CLLocationCoordinate2D(latitude: 37.782, longitude: -122.272),
                CLLocationCoordinate2D(latitude: 37.778, longitude: -122.290),
                CLLocationCoordinate2D(latitude: 37.790, longitude: -122.308),
                CLLocationCoordinate2D(latitude: 37.808, longitude: -122.318),
            ], value: 2),
            // South Bay light industry (Mountain View / Sunnyvale)
            MapZone(coordinates: [
                CLLocationCoordinate2D(latitude: 37.430, longitude: -122.010),
                CLLocationCoordinate2D(latitude: 37.410, longitude: -122.030),
                CLLocationCoordinate2D(latitude: 37.390, longitude: -122.000),
                CLLocationCoordinate2D(latitude: 37.400, longitude: -121.970),
                CLLocationCoordinate2D(latitude: 37.420, longitude: -121.980),
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
}

// MARK: - Score Card View
struct ScoreCardView: View {
    @Binding var category: NeighborhoodCategory
    var isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                if let score = category.score {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100.0)
                        .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                }
                Circle()
                    .fill(category.color.opacity(isSelected ? 0.22 : 0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: category.icon)
                    .font(.system(size: 17))
                    .foregroundColor(category.color)
            }
            .frame(width: 52, height: 52)
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
                ProgressView()
                    .scaleEffect(0.55)
                    .frame(height: 16)
                    .padding(.top, 4)
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
            VStack(spacing: 1) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : category.color)
                    .frame(height: 20)
                Text(shortName(category.name))
                    .font(.system(size: 7, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 50)
            }
            .frame(width: 54, height: 38)
            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? category.color : Color.clear))
        }
    }

    func shortName(_ name: String) -> String {
        switch name {
        case "Air Quality / Odor": return "Air"
        case "Supportive Housing": return "Housing"
        case "Electric Lines":     return "Electric"
        case "Fire Hazard":        return "Fire"
        default:                   return name
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
