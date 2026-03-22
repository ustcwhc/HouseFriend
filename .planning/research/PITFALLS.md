# Pitfalls Research

**Domain:** Bay Area neighborhood data iOS app — milestone adding real crime/school API data, dark mode, share features, saved addresses, App Store submission
**Researched:** 2026-03-22
**Confidence:** MEDIUM — government API schema behavior, MapKit rendering details, and App Store review criteria verified via official sources and community; dark mode overlay specifics inferred from framework behavior and community reports.

---

## Critical Pitfalls

### Pitfall 1: Socrata Default Row Limit Silently Truncates Crime Data

**What goes wrong:**
SF Open Data (`data.sfgov.org`) and Oakland CrimeWatch (`data.oaklandca.gov/ppgh-7dqv`) both use the Socrata SODA API. Without an explicit `$limit` parameter, every query returns at most 1,000 rows. The app's current `CrimeService.fetchNear()` already queries SF Open Data — if it does not paginate, it will pull at most 1,000 of potentially tens of thousands of recent incidents, producing an artificially sparse heatmap that looks correct but misses the majority of events.

**Why it happens:**
The Socrata default is deliberately conservative. Developers assume the API returns "all results" without reading pagination docs. The response has no indication truncation occurred — it simply ends at row 1,000.

**How to avoid:**
Always pass `$limit` and `$offset` explicitly. For a spatial query (e.g., incidents within a bounding box), use a `$where` clause filtering by `latitude`/`longitude` or the `point` field so you can bound the result set to a manageable size without needing full pagination. For the crime heatmap, query the last 90 days within the map viewport only, using:
```
$where=date > '[ISO_DATE]' AND within_box(point, maxLat, minLon, minLat, maxLon)&$limit=5000
```
Set `$limit` to a safe ceiling (5,000–10,000) and add a `$order=date DESC` so the most recent incidents are never cut off.

**Warning signs:**
- Crime heatmap looks unusually uniform or sparse in dense neighborhoods
- Incident count in debug logs caps at exactly 1,000
- Removing the date filter doesn't change the result count

**Phase to address:**
Real crime data integration phase (the phase that replaces the Gaussian model with live SF Open Data and Oakland CrimeWatch).

---

### Pitfall 2: Unauthenticated Socrata Requests Throttled by Shared IP Pool

**What goes wrong:**
Requests to `data.sfgov.org` and `data.oaklandca.gov` without a Socrata application token are drawn from a shared IP pool. Throttling is not published as a hard number, but Socrata documentation states unauthenticated requests are "subjected to a much lower throttling limit." On devices sharing a NAT (office, café, open house), multiple users hitting the same city endpoint will collectively exhaust the pool, causing `429 Too Many Requests`. The existing `CrimeService` has no rate limiter on the client side — this is already flagged in CONCERNS.md as a known security/reliability risk.

**Why it happens:**
Open APIs feel "free and unlimited." The token registration step is easy to skip. No throttling manifests during single-developer testing where request volume is low.

**How to avoid:**
Register a free Socrata app token at `https://data.sfgov.org/profile/app_tokens` (no authentication required, just an email). Pass it in the `X-App-Token` HTTP header. Token-authenticated requests are not throttled under normal usage. Also add a minimum interval guard (matching the Overpass debounce pattern already in `NoiseService`) to prevent rapid repeated calls.

**Warning signs:**
- HTTP 429 errors appearing in console during testing in a shared network
- Crime layer shows error banner intermittently but not consistently
- Errors correlated with time-of-day or location (busy networks)

**Phase to address:**
Real crime data integration phase. Must be resolved before TestFlight distribution where multiple testers hit the same endpoints.

---

### Pitfall 3: Government Dataset Schema Changes Break Parsing Silently

**What goes wrong:**
City open data portals rename or deprecate columns without notice. The SFPD dataset (`wg3w-h783`) has a precedent: the pre-2018 historical dataset and the 2018-present dataset use different column names — integrations built against the historical dataset broke when SFPD migrated. If the app hard-codes column names like `"latitude"`, `"longitude"`, `"incident_category"`, and those names change, the JSON parser returns empty values and the app silently falls back to mock data. The existing `CrimeService` already silently falls back to mock data on parse failure — meaning a schema change would go unnoticed by users and developers alike.

**Why it happens:**
City IT departments treat column renames as internal schema management, not breaking API changes. There is no versioned contract or deprecation notice sent to consumers. The SODA API does not surface schema mismatches as HTTP errors.

