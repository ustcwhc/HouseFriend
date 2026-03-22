# Stack Research

**Domain:** Bay Area Neighborhood Data iOS App — Milestone 2 (Real Data + Polish)
**Researched:** 2026-03-22
**Confidence:** MEDIUM-HIGH (APIs verified via official sources; rate limits partially inferred)

---

## Recommended Stack

### 1. Crime Data APIs

#### Primary: SF Open Data — SFPD Incident Reports (Socrata SODA API)
**Confidence:** HIGH

| Property | Value |
|----------|-------|
| Dataset | Police Department Incident Reports 2018 to Present |
| Dataset ID | `wg3w-h783` |
| Base endpoint | `https://data.sfgov.org/resource/wg3w-h783.json` |
| Protocol | SODA v2.1 (JSON over HTTPS, no auth required) |
| Key fields | `latitude`, `longitude`, `incident_category`, `incident_date`, `incident_time`, `police_district`, `point` |
| Row limit default | 1,000 rows (override with `$limit=50000`) |
| Max rows per request | 50,000 |
| Geographic filter | `$where=within_circle(point,37.77,-122.41,3000)` — meters radius |
| Date filter | `$where=incident_date > '2023-01-01T00:00:00'` |

**Rate limits:**
- Anonymous (no token): shared IP pool, throttled aggressively — sufficient only for development
- App token (free registration at data.sfgov.org): effectively unlimited for non-abusive usage; Apple recommends using a token for any production app
- SODA3 (upcoming, 2025): will require an app token for all queries — register proactively

**Why this source:** Official SFPD data, updated daily, covers all SF neighborhoods, proven by civic tech community. The dataset IDs are stable and have been in use since 2018.

**App token registration:** https://data.sfgov.org/profile/app_tokens — free, takes 2 minutes.

**Example query (crimes last 90 days within 1km of a point):**
```
GET https://data.sfgov.org/resource/wg3w-h783.json
  ?$where=within_circle(point,37.785,-122.408,1000)
    AND incident_date > '2025-12-22T00:00:00'
  &$limit=1000
  &$$app_token=YOUR_TOKEN
```

---

#### Secondary: Oakland Crime Data (Socrata SODA API, same platform)
**Confidence:** MEDIUM

| Property | Value |
|----------|-------|
| Dataset | Crime Data 15X v2 |
| Dataset ID | `vmz9-uktm` |
| Base endpoint | `https://data.oaklandca.gov/resource/vmz9-uktm.json` |
| Alternate dataset | CrimeWatch Data (`ppgh-7dqv`) — daily-updated |
| Platform | data.oaklandca.gov (Socrata, identical SODA API) |
| Key fields | `latitude`, `longitude`, `crimetype`, `datetime` (verify schema at runtime) |
| Geographic filter | Same `within_circle` syntax as SF |

**Note:** Oakland's Socrata instance uses the same SODA API as SF. A single URLSession-based service can hit both with parameterized base URLs. Register a separate app token at data.oaklandca.gov.

---

#### What NOT to use for crime data

| Avoid | Why |
|-------|-----|
| SpotCrime / CrimeReports third-party APIs | Paid, terms restrict iOS embedding, adds a dependency |
| LexisNexis Community Crime Map API | Paid enterprise, not viable for free-tier v1 |
| Scraping SFPD Crime Dashboard (sanfranciscopolice.org) | HTML, fragile, violates ToS |
| Oakland Crime Watch (oaklandcrimewatch.com) | Third-party derivative, no API, no embedding rights |

---

### 2. School Rating Data

#### Recommended: CDE California Dashboard — Direct File Download (offline-bundled)
**Confidence:** HIGH (official source confirmed)

The California Department of Education publishes annual academic indicator data as downloadable XLSX/TXT files. There is no REST API — the correct approach is to bundle the data or fetch it once on first launch.

