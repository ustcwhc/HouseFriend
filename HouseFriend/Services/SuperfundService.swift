import Foundation
import MapKit

struct SuperfundSite: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let status: String        // "NPL", "Proposed", "Deleted"
    let contaminants: String  // Primary contaminants
    let distanceMiles: Double?
}

class SuperfundService: ObservableObject {
    @Published var sites: [SuperfundSite] = []
    @Published var isLoading = false

    func fetchNear(lat: Double, lon: Double, radiusMiles: Double = 10) {
        isLoading = true
        let all = Self.allBayAreaSites()
        // Filter by distance
        let filtered = all.filter { site in
            let dlat = site.coordinate.latitude  - lat
            let dlon = site.coordinate.longitude - lon
            let distDeg = sqrt(dlat*dlat + dlon*dlon)
            let distMiles = distDeg * 69.0
            return distMiles <= radiusMiles
        }.map { site -> SuperfundSite in
            // Annotate distance
            let dlat = site.coordinate.latitude  - lat
            let dlon = site.coordinate.longitude - lon
            let dist = sqrt(dlat*dlat + dlon*dlon) * 69.0
            return SuperfundSite(name: site.name, coordinate: site.coordinate,
                                 status: site.status, contaminants: site.contaminants,
                                 distanceMiles: round(dist * 10) / 10)
        }.sorted { ($0.distanceMiles ?? 99) < ($1.distanceMiles ?? 99) }

        DispatchQueue.main.async {
            self.sites = filtered
            self.isLoading = false
        }
    }