**How to avoid:**
- Add a validation step that checks for required fields after parsing: if `latitude` and `incident_category` are both absent from the first record, log a loud warning and surface a user-visible "data source may have changed" banner rather than falling back silently.
- Prefer the `point` geo-column (a structured `{latitude, longitude}` object) over flat `latitude`/`longitude` fields — the geo-column is less likely to be renamed because it is the primary spatial index.
- Pin the Socrata API endpoint version: use `/resource/wg3w-h783.json` not `/resource/wg3w-h783.csv` to preserve type information.

**Warning signs:**
- Crime layer always shows fallback/mock data even when network is healthy
- `crimeValue()` returns the Gaussian estimate even after API integration
- Parse returns an empty array on a network-successful response

**Phase to address:**
Real crime data integration phase. The validation/alerting guard should be part of the initial API integration, not a follow-up.

---

### Pitfall 4: MKMapSnapshotter Does Not Capture Custom Overlays

**What goes wrong:**
`MKMapSnapshotter` is the natural choice for generating a shareable map image — it is async, returns a `UIImage`, and supports region/size configuration. However, it is a fundamental limitation of the framework that `MKMapSnapshotter` renders base map tiles only. It does not render any custom overlays (`MKTileOverlay`, `MKPolyline`, `NoiseSmokeRenderer`) or any annotations. This is a documented, long-standing limitation (Apple Radar 15390104, unfixed). For HouseFriend, a share image without the crime heatmap, noise smoke, or school pins is nearly useless — it is just a plain map.

**Why it happens:**
The documentation says "creates an image of a map" but does not prominently warn that custom overlays are excluded. Developers discover this only after implementing the full share flow.

**How to avoid:**
Use `drawHierarchy(in:afterScreenUpdates:true)` on the live `MKMapView` instance instead. This captures the actual rendered screen including all overlays and annotations exactly as the user sees them. Wrap it in `UIGraphicsImageRenderer` for proper display scale handling:
```swift
let renderer = UIGraphicsImageRenderer(bounds: mapView.bounds)
let image = renderer.image { _ in
    mapView.drawHierarchy(in: mapView.bounds, afterScreenUpdates: true)
}
```
The key requirement: this must run on the main thread, and `afterScreenUpdates: true` must be passed to ensure overlay render passes have completed. The resulting image can then be composited with a score card view using a second `UIGraphicsImageRenderer` pass.

**Warning signs:**
- Share image shows the base map but all colored overlays are absent
- `MKMapSnapshotter` completion handler returns quickly but image looks empty of app content
- Testing with noise layer active: no smoke effect visible in the output image

**Phase to address:**
Share feature implementation phase.

---

### Pitfall 5: Dark Mode Does Not Automatically Redraw Custom MKOverlayRenderers

**What goes wrong:**
When the user switches between light and dark mode, SwiftUI views update automatically via environment. `MKMapView` itself respects the system appearance and switches its base map style. However, custom `MKOverlayRenderer` subclasses (like `NoiseSmokeRenderer`) do not receive any automatic notification of the trait change. Their `draw(_:zoomScale:in:)` method is not called again. The overlay colors remain hard-coded to whatever was drawn at last render, leaving e.g. light-colored smoke overlays on a dark map base.

**Why it happens:**
`MKOverlayRenderer` inherits from `NSObject`, not `UIView`. It does not participate in the `UITraitEnvironment` protocol chain that triggers `traitCollectionDidChange`. The renderer is only called when MapKit decides to re-render a tile — which it does not do solely because the appearance changed.

**How to avoid:**
Observe `UIApplication.didChangeStatusBarOrientationNotification` or, better, implement `traitCollectionDidChange` on the `UIViewRepresentable` coordinator (which is a UIKit object and does receive trait changes). When the trait changes, call `setNeedsDisplay()` on each active overlay renderer, forcing MapKit to re-render:
```swift
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
        mapView.overlays.forEach { overlay in
            if let renderer = mapView.renderer(for: overlay) {
                renderer.setNeedsDisplay()
            }
        }
    }
}
```
Additionally, in each renderer's `draw` method, query `UITraitCollection.current.userInterfaceStyle` (not a stored constant) to pick colors dynamically at draw time.

**Warning signs:**
- Switching to dark mode: base map goes dark but noise smoke remains white/light-colored
- Crime heatmap colors look washed out on dark backgrounds
- No color change in overlays until the user pans or zooms (which triggers a tile re-render)

**Phase to address:**
Dark mode support phase.

---

### Pitfall 6: App Store Rejection for Missing Privacy Policy URL