| Property | Value |
|----------|-------|
| ELA 2025 data | `https://www3.cde.ca.gov/researchfiles/cadashboard/eladownload2025.xlsx` |
| Math 2025 data | `https://www3.cde.ca.gov/researchfiles/cadashboard/mathdownload2025.xlsx` |
| Format | XLSX (tab-delimited TXT also available at same URL pattern with `.txt`) |
| Update cadence | Annual (published March each year) |
| School locations | `https://data.ca.gov/dataset/california-public-schools-2024-25` (ArcGIS GeoJSON) |
| Key fields | School name, county code, district code, school code (CDS), performance color (Red/Orange/Yellow/Green/Blue), change level |

**Integration strategy:**
1. Download the XLSX/TXT files once via a Python script at build time (same pattern as the existing `scripts/fetch_bayarea_roads.py`)
2. Filter to Bay Area counties (San Francisco, Alameda, Contra Costa, Marin, Napa, San Mateo, Santa Clara, Solano, Sonoma)
3. Emit a compact JSON: `[{name, lat, lon, cdsCode, elaColor, mathColor, gradesServed}]`
4. Bundle as a gzip'd JSON alongside `bayarea_roads.json.gz`
5. No API key needed, no rate limits, no runtime network dependency for school data

**Why offline over GreatSchools API:** GreatSchools charges $52.50–$97.50/month with only 3-band ratings ("below average/average/above average") on paid tiers — the 1-10 rating scale is enterprise-only. The CDE Dashboard provides the same color-coded performance levels for free with official state authority. PROJECT.md constraint: "All external APIs must be keyless or use free tiers."

---

#### Do NOT use: GreatSchools NearbySchools API
**Confidence:** HIGH

| Avoid | Why |
|-------|-----|
| GreatSchools NearbySchools API | $52.50+/month, requires API key, 1-10 ratings are enterprise-only (not on free tier), violates project constraint of free/keyless APIs |
| GreatSchools old v2 API | Registration-gated, appears largely deprecated for new signups |

---

### 3. iOS Dark Mode with MapKit

#### Recommended: `overrideUserInterfaceStyle` on `MKMapView` + SwiftUI `@Environment(\.colorScheme)`
**Confidence:** HIGH (native Apple pattern, no dependency)

**How it works for the existing HouseFriend architecture:**

HouseFriend uses `MKMapView` wrapped in `UIViewRepresentable` (`HFMapView.swift`). Dark mode requires two coordinated changes:

**A. Map tile appearance** — set `overrideUserInterfaceStyle` on the `MKMapView` instance to follow the system or a user override:

```swift
// In makeUIView or updateUIView inside HFMapView.swift
mapView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
// or to fully follow system:
mapView.overrideUserInterfaceStyle = .unspecified
```

**B. Map configuration (iOS 16+)** — use `MKStandardMapConfiguration` with `preferredConfiguration` to get the muted map style that works better with custom overlays in dark mode:

```swift
let config = MKStandardMapConfiguration(emphasisStyle: .muted)
mapView.preferredConfiguration = config
```

**C. SwiftUI layer** — all SwiftUI views respond automatically to `colorScheme` via `@Environment(\.colorScheme)`. Custom overlay colors (sidebar, score cards, bottom sheets) need to use semantic colors (`Color(.systemBackground)`, `Color(.label)`) rather than hardcoded values.

**D. Trait change detection** — in the `UIViewRepresentable` coordinator, monitor trait changes to update the map:

```swift
// In Coordinator (inherits from NSObject)
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
        // notify parent via callback to update map config
    }
}
```

**iOS version requirement:** `overrideUserInterfaceStyle` available iOS 13+. `preferredConfiguration` available iOS 16+. Both are within the project's iOS 17+ deployment target.

**Why NOT a third-party dark theme library:** The project has zero third-party dependencies. Native `overrideUserInterfaceStyle` and semantic colors are the correct iOS-native solution.

---

### 4. Share Feature — Screenshot + Score Card Generation

#### Recommended: `UIGraphicsImageRenderer` + `UIActivityViewController`
**Confidence:** HIGH (standard Apple API, iOS 10+, no dependency)