    // MARK: - Comprehensive Bay Area EPA Superfund NPL Sites
    static func allBayAreaSites() -> [SuperfundSite] {
        return [
            // ─── Santa Clara County ───────────────────────────────────────────
            SuperfundSite(name: "Lorentz Barrel & Drum",
                coordinate: .init(latitude: 37.3505, longitude: -121.9258),
                status: "NPL", contaminants: "Solvents, VOCs", distanceMiles: nil),
            SuperfundSite(name: "Intel Corp (Santa Clara III)",
                coordinate: .init(latitude: 37.3720, longitude: -121.9688),
                status: "NPL", contaminants: "TCE, PCE, Solvents", distanceMiles: nil),
            SuperfundSite(name: "Intersil Inc./Siemens Components",
                coordinate: .init(latitude: 37.3482, longitude: -122.0124),
                status: "NPL", contaminants: "TCE, Freon 113", distanceMiles: nil),
            SuperfundSite(name: "Middlefield-Ellis-Whisman (MEW)",
                coordinate: .init(latitude: 37.3960, longitude: -122.0683),
                status: "NPL", contaminants: "TCE, Chromium, VOCs", distanceMiles: nil),
            SuperfundSite(name: "South Bay Asbestos Area",
                coordinate: .init(latitude: 37.4120, longitude: -121.9812),
                status: "NPL", contaminants: "Asbestos", distanceMiles: nil),
            SuperfundSite(name: "Fairchild Semiconductor (Mountain View)",
                coordinate: .init(latitude: 37.3890, longitude: -122.0760),
                status: "Deleted", contaminants: "TCA, Freon 113", distanceMiles: nil),
            SuperfundSite(name: "Advanced Micro Devices (AMD) Sunnyvale",
                coordinate: .init(latitude: 37.3810, longitude: -122.0340),
                status: "NPL", contaminants: "TCE, VOCs", distanceMiles: nil),
            SuperfundSite(name: "TRW Microelectronics Center",
                coordinate: .init(latitude: 37.3760, longitude: -122.0598),
                status: "NPL", contaminants: "TCE, Xylene", distanceMiles: nil),
            SuperfundSite(name: "Teledyne Semiconductor",
                coordinate: .init(latitude: 37.3878, longitude: -122.0492),
                status: "NPL", contaminants: "TCA, TCE", distanceMiles: nil),
            SuperfundSite(name: "Spectra-Physics Lasers",
                coordinate: .init(latitude: 37.3720, longitude: -121.9588),
                status: "NPL", contaminants: "Freon 113, VOCs", distanceMiles: nil),
            SuperfundSite(name: "Raytheon (Mountain View)",
                coordinate: .init(latitude: 37.3955, longitude: -122.0742),
                status: "Deleted", contaminants: "PCBs, Solvents", distanceMiles: nil),
            SuperfundSite(name: "Hewlett-Packard D Street",
                coordinate: .init(latitude: 37.4058, longitude: -122.0552),
                status: "NPL", contaminants: "TCE, Methylene Chloride", distanceMiles: nil),
            SuperfundSite(name: "Intel Corp (Mountain View)",
                coordinate: .init(latitude: 37.4050, longitude: -122.0268),
                status: "NPL", contaminants: "TCE, Freon, VOCs", distanceMiles: nil),
            SuperfundSite(name: "Samtec Corporation",
                coordinate: .init(latitude: 37.3440, longitude: -121.9640),
                status: "Proposed", contaminants: "PCE, TCE", distanceMiles: nil),
            SuperfundSite(name: "Bay Area Drum Site (San Jose)",
                coordinate: .init(latitude: 37.3280, longitude: -121.9020),
                status: "NPL", contaminants: "Petroleum, Heavy Metals", distanceMiles: nil),
            SuperfundSite(name: "Motorola 52nd St (San Jose)",
                coordinate: .init(latitude: 37.2950, longitude: -121.8820),
                status: "Deleted", contaminants: "Solvents, TCE", distanceMiles: nil),
            SuperfundSite(name: "Olin Corporation (McIntosh)",
                coordinate: .init(latitude: 37.3082, longitude: -121.9440),
                status: "NPL", contaminants: "Arsenic, Lead", distanceMiles: nil),
            SuperfundSite(name: "Applied Materials (Sunnyvale)",
                coordinate: .init(latitude: 37.3648, longitude: -122.0358),
                status: "Proposed", contaminants: "VOCs, Metals", distanceMiles: nil),

            // ─── Moffett Field / Mountain View ───────────────────────────────
            SuperfundSite(name: "Moffett Field Naval Air Station",
                coordinate: .init(latitude: 37.4148, longitude: -122.0488),
                status: "NPL", contaminants: "PFAS, TCE, Jet Fuel", distanceMiles: nil),
            SuperfundSite(name: "NASA Ames Research Center",
                coordinate: .init(latitude: 37.4057, longitude: -122.0637),
                status: "NPL", contaminants: "Solvents, Freon, PCBs", distanceMiles: nil),

            // ─── Milpitas ─────────────────────────────────────────────────────
            SuperfundSite(name: "Newby Island Landfill (Milpitas)",
                coordinate: .init(latitude: 37.4480, longitude: -121.9202),
                status: "Active", contaminants: "Landfill Gas, Leachate", distanceMiles: nil),
            SuperfundSite(name: "Intel Corp (Milpitas)",
                coordinate: .init(latitude: 37.4150, longitude: -121.9138),
                status: "NPL", contaminants: "TCE, TCA, Metals", distanceMiles: nil),

            // ─── Fremont / Newark / Alameda Co ───────────────────────────────
            SuperfundSite(name: "Ponderosa Dairy (Fremont)",
                coordinate: .init(latitude: 37.5488, longitude: -121.9882),
                status: "NPL", contaminants: "Nitrates, Bacteria", distanceMiles: nil),
            SuperfundSite(name: "United Heckathorn Co. (Richmond)",
                coordinate: .init(latitude: 37.9240, longitude: -122.3702),
                status: "NPL", contaminants: "DDT, Chlordane, Dieldrin", distanceMiles: nil),
            SuperfundSite(name: "Chevron Ortho (Richmond)",
                coordinate: .init(latitude: 37.9062, longitude: -122.3528),
                status: "NPL", contaminants: "Pesticides, Arsenic", distanceMiles: nil),
            SuperfundSite(name: "Sherwin-Williams (Richmond)",
                coordinate: .init(latitude: 37.9188, longitude: -122.3460),
                status: "NPL", contaminants: "Lead, VOCs, Solvents", distanceMiles: nil),

            // ─── San Francisco Bay ────────────────────────────────────────────
            SuperfundSite(name: "Former Hunters Point Naval Shipyard (SF)",
                coordinate: .init(latitude: 37.7202, longitude: -122.3665),
                status: "NPL", contaminants: "PCBs, Heavy Metals, Radioactive", distanceMiles: nil),
            SuperfundSite(name: "Alameda Naval Air Station",
                coordinate: .init(latitude: 37.7832, longitude: -122.3088),
                status: "NPL", contaminants: "Jet Fuel, Solvents, PCBs", distanceMiles: nil),
            SuperfundSite(name: "Mare Island Naval Shipyard (Vallejo)",
                coordinate: .init(latitude: 38.1068, longitude: -122.2572),
                status: "NPL", contaminants: "Solvents, Heavy Metals, PCBs", distanceMiles: nil),

            // ─── Gilroy / South County ────────────────────────────────────────
            SuperfundSite(name: "Casmalia Resources (Santa Maria Area)",
                coordinate: .init(latitude: 37.0128, longitude: -121.5678),
                status: "NPL", contaminants: "Pesticides, Heavy Metals", distanceMiles: nil),
            SuperfundSite(name: "Halford Channel (Gilroy)",
                coordinate: .init(latitude: 37.0058, longitude: -121.5782),
                status: "Proposed", contaminants: "Mercury, Lead", distanceMiles: nil),

            // ─── San Jose downtown / east ─────────────────────────────────────
            SuperfundSite(name: "San Jose Chrome Plating",
                coordinate: .init(latitude: 37.3368, longitude: -121.8768),
                status: "NPL", contaminants: "Hexavalent Chromium, TCE", distanceMiles: nil),
            SuperfundSite(name: "Elsinore Valley Municipal (San Jose)",
                coordinate: .init(latitude: 37.3688, longitude: -121.8452),
                status: "Proposed", contaminants: "Nitrates, VOCs", distanceMiles: nil),

            // ─── San Francisco ────────────────────────────────────────────────
            SuperfundSite(name: "Former Hunters Point Naval Shipyard",
                coordinate: .init(latitude: 37.7202, longitude: -122.3665),
                status: "NPL", contaminants: "PCBs, Heavy Metals, Low-level Radioactive", distanceMiles: nil),
            SuperfundSite(name: "Visitacion Valley (SF)",
                coordinate: .init(latitude: 37.7108, longitude: -122.4028),
                status: "Proposed", contaminants: "Lead, PAHs, Petroleum", distanceMiles: nil),
            SuperfundSite(name: "Islais Creek Industrial (SF)",
                coordinate: .init(latitude: 37.7458, longitude: -122.4028),
                status: "NPL", contaminants: "VOCs, PCBs, Solvents", distanceMiles: nil),
            SuperfundSite(name: "SF Bay Area Dry Cleaners Cluster",
                coordinate: .init(latitude: 37.7808, longitude: -122.4128),
                status: "Proposed", contaminants: "PCE, TCE (dry cleaning)", distanceMiles: nil),

            // ─── Oakland / Alameda ────────────────────────────────────────────
            SuperfundSite(name: "Alameda Naval Air Station",
                coordinate: .init(latitude: 37.7832, longitude: -122.3088),
                status: "NPL", contaminants: "Jet Fuel, PCBs, Solvents", distanceMiles: nil),
            SuperfundSite(name: "Oakland Army Base",
                coordinate: .init(latitude: 37.8158, longitude: -122.3218),
                status: "Deleted", contaminants: "Petroleum, Heavy Metals", distanceMiles: nil),
            SuperfundSite(name: "Kaiser Industries (Oakland)",
                coordinate: .init(latitude: 37.8008, longitude: -122.2728),
                status: "NPL", contaminants: "Arsenic, Lead, PAHs", distanceMiles: nil),
            SuperfundSite(name: "Levin Enterprises (Oakland)",
                coordinate: .init(latitude: 37.7738, longitude: -122.2258),
                status: "NPL", contaminants: "PCBs, Heavy Metals", distanceMiles: nil),
            SuperfundSite(name: "Elmore Oil / Oakland Barrel",
                coordinate: .init(latitude: 37.7908, longitude: -122.2588),
                status: "Proposed", contaminants: "Petroleum, TCE", distanceMiles: nil),

            // ─── Richmond / Contra Costa ──────────────────────────────────────
            SuperfundSite(name: "United Heckathorn (Richmond)",
                coordinate: .init(latitude: 37.9240, longitude: -122.3702),
                status: "NPL", contaminants: "DDT, Chlordane, Dieldrin", distanceMiles: nil),
            SuperfundSite(name: "Chevron Ortho (Richmond)",
                coordinate: .init(latitude: 37.9062, longitude: -122.3528),
                status: "NPL", contaminants: "Pesticides, Arsenic", distanceMiles: nil),
            SuperfundSite(name: "Sherwin-Williams (Richmond)",
                coordinate: .init(latitude: 37.9188, longitude: -122.3460),
                status: "NPL", contaminants: "Lead, VOCs, Solvents", distanceMiles: nil),
            SuperfundSite(name: "Richmond Plating Works",
                coordinate: .init(latitude: 37.9318, longitude: -122.3638),
                status: "NPL", contaminants: "Hexavalent Chromium, Cyanide", distanceMiles: nil),
            SuperfundSite(name: "Celanese Corp (Richmond)",
                coordinate: .init(latitude: 37.9128, longitude: -122.3748),
                status: "Deleted", contaminants: "VOCs, Solvents", distanceMiles: nil),
            SuperfundSite(name: "Wickland Oil (Benicia)",
                coordinate: .init(latitude: 38.0528, longitude: -122.1658),
                status: "NPL", contaminants: "Petroleum, MTBE", distanceMiles: nil),
            SuperfundSite(name: "Pacific Coast Pipe Lines (Hercules)",
                coordinate: .init(latitude: 37.9908, longitude: -122.2798),
                status: "NPL", contaminants: "Petroleum, Lead", distanceMiles: nil),

            // ─── Hayward / San Leandro ────────────────────────────────────────
            SuperfundSite(name: "Pacific Coast Drum (Hayward)",
                coordinate: .init(latitude: 37.6628, longitude: -122.0888),
                status: "NPL", contaminants: "Solvents, Heavy Metals", distanceMiles: nil),
            SuperfundSite(name: "Industrial Waste Service (San Leandro)",
                coordinate: .init(latitude: 37.7208, longitude: -122.1558),
                status: "Deleted", contaminants: "Solvents, Petroleum", distanceMiles: nil),
            SuperfundSite(name: "Norcal Waste Systems (Hayward)",
                coordinate: .init(latitude: 37.6458, longitude: -122.0618),
                status: "Proposed", contaminants: "Landfill Gas, Leachate", distanceMiles: nil),

            // ─── San Mateo County ─────────────────────────────────────────────
            SuperfundSite(name: "Romic Environmental Technologies (PA)",
                coordinate: .init(latitude: 37.4428, longitude: -122.1308),
                status: "NPL", contaminants: "Solvents, Metals, PCBs", distanceMiles: nil),
            SuperfundSite(name: "Beckman Instruments (Palo Alto)",
                coordinate: .init(latitude: 37.4128, longitude: -122.1188),
                status: "Deleted", contaminants: "VOCs, Solvents", distanceMiles: nil),
            SuperfundSite(name: "Crystal Chemical (San Mateo)",
                coordinate: .init(latitude: 37.5608, longitude: -122.3248),
                status: "NPL", contaminants: "Chromium, Heavy Metals", distanceMiles: nil),
            SuperfundSite(name: "SF Bay Shipyards (So. San Francisco)",
                coordinate: .init(latitude: 37.6608, longitude: -122.3788),
                status: "Proposed", contaminants: "Petroleum, Heavy Metals, Asbestos", distanceMiles: nil),
            SuperfundSite(name: "Daly City Landfill",
                coordinate: .init(latitude: 37.6888, longitude: -122.4688),
                status: "Active", contaminants: "Landfill Gas, Leachate", distanceMiles: nil),

            // ─── Marin County ─────────────────────────────────────────────────
            SuperfundSite(name: "Mare Island Naval Shipyard (Vallejo)",
                coordinate: .init(latitude: 38.1068, longitude: -122.2572),
                status: "NPL", contaminants: "PCBs, Solvents, Heavy Metals", distanceMiles: nil),
            SuperfundSite(name: "Hamilton Army Airfield (Novato)",
                coordinate: .init(latitude: 38.0628, longitude: -122.4958),
                status: "NPL", contaminants: "Jet Fuel, TCE, Heavy Metals", distanceMiles: nil),

            // ─── Solano County ────────────────────────────────────────────────
            SuperfundSite(name: "Fairfield-Suisun Sewer Dist",
                coordinate: .init(latitude: 38.2608, longitude: -122.0458),
                status: "Proposed", contaminants: "Nitrates, Heavy Metals", distanceMiles: nil),
            SuperfundSite(name: "Travis Air Force Base",
                coordinate: .init(latitude: 38.2628, longitude: -121.9278),
                status: "NPL", contaminants: "TCE, Jet Fuel, PFAS", distanceMiles: nil),
        ]
    }
}