**What goes wrong:**
Apple requires a privacy policy URL in two places: (1) in App Store Connect metadata, and (2) accessible from within the app itself (typically in a Settings or About screen). Apps that access location data — which HouseFriend does — are scrutinized closely. A missing or inaccessible privacy policy is a hard rejection under guideline 5.1.1(i). The policy must explicitly state what location data is collected, how it is used, and that it is not shared with third parties (since HouseFriend has no backend). Missing either location causes an automatic rejection without further review of the app's functionality.

**Why it happens:**
Developers focus on the app itself and treat the privacy policy as a late-stage checklist item. App Store Connect's metadata form accepts submissions without the privacy policy URL but then rejects at review. "The app has no backend" is not a valid reason to omit a policy — the policy simply states "we do not collect or transmit your data."

**How to avoid:**
Create a minimal privacy policy (even a single-page hosted HTML file) before submitting. The policy must cover: (a) location data is used only locally to show neighborhood scores and is not transmitted, (b) no user accounts or personal data are stored, (c) crash data if any. Add an in-app link (Settings tab or About sheet) that opens the URL in `SFSafariViewController`. Put the same URL in App Store Connect under "Privacy Policy URL" before first submission.

**Warning signs:**
- App Store Connect submission form allows progress past metadata without a URL — do not interpret this as acceptance
- Pre-submission TestFlight review feedback requesting policy
- Review rejection with reason code 5.1.1

**Phase to address:**
App Store preparation phase. Must be completed before first submission attempt.

---

### Pitfall 7: Privacy Manifest (PrivacyInfo.xcprivacy) Missing or Incomplete

**What goes wrong:**
Since May 1, 2024, Apple requires all app submissions to include a `PrivacyInfo.xcprivacy` file declaring which "required reason APIs" the app uses and why. For HouseFriend, the relevant APIs are: `UserDefaults` (for saved addresses), file timestamps (if used), and system boot time (if used). Submissions without this manifest, or with an incomplete manifest, are rejected automatically by App Store Connect — not even reaching human review. Apple rejected 12% of Q1 2025 submissions for Privacy Manifest violations.

**Why it happens:**
The requirement was enforced starting mid-2024. Apps built before enforcement and not updated since may lack the file entirely. Xcode 15+ generates a template but does not auto-populate it with the correct reasons — developers must manually declare each API usage.

**How to avoid:**
Create `PrivacyInfo.xcprivacy` in Xcode (File > New > Privacy Manifest). For HouseFriend's zero-dependency stack, the required entries are likely only `NSPrivacyAccessedAPITypeUserDefaults` (if saved addresses use `UserDefaults`). Declare the approved reason code for each API (e.g., `CA92.1` — "accessing preferences from the same app"). Run the Xcode Privacy Report (Product > Archive > Distribute App) to see what the manifest will look like before submission.

**Warning signs:**
- App Store Connect upload succeeds but automated validation email lists missing privacy manifest
- Xcode 15/16 warning in build log about undeclared required reason APIs
- Submission rejection immediately after upload without reaching human review

