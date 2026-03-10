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

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.450, longitude: -122.050),
        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
    )
    @State private var selectedCategory: CategoryType = .population
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @StateObject private var searchCompleter = SearchCompleterService()
    @State private var isSearchFocused = false
    // Population / ZIP layer
    @State private var zipRegions: [ZIPCodeRegion] = ZIPCodeData.allZIPs()
    @State private var selectedZIP: ZIPCodeRegion?
    @State private var highlightedZIPId: String? = nil
    @State private var currentSpan   = MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
    @State private var currentCenter = CLLocationCoordinate2D(latitude: 37.450, longitude: -122.050)
    @State private var pinnedLocation: CLLocationCoordinate2D?
    @State private var pinnedAddress  = ""
    @State private var categories     = NeighborhoodCategory.all
    @State private var isLoadingScores = false
    @State private var showCrimeDetails = false
    @State private var crimeIncidents: [CrimeMarker] = []
    @State private var selectedSchool: School?
    @State private var selectedSuperfund: SuperfundSite?
    @State private var selectedHousing: SupportiveHousingFacility?
    @State private var apiErrorMessage: String?

    /// Collects the first non-nil error from any service
    private var activeServiceError: String? {
        earthquakeService.errorMessage ??
        crimeService.errorMessage ??
        airQualityService.errorMessage ??
        electricService.errorMessage ??
        noiseService.errorMessage
    }

    var body: some View {
        ZStack {
            mapLayer

            // Top: NavBar + Search
            VStack(spacing: 0) {
                navBar
                searchBar
                if !searchResults.isEmpty || !searchCompleter.completions.isEmpty { searchDropdown }
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
                    VStack(alignment: .trailing, spacing: 8) {
                        // Details toggle (crime layer only)
                        if selectedCategory == .crime {
                            HStack(spacing: 8) {
                                Text("Details")
                                    .font(.subheadline).fontWeight(.medium)
                                Toggle("", isOn: $showCrimeDetails)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .tint(.blue)
                                    .scaleEffect(0.85)
                                    .onChange(of: showCrimeDetails) { _, on in
                                        if on { refreshCrimeIncidents() }
                                        else { crimeIncidents = [] }
                                    }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(.regularMaterial)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.12), radius: 4)
                        }
                        sideBar
                    }
                }
                Spacer().frame(height: pinnedLocation != nil ? 280 : 120)
            }

            // Zoom + location buttons (bottom-right, above panel)
            VStack {
                Spacer()
                HStack {
                    // Legend bottom-left
                    VStack(alignment: .leading, spacing: 6) {
                        LegendView(category: selectedCategory)
                        // Noise loading/zoom hint
                        if selectedCategory == .noise {
                            if noiseService.isLoading {
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.7)
                                    Text("Loading road data...").font(.caption2)
                                }
                                .padding(8).background(.regularMaterial).cornerRadius(8)
                            } else if noiseService.needsZoomIn {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption)
                                    Text("Zoom in to see street noise").font(.caption2)
                                }
                                .padding(8).background(.regularMaterial).cornerRadius(8)
                            } else if !noiseService.roads.isEmpty {
                                Text("\(noiseService.roads.count) roads loaded").font(.caption2)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(.regularMaterial).cornerRadius(8)
                            }
                        }
                    }
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

            // ── API Error Banner ─────────────────────────────────────────────
            if let error = apiErrorMessage {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .accessibilityIdentifier("errorBannerText")
                        Spacer()
                        Button { withAnimation { apiErrorMessage = nil } } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.regularMaterial)
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.15), radius: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 160)
                    Spacer()
                }
                .allowsHitTesting(true)
                .zIndex(15)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── ZIP Bottom Drawer ────────────────────────────────────────────
            // Custom overlay in same ZStack → selectedZIP changes propagate
            // instantly without any .sheet() modal sync issues.
            if let zip = selectedZIP {
                ZIPBottomDrawer(zip: zip) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedZIP      = nil
                        highlightedZIPId = nil
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3), value: zip.id)
                .allowsHitTesting(true)
                .zIndex(20)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            locationService.requestPermission()
            loadLayerIfNeeded(.population)
        }
        .onChange(of: activeServiceError) { _, error in
            if let error {
                withAnimation { apiErrorMessage = error }
                // Auto-dismiss after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation { apiErrorMessage = nil }
                }
            }
        }
        .onChange(of: locationService.location) { _, loc in
            // Fly to user location the FIRST time we get a fix
            guard let loc, currentCenter.latitude == 37.450 else { return }
            let coord = loc.coordinate
            currentCenter = coord
            currentSpan   = MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            mapRegion     = MKCoordinateRegion(center: coord, span: currentSpan)
        }
        .onChange(of: selectedCategory) { _, _ in
            // Auto-dismiss ZIP drawer when switching any layer
            if selectedZIP != nil {
                withAnimation(.spring(response: 0.3)) {
                    selectedZIP      = nil
                    highlightedZIPId = nil
                }
            }
            // Auto-dismiss neighborhood panel when switching any layer
            if pinnedLocation != nil {
                pinnedLocation = nil
                pinnedAddress  = ""
                for i in categories.indices {
                    categories[i].score      = nil
                    categories[i].scoreLabel = nil
                }
            }
        }
        .sheet(item: $selectedSchool) { school in SchoolDetailSheet(school: school) }
        .sheet(item: $selectedSuperfund) { site in SuperfundDetailSheet(site: site) }
        .sheet(item: $selectedHousing) { f in HousingDetailSheet(facility: f) }

    }

    // MARK: - Map (HFMapView — UIKit MKMapView for full overlay control)
    var mapLayer: some View {
        HFMapView(
            region: $mapRegion,
            selectedCategory: selectedCategory,
            showCrimeDetails: showCrimeDetails,
            pinnedLocation: pinnedLocation,
            noiseRoads: noiseService.roads,
            earthquakes: earthquakeService.events,
            schools: schoolService.schools,
            superfundSites: superfundService.sites,
            housingFacilities: housingService.facilities,
            fireZones: fireService.hazardZones,
            electricLines: electricService.lines,
            odorZones: odorMapZones(),
            zipRegions: zipRegions,
            highlightedZIPId: highlightedZIPId,
            crimeMarkers: crimeIncidents,
            onCameraChange: { region in
                currentCenter = region.center
                currentSpan   = region.span
                mapRegion     = region
                if selectedCategory == .noise {
                    noiseService.fetchForRegion(region)
                }
                if selectedCategory == .crime && showCrimeDetails {
                    refreshCrimeIncidents()
                }
            },
            onSchoolTap:   { selectedSchool    = $0 },
            onSuperfundTap:{ selectedSuperfund = $0 },
            onHousingTap:  { selectedHousing   = $0 },
            onZIPTap: { region in
                highlightedZIPId = region.id
                selectedZIP      = region  // drawer re-renders instantly (same ZStack)

                // ── Zoom to fit full ZIP polygon ──────────────────────────
                // Calculate bounding box of polygon coordinates
                let lats = region.polygon.map { $0.latitude }
                let lons = region.polygon.map { $0.longitude }
                let rawLatSpan = max(0.012, (lats.max() ?? 0) - (lats.min() ?? 0))
                let rawLonSpan = max(0.012, (lons.max() ?? 0) - (lons.min() ?? 0))
                // Sheet covers 52% → visible map = 48%.
                // ZIP fills ~80% of visible area → latSpan = rawLatSpan / (0.48 * 0.80)
                let latSpan = max(0.04, rawLatSpan / 0.38)
                // Longitude: full width visible, 30% margin each side
                let lonSpan = max(0.04, rawLonSpan / 0.70)
                // Offset center south so ZIP appears in visible-area center
                // (visible center = 24% from top; map center = 50% → offset 26%)
                let southOffset = latSpan * 0.26
                let adjustedCenter = CLLocationCoordinate2D(
                    latitude:  region.center.latitude - southOffset,
                    longitude: region.center.longitude
                )
                currentCenter = adjustedCenter
                currentSpan   = MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
                mapRegion     = MKCoordinateRegion(center: adjustedCenter,
                                                   span: currentSpan)
            },
            onMapTap: { coord in
                // tap in non-population layers: no-op (handled by long press now)
                _ = coord
            },
            onNoiseFetchCancel: {
                noiseService.cancelFetch()
            },
            onMapLongPress: { coord in
                pinnedLocation = coord
                computeScores(coord: coord)
            }
        )
        .ignoresSafeArea()
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
                    .accessibilityIdentifier("appTitle")
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
                .accessibilityIdentifier("searchField")
                .autocorrectionDisabled()
                .onSubmit { performSearch() }
                .onChange(of: searchText) { _, v in
                    if v.isEmpty {
                        searchResults = []
                        searchCompleter.clear()
                    } else {
                        // MKLocalSearchCompleter gives instant fuzzy suggestions
                        searchCompleter.search(v)
                        // Also run full search for richer results
                        if v.count >= 2 { performSearch() }
                    }
                }
            if !searchText.isEmpty {
                Button { searchText = ""; searchResults = []; searchCompleter.clear() } label: {
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
            // Completer suggestions (fast, fuzzy, instant)
            ForEach(searchCompleter.completions.prefix(4)) { completion in
                Button {
                    resolveCompletion(completion)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue).font(.subheadline)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(completion.title)
                                .font(.subheadline).fontWeight(.medium).foregroundColor(.primary)
                            if !completion.subtitle.isEmpty {
                                Text(completion.subtitle)
                                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                }
                Divider().padding(.leading, 50)
            }

            // Full search results (slower, but has coordinates)
            if !searchResults.isEmpty {
                if !searchCompleter.completions.isEmpty {
                    HStack {
                        Text("Best Matches").font(.caption2).foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Color(UIColor.secondarySystemBackground))
                }
                ForEach(searchResults.prefix(4), id: \.self) { item in
                    Button { selectItem(item) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red).font(.subheadline)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? "")
                                    .font(.subheadline).fontWeight(.medium).foregroundColor(.primary)
                                Text(item.placemark.title ?? "")
                                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                    }
                    Divider().padding(.leading, 50)
                }
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
                        loadLayerIfNeeded(cat.id)
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
        .accessibilityIdentifier("layerSidebar")
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
                        .accessibilityIdentifier("emptyStateHint")
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
                        .accessibilityIdentifier("neighborhoodReportTitle")
                    Text(pinnedAddress)
                        .font(.caption).foregroundColor(.secondary).lineLimit(2)
                        .accessibilityIdentifier("pinnedAddress")
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
                        .accessibilityIdentifier("scoringProgress")
                        .padding()
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach($categories) { $cat in
                            ScoreCardView(category: $cat, isSelected: selectedCategory == cat.id)
                                .onTapGesture {
                                    selectedCategory = cat.id
                                    loadLayerIfNeeded(cat.id)
                                }
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
                mapRegion = MKCoordinateRegion(center: currentCenter, span: currentSpan)
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
    /// Lazy loader — only fetches data when a layer is first activated
    func loadLayerIfNeeded(_ layer: CategoryType) {
        switch layer {
        case .crime:
            break  // CrimeTileOverlay handles rendering; no pre-computation needed
        case .noise:
            // Noise always re-fetches based on viewport (Overpass API)
            noiseService.fetchForRegion(MKCoordinateRegion(center: currentCenter, span: currentSpan))
        case .earthquake:
            if earthquakeService.events.isEmpty {
                earthquakeService.fetch()
            }
        case .fireHazard:
            if fireService.hazardZones.isEmpty {
                fireService.fetchFireData()
            }
        case .electricLines:
            if electricService.lines.isEmpty {
                electricService.fetch()
            }
        case .supportiveHome:
            if housingService.facilities.isEmpty {
                housingService.fetch()
            }
        case .milpitasOdor:
            if airQualityService.data == nil {
                airQualityService.fetch(lat: currentCenter.latitude, lon: currentCenter.longitude)
            }
        default:
            // Schools, Superfund, Population: hardcoded, always available
            break
        }
    }

    func refreshCrimeIncidents() {
        guard currentSpan.latitudeDelta < 0.08 else { crimeIncidents = []; return }
        // Generate mock crime incidents around the visible area
        let lat = currentCenter.latitude
        let lon = currentCenter.longitude
        let spread = currentSpan.latitudeDelta * 0.45
        let types: [CrimeType] = [.violent, .property, .vehicle, .vandalism, .other]
        var incidents: [CrimeMarker] = []
        // Get crime density for this area
        let baseValue = CrimeTileOverlay.crimeValue(lat: lat, lon: lon)
        let count = Int(baseValue * 25) + 3  // more incidents in high-crime areas
        for _ in 0..<count {
            let rLat = lat + Double.random(in: -spread...spread)
            let rLon = lon + Double.random(in: -spread...spread)
            let localVal = CrimeTileOverlay.crimeValue(lat: rLat, lon: rLon)
            let type_ = localVal > 0.6
                ? (Bool.random() ? CrimeType.violent : CrimeType.property)
                : types.randomElement()!
            let days = Int.random(in: 1...30)
            incidents.append(CrimeMarker(
                coordinate: CLLocationCoordinate2D(latitude: rLat, longitude: rLon),
                type: type_,
                count: Int.random(in: 1...max(1, Int(min(8.0, localVal * 8)))),
                daysAgo: days
            ))
        }
        crimeIncidents = incidents
    }


    func zoom(in zoomIn: Bool) {
        let factor: Double = zoomIn ? 0.5 : 2.0
        currentSpan = MKCoordinateSpan(
            latitudeDelta: max(0.002, min(180, currentSpan.latitudeDelta * factor)),
            longitudeDelta: max(0.002, min(360, currentSpan.longitudeDelta * factor))
        )
        mapRegion = MKCoordinateRegion(center: currentCenter, span: currentSpan)
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
        // Bias results toward Bay Area
        req.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.650, longitude: -122.100),
            span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
        )
        req.resultTypes = [.address, .pointOfInterest]
        let search = MKLocalSearch(request: req)
        search.start { resp, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.apiErrorMessage = "Search failed: \(error.localizedDescription)"
                    self.searchResults = []
                } else {
                    self.searchResults = resp?.mapItems ?? []
                }
            }
        }
    }

    func resolveCompletion(_ completion: SearchCompletion) {
        let req = MKLocalSearch.Request(completion: completion.original)
        MKLocalSearch(request: req).start { resp, error in
            DispatchQueue.main.async {
                if let item = resp?.mapItems.first {
                    self.selectItem(item)
                } else if let error = error {
                    self.apiErrorMessage = "Could not resolve address: \(error.localizedDescription)"
                }
            }
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
        mapRegion = MKCoordinateRegion(center: c, span: currentSpan)
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
        for i in categories.indices { categories[i].score = nil; categories[i].scoreLabel = nil }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            for i in categories.indices {
                let result: ScoringService.ScoreResult
                switch categories[i].id {
                case .earthquake:
                    result = ScoringService.earthquakeScore(events: earthquakeService.events, coord: coord)
                case .superfund:
                    result = ScoringService.superfundScore(sites: superfundService.sites, coord: coord)
                case .milpitasOdor:
                    result = ScoringService.airQualityScore(data: airQualityService.data)
                case .crime:
                    result = ScoringService.crimeScore(stats: crimeService.stats)
                case .fireHazard:
                    result = ScoringService.fireScore(zones: fireService.hazardZones, coord: coord)
                case .schools:
                    result = ScoringService.schoolScore(schools: schoolService.schools, coord: coord)
                case .noise:
                    result = ScoringService.noiseScore(zones: noiseService.zones, roads: noiseService.roads, coord: coord)
                case .electricLines:
                    result = ScoringService.electricLineScore(lines: electricService.lines, coord: coord)
                case .population:
                    result = ScoringService.populationScore(info: populationService.info)
                case .supportiveHome:
                    result = ScoringService.supportiveHomeScore(facilities: housingService.facilities, coord: coord)
                }
                categories[i].score = result.score
                categories[i].scoreLabel = result.label
            }
            isLoadingScores = false
        }
    }

    // MARK: - Geometry Helpers
    func pointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        ScoringService.pointInPolygon(point, polygon: polygon)
    }


    /// Rough land mask — exclude open water cells
    func isLandCell(lat: Double, lon: Double) -> Bool {
        // Pacific Ocean (west of Bay Area coast)
        if lon < -122.55 && lat < 37.70 { return false }
        if lon < -122.65 && lat < 37.85 { return false }
        if lon < -122.75 { return false }
        // Deep SF Bay water only (narrow central channel)
        if lat > 37.60 && lat < 37.80 && lon > -122.30 && lon < -122.15 { return false }
        // San Pablo Bay deep water
        if lat > 37.96 && lat < 38.08 && lon > -122.42 && lon < -122.25 { return false }
        return true
    }

    /// Rough land mask — skip cells that are mostly ocean/bay water

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

    func crimeColor(_ v: Double) -> Color {
        // Reference app palette: deep red → orange → amber → light amber (all opaque)
        if v >= 0.72 { return Color(red: 0.75, green: 0.05, blue: 0.05) }  // deep red
        if v >= 0.55 { return Color(red: 0.92, green: 0.25, blue: 0.08) }  // red-orange
        if v >= 0.40 { return Color(red: 0.98, green: 0.52, blue: 0.15) }  // orange
        if v >= 0.28 { return Color(red: 0.99, green: 0.72, blue: 0.35) }  // amber
        if v >= 0.18 { return Color(red: 0.99, green: 0.86, blue: 0.60) }  // light amber
        return Color(red: 1.00, green: 0.93, blue: 0.78)                    // very light amber
    }
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
        .accessibilityIdentifier("layer_\(category.id.rawValue)")
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