**Screenshot of map + score card:**

```swift
// Renders any UIView (or UIHostingController-hosted SwiftUI view) to UIImage
let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
let image = renderer.image { ctx in
    view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
}
```

**Compositing the score card:**
Build the share card as a SwiftUI `View`, host it in a `UIHostingController`, set its view bounds to the target size (e.g., 1170×2532 for iPhone 14), then render with `UIGraphicsImageRenderer`. This keeps the card layout in SwiftUI while using UIKit for the capture.

**Presenting the share sheet:**
```swift
let activityVC = UIActivityViewController(
    activityItems: [image, "Check out this neighborhood on HouseFriend"],
    applicationActivities: nil
)
// Present from the root view controller
UIApplication.shared.connectedScenes
    .compactMap { $0 as? UIWindowScene }
    .first?.windows.first?.rootViewController?
    .present(activityVC, animated: true)
```

**Privacy manifest requirement:** If users can save the image to Photos via the share sheet, add `NSPhotoLibraryAddUsageDescription` to `Info.plist`. The share sheet itself does not require this — only the explicit "Save Image" action within it. Recommend adding the key preemptively with a clear description.

**What NOT to use:**

| Avoid | Why |
|-------|-----|
| `UIScreen.snapshotView` / `UIScreen.main.bounds` | Deprecated in iOS 16, broken on multi-scene on iOS 17+ |
| Third-party screenshot libraries | Violates zero-dependency constraint |
| CloudKit for share delivery | Requires auth and server — out of scope per PROJECT.md |

---

### 5. Saved/Favorited Addresses

#### Recommended: `UserDefaults` with `Codable`
**Confidence:** HIGH (standard Apple pattern for lightweight persistent preferences)

**Why UserDefaults (not CoreData, not SwiftData):**
- Saved addresses are small (<100 items, <100KB total)
- No relational queries needed — just an ordered array
- No migration logic needed — Codable handles schema evolution
- Zero dependencies, already used in similar iOS patterns

**Implementation pattern:**

```swift
struct SavedAddress: Codable, Identifiable {
    let id: UUID
    let title: String          // display name from MKLocalSearchCompletion
    let subtitle: String       // e.g., "San Francisco, CA"
    let coordinate: CLLocationCoordinate2D  // stored as lat/lon Doubles
    let savedAt: Date
}

// Encode/decode via JSONEncoder — UserDefaults stores as Data
extension UserDefaults {
    func savedAddresses() -> [SavedAddress] { ... }
    func save(_ addresses: [SavedAddress]) { ... }
}
```

**Privacy manifest:** `UserDefaults` is a Required Reason API. HouseFriend must declare it in `PrivacyInfo.xcprivacy` with reason `CA92.1` (app functionality — storing user preferences). See App Store Submission section below.

**Storage limit:** Apple's informal guidance is ~512KB max in UserDefaults. A typical saved address is ~200 bytes encoded; 100 addresses = ~20KB. No practical limit concern.

---

### 6. App Store Submission — Requirements and Tools

#### A. PrivacyInfo.xcprivacy (Privacy Manifest)
**Confidence:** HIGH — mandatory since May 1, 2024

Every app must include a `PrivacyInfo.xcprivacy` file (a property list). HouseFriend has no third-party SDKs, so only app-level declarations are needed.

**Required declarations for HouseFriend:**

| API / Data | Declaration Type | Reason Code |
|-----------|-----------------|-------------|
| `UserDefaults` | Required Reason API | `CA92.1` (read/write user preferences) |
| `CoreLocation` / precise GPS | Data type: Precise Location | Purpose: App Functionality |
| No data collected or shared with third parties | NSPrivacyCollectedDataTypes: [] | N/A |
| NSPrivacyTracking: false | Not used for cross-app tracking | N/A |

**File location:** `HouseFriend/PrivacyInfo.xcprivacy` — Xcode 16's auto-sync will add it to the target automatically when placed in the source directory.