**Phase to address:**
App Store preparation phase.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hard-coded fallback to mock crime data on any parse error | Hides API failures gracefully | Schema changes or rate limits go undetected; real data quality never improves | Never for a data-accuracy app — surface errors loudly |
| Querying only SF Open Data regardless of pin location | One endpoint to integrate | Crime scores for Oakland, San Jose, and all non-SF locations are Gaussian fiction | Acceptable only for SF-only alpha; not for Bay Area v1 |
| Using a fixed 1.8-second delay before score computation | Simple to write | Stale scores on slow networks; unnecessary delay on fast devices | Never — replace with `async/await` completion tracking |
| Hard-coding school ratings as Swift literals | Instant load, no API | Ratings drift from reality; school openings/closures not reflected | Acceptable for prototype; must be replaced before App Store submission |
| No `$limit`/`$offset` on Socrata queries | Simpler query string | Silent truncation at 1,000 rows, sparse heatmap | Never for a production data query |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| SF Open Data (Socrata) | Omitting `$limit` and assuming all data is returned | Always specify `$limit=5000` and a `$where` bounding box; add `$order=date DESC` |
| SF Open Data (Socrata) | Querying without an app token, getting IP-pool throttling | Register a free app token; pass it as `X-App-Token` header |
| Oakland CrimeWatch (`ppgh-7dqv`) | Assuming same schema as SF data | Oakland dataset columns differ; validate field names separately; Oakland returns last 90 days only |
| GreatSchools API | Expecting it to be free and keyless | GreatSchools API requires registration and has usage-based pricing after 15,000 calls; plan for CA Open Data (`data.ca.gov`) as the free alternative |
| CA School Dashboard (CDE) | Expecting a real-time query API | CDE publishes annual exports, not a live query API; download the CSV and bundle it, updating annually |
| `MKMapSnapshotter` | Expecting it to capture custom overlays | It captures base tiles only; use `drawHierarchy` on the live map view for a full capture |
| `UIActivityViewController` | Presenting from a background thread | Must be presented from the main thread; image generation can be async, but `present()` must be main-thread |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Fetching all crime incidents (no spatial filter) and storing in memory | Memory spike, slow parse, incomplete data due to 1,000-row cap | Always filter by bounding box and date window at the API level | At any usage — the cap hits immediately |
| `drawHierarchy` called before map tiles finish loading | Share image shows blank/grey tile areas | Wait for `mapViewDidFinishRenderingMap` delegate callback before triggering capture | On any network slower than LTE, or at high zoom levels |
| Generating score card image on main thread using `UIGraphicsImageRenderer` with complex drawing | UI freeze during share sheet setup | Move image generation to `Task { @MainActor }` and yield before presentation | As score card complexity grows |
| Calling `setNeedsDisplay()` on all overlays on every trait change | Unnecessary re-render of all 10 layers | Only call `setNeedsDisplay()` if `hasDifferentColorAppearance` is true | Visible jank if device flips appearance rapidly (e.g., in Settings) |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Embedding a Socrata app token as a plain string in Swift source | Token visible in binary; could be extracted and abused | Store token in a configuration file excluded from source control, or use a proxy; for a free-tier keyless token the risk is low but still better practice |
| Displaying crime data labeled as authoritative when it is 90-days-delayed government data | User relies on stale data for safety decisions | Always show the data freshness date (e.g., "Incidents: past 90 days, updated daily") next to crime scores |
| Not disclosing real data sources in privacy policy | App Store rejection; user trust | Privacy policy and in-app disclosure must name the specific endpoints used (DataSF, Oakland Open Data) |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Share image is the plain map without overlays | Shared image is meaningless without the data layers that make HouseFriend valuable | Capture with `drawHierarchy` to include all active overlays in the share image |
| Dark mode: overlays remain light-colored on dark map | Jarring visual inconsistency; overlays become unreadable against dark base | Force overlay redraw on trait change; use dynamic colors at draw time, not at init time |
| No data freshness label in neighborhood report | Users cannot tell if crime data is from last week or last year | Add a small "Data as of: [date]" label to the long-press report sheet |
| Crime scores shown for Oakland/San Jose with the same confidence as SF scores | Misleads users — Oakland scores are Gaussian fiction, not real data | Show a "Estimated" badge next to crime scores for locations outside SF until real multi-city data is integrated |
| App Store screenshots show layers that are not live data | If screenshots show a busy crime heatmap but the app shows Gaussian placeholders, reviewers may flag this as misleading metadata (guideline 2.3) | Use real data in screenshots, or add "Illustrative data" disclaimer; better: integrate real data before submission |

---

## "Looks Done But Isn't" Checklist

- [ ] **Crime API integration:** Verify the heatmap is rebuilding from fetched incident coordinates, not still using the Gaussian `crimeValue()` model — check by looking up an address in a known low-crime area and confirming the score drops.
- [ ] **Dark mode overlay rendering:** Switch system to dark mode while each layer is active; confirm all overlays update colors, not just the base map.
- [ ] **Share image:** Generate a share image with the crime heatmap and noise layer active; verify both appear in the exported `UIImage`.
- [ ] **Privacy policy:** Confirm the policy URL is accessible from inside the app (not only in App Store Connect) and opens without requiring a login.
- [ ] **PrivacyInfo.xcprivacy:** Run Xcode's Privacy Report before the first archive and confirm no undeclared required reason APIs.
- [ ] **Socrata app token:** Confirm the `X-App-Token` header is present in outgoing requests (use Charles Proxy or `URLProtocol` logging).
- [ ] **Oakland crime data:** Verify the app queries `data.oaklandca.gov` when the pin is in Oakland, not `data.sfgov.org`.
- [ ] **Row count sanity check:** Log the count of returned incidents; confirm it is well above 1,000 for a dense urban area query.
- [ ] **Score card composite:** Verify the share image composites both the map capture and the score card in a single image, not two separate items in the share sheet.
- [ ] **Saved addresses persistence:** Confirm saved addresses survive app termination and relaunch (not just held in `@State`).

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Silent 1,000-row truncation discovered post-launch | MEDIUM | Add `$limit` and `$where` to query; rebuild heatmap model; no user data lost |
| Socrata schema change breaks crime parsing | MEDIUM | Detect via monitoring; update field name mapping; redeploy; can be done in a patch update |
| App Store rejection for missing privacy policy | LOW | Draft and host policy (30 min); add in-app link (1 hour); resubmit; typical review turnaround 1–2 days |
| App Store rejection for missing PrivacyInfo.xcprivacy | LOW | Add file in Xcode (30 min); archive and resubmit; automated check passes within hours |
| Share image missing overlays (snapshotter used instead of drawHierarchy) | LOW | Replace `MKMapSnapshotter` call with `drawHierarchy` approach; one-session fix |
| Dark mode overlays not updating | LOW | Add `traitCollectionDidChange` handler to coordinator; add dynamic color resolution in each renderer's `draw` method; test all 10 layers |
| GreatSchools API found to be paid/unavailable | LOW | Pivot to CA Open Data annual CSV (`data.ca.gov`); bundle updated school data; no live API needed |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Socrata 1,000-row default truncation | Real crime data integration | Log row count for a downtown SF query; must exceed 1,000 |
| Unauthenticated Socrata throttling | Real crime data integration | Confirm `X-App-Token` header present in network logs |
| Government dataset schema changes | Real crime data integration | Add field-presence validation; verify with a real Oakland pin |
| MKMapSnapshotter missing overlays | Share feature implementation | Generate share image with noise + crime active; both must appear |
| Dark mode overlay not auto-redrawing | Dark mode support | Toggle system appearance with each layer active; all must redraw |
| Missing App Store privacy policy URL | App Store preparation | App Store Connect metadata check + in-app link verification |
| Missing PrivacyInfo.xcprivacy | App Store preparation | Xcode Privacy Report shows no undeclared APIs |
| Oakland crime data not integrated (all traffic to SF endpoint) | Real crime data integration | Network intercept confirms multi-city endpoint routing |
| `UIActivityViewController` presented off main thread | Share feature implementation | Test share on a device under simulated slow image generation |

---

## Sources

- [Socrata App Tokens — dev.socrata.com](https://dev.socrata.com/docs/app-tokens.html) — rate limit behavior, token registration
- [Socrata LIMIT clause — dev.socrata.com](https://dev.socrata.com/docs/queries/limit.html) — 1,000-row default, pagination pattern
- [SFPD Dataset Explainer — sfdigitalservices.gitbook.io](https://sfdigitalservices.gitbook.io/dataset-explainers/sfpd-incident-report-2018-to-present) — column schema, coordinate anonymization
- [Oakland CrimeWatch API — dev.socrata.com/foundry](https://dev.socrata.com/foundry/data.oaklandca.gov/ppgh-7dqv) — Oakland endpoint identifier
- [MKMapSnapshotter overlay limitation — openradar.appspot.com/15390104](http://openradar.appspot.com/15390104) — long-standing framework bug
- [NSHipster MKMapSnapshotter — nshipster.com](https://nshipster.com/mktileoverlay-mkmapsnapshotter-mkdirections/) — annotations-not-included behavior, Core Graphics workaround
- [Apple App Store Review Guidelines — developer.apple.com](https://developer.apple.com/app-store/review/guidelines/) — 5.1.1(i) privacy policy, 5.1.5 location, 4.2 minimum functionality
- [Privacy Manifest Files — developer.apple.com](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) — PrivacyInfo.xcprivacy requirements
- [Apple Privacy Manifest enforcement announcement — developer.apple.com/news](https://developer.apple.com/news/?id=pvszzano) — May 1, 2024 enforcement date
- [MKOverlayRenderer setNeedsDisplay bug — github.com/briancoyner/MKOverlayRendererBug](https://github.com/briancoyner/MKOverlayRendererBug) — setNeedsDisplay behavior on tile overlays
- [App Store rejection reasons 2025 — twinr.dev](https://twinr.dev/blogs/apple-app-store-rejection-reasons-2025/) — privacy policy and metadata rejection patterns
- [HouseFriend CONCERNS.md — .planning/codebase/CONCERNS.md] — existing known issues, specifically CrimeService always using SF endpoint, no rate limiting, fake school data

---

*Pitfalls research for: Bay Area neighborhood data iOS app — data integration, dark mode, share, App Store submission milestone*
*Researched: 2026-03-22*