**Note:** File timestamp APIs (stat, etc.) and disk space APIs are also on the required reasons list. Audit final code before submission.

---

#### B. App Store Connect — Metadata
**Confidence:** HIGH

| Asset | Requirement | Notes |
|-------|-------------|-------|
| App icon | 1024×1024 PNG, no alpha, no rounding | Single asset; Xcode generates all sizes via asset catalog |
| Screenshots | 6.9" (1320×2868) OR 6.5" (1242×2688) — one set required | Apple auto-scales to other sizes; provide 6.9" for iPhone 16 Pro Max |
| App Preview video | Optional, max 30s, 1080×1920 | Not required |
| Privacy policy URL | Required for all apps | Must be publicly accessible URL — host on GitHub Pages or similar |
| Support URL | Required | Can be same as privacy policy page |
| Age rating | Updated age rating questionnaire required by Jan 31, 2026 | New system: 4+, 13+, 16+, 18+ |
| Export compliance | "Does app use encryption beyond standard OS?" | Answer NO for HouseFriend (no custom crypto); HTTPS is exempt |

---

#### C. SDK Requirement Timeline
**Confidence:** HIGH — sourced from developer.apple.com/news/upcoming-requirements

| Deadline | Requirement |
|----------|-------------|
| Now (active since April 24, 2025) | Must build with Xcode 16 + iOS 18 SDK |
| January 31, 2026 | Update age rating questionnaire in App Store Connect |
| April 28, 2026 | Must build with Xcode 26 + iOS 26 SDK |

**Implication for HouseFriend:** Current setup (Xcode 16.4, iOS 18.5 SDK per STACK.md) meets the active requirement. Xcode 26 requirement hits April 2026 — update before then.

---

#### D. Privacy Nutrition Labels (App Store Connect)
**Confidence:** HIGH

HouseFriend collects:
- **Precise Location** — used for App Functionality (centering map on user), NOT linked to identity, NOT used for tracking
- No other data collected (all neighborhood data is public, not user-generated)

Labels to set:
- Location → Precise Location → App Functionality → Not linked to you

---

#### E. No Additional Tools Required

| Tool | Status | Notes |
|------|--------|-------|
| App Store Connect | Use existing Apple Developer account (T539CYBWJW) | No new accounts needed |
| Fastlane | NOT recommended | Zero-dependency project; manual submission via Xcode Organizer is simpler |
| Transporter | Optional | Alternative to Xcode Organizer for IPA upload |
| TestFlight | Recommended for internal beta | Free, built into App Store Connect |

---

## Version Compatibility Summary

| Component | Version | iOS Requirement | Notes |
|-----------|---------|-----------------|-------|
| SODA API (SF/Oakland) | v2.1 | None — REST/URLSession | iOS 17+ foundation |
| CDE Dashboard data | 2025 annual | None — bundled JSON | Build-time fetch via Python script |
| `overrideUserInterfaceStyle` | iOS 13+ | iOS 13+ | Project target is iOS 17+, fully compatible |
| `preferredConfiguration` | iOS 16+ | iOS 16+ | Project target is iOS 17+, fully compatible |
| `UIGraphicsImageRenderer` | iOS 10+ | iOS 10+ | Stable, no changes |
| `UIActivityViewController` | iOS 6+ | iOS 6+ | Stable, no changes |
| `UserDefaults` + `Codable` | iOS 8+ | iOS 8+ | `JSONEncoder` iOS 7+ |
| `PrivacyInfo.xcprivacy` | Xcode 15+ | App Store requirement | Xcode 16 supports it natively |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not Alternative |
|----------|-------------|-------------|---------------------|
| School ratings | CDE Dashboard bundled JSON | GreatSchools API | Paid ($52.50/mo+), API key required, 1-10 ratings enterprise-only — violates project constraints |
| School ratings | CDE Dashboard bundled JSON | NCES Common Core of Data API | Location data only, no performance ratings |
| Crime data | SF Open Data SODA | SpotCrime API | Paid, adds dependency, no keyless tier |
| Crime data | SF Open Data SODA | Manual CSV bundle | 50MB+ for full Bay Area, stale immediately |
| Share feature | UIGraphicsImageRenderer | SwiftUI `.snapshot()` (custom) | Not an Apple API — all implementations are UIKit under the hood anyway |
| Saved addresses | UserDefaults + Codable | CoreData | Massive overkill for a flat list of addresses |
| Saved addresses | UserDefaults + Codable | SwiftData | iOS 17+ only (matches target) but adds framework overhead for a simple use case |
| Saved addresses | UserDefaults + Codable | Files in Documents directory | More complex for simple key-value storage |
| Dark mode | `overrideUserInterfaceStyle` | Third-party theme library | Violates zero-dependency constraint |

---

## Sources

- [SF Open Data SFPD Incident Reports dataset](https://data.sfgov.org/Public-Safety/Police-Department-Incident-Reports-2018-to-Present/wg3w-h783) — Dataset ID `wg3w-h783` confirmed MEDIUM confidence (portal JS-heavy, dataset ID via community references)
- [Oakland Open Data CrimeWatch](https://data.oaklandca.gov/Public-Safety/CrimeWatch-Data/ppgh-7dqv) — Dataset ID `ppgh-7dqv`, Crime Data 15X v2 `vmz9-uktm` MEDIUM confidence
- [Socrata SODA API — Getting Started](https://dev.socrata.com/consumers/getting-started.html) — 50,000 row max, `$limit`/`$offset` pagination HIGH confidence
- [Socrata App Tokens](https://dev.socrata.com/docs/app-tokens.html) — app tokens free, no throttling unless abusive HIGH confidence
- [Socrata `within_circle` function](https://dev.socrata.com/docs/functions/within_circle.html) — geographic filter syntax HIGH confidence
- [CDE Academic Indicators Download Page](https://www.cde.ca.gov/ta/ac/cm/acaddatafiles.asp) — XLSX files with direct URLs confirmed HIGH confidence
- CDE ELA 2025 direct URL: `https://www3.cde.ca.gov/researchfiles/cadashboard/eladownload2025.xlsx` HIGH confidence (from official CDE page)
- [California Public Schools 2024-25 dataset](https://data.ca.gov/dataset/california-public-schools-2024-25) — ArcGIS GeoJSON, school locations HIGH confidence
- [GreatSchools NearbySchools API pricing](https://www.greatschools.org/solutions/k12-data-solutions/nearbyschools-api) — $52.50/mo confirmed, 1-10 ratings enterprise-only HIGH confidence
- [Apple Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/) — Xcode 26 deadline April 28, 2026; age rating Jan 31, 2026 HIGH confidence
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) — nutrition label categories HIGH confidence
- [Apple Privacy Manifest (news)](https://developer.apple.com/news/?id=3d8a9yyh) — mandatory since May 1, 2024 HIGH confidence
- [Required Reason APIs — UserDefaults, file timestamp, disk space](https://mszpro.com/itms-91053-missing-api-declaration-for-accessing-userdefaults-timestamps-other-apis/) — ITMS-91053 error explained MEDIUM confidence (third-party, matches Apple docs)
- [UIActivityViewController share pattern](https://medium.com/practical-coding/share-to-social-media-on-ios-with-uiactivityviewcontroller-bc5d0559d3db) — NSPhotoLibraryAddUsageDescription required for save-to-photos LOW confidence (training data + search result, verify in Apple docs)
- `overrideUserInterfaceStyle` for MKMapView — MEDIUM confidence (pattern confirmed by multiple Swift community sources, not fetched from official docs due to JS-required Apple docs pages)
- `MKStandardMapConfiguration.preferredConfiguration` iOS 16+ — MEDIUM confidence (confirmed by community articles and WWDC 2022 notes)

---

*Stack research for: HouseFriend — Milestone 2 (Real Data + Polish)*
*Researched: 2026-03-22*
