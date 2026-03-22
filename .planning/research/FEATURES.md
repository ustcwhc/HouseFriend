# Feature Research

**Domain:** Neighborhood safety / real estate data iOS app
**Researched:** 2026-03-22
**Confidence:** MEDIUM-HIGH (App Store patterns HIGH; crime display ethics MEDIUM; share card specifics LOW from direct competitors)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or untrustworthy.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Real crime data (not synthetic) | Users distrust a "safety" app with placeholder data; Zillow, Redfin, Trulia all use real crime feeds | MEDIUM | SF Open Data and Oakland Crime API are keyless; replace Gaussian model. Display incidents as heatmap or density, not individual dots (avoids fear-mongering stigma) |
| School ratings displayed on map | Every competing real estate app (Zillow, Redfin, Homes.com) shows nearby schools with GreatSchools 1–10 scores on listing detail | MEDIUM | CA School Dashboard is the state-official source; GreatSchools API requires a free key. Show school pins at zoom ≥ ~13; tap pin for name + rating + type (elementary/middle/high) |
| Dark mode support | iOS system dark mode is a baseline expectation since iOS 13; absence feels like a bug | MEDIUM | MKMapView itself adapts automatically. Challenge is custom overlay colors: heatmap tiles, smoke renderer, and sidebar buttons need `UIUserInterfaceStyle`-aware color sets. Use asset catalog semantic colors |
| Layer loading spinners on all layers | Noise layer already has one; others don't. Users interpret missing spinner as app freeze | LOW | All 10 layers need consistent loading state. Pattern is: toggle ON → show spinner → hide on completion |
| Descriptive text per layer in report | A score of "C" with no context is meaningless; users expect "What does this mean?" | LOW | 1–2 sentence interpretation per grade per layer, e.g., "Crime: C — Above-average incident density for this ZIP. Consider reviewing recent reports." |
| Privacy policy accessible from app | Apple App Store requires a privacy policy URL inside the app, not just in App Store Connect | LOW | Single Settings or About screen with a `Link` to hosted privacy policy URL. Required for App Store submission. HouseFriend collects no user data, making this a short/simple policy |
| App icon + App Store screenshots | Cannot submit without them; screenshots drive conversion | LOW-MEDIUM | Needs 6.7" iPhone screenshots (required), 5.5" (required), optionally iPad. Show the map in action with layers on, neighborhood report card open |

### Differentiators (Competitive Advantage)

Features that set HouseFriend apart. Zillow/Redfin show single-dimension data; HouseFriend's 10-layer composite scoring is the moat.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Shareable neighborhood score card | "Look at the score I got for this neighborhood" — viral loop for house hunters sharing with partners/family; no competitor generates a branded composite score image | MEDIUM | Render a SwiftUI view offscreen to `UIGraphicsImageRenderer`, then pass UIImage to `UIActivityViewController`. Card should show: address, map thumbnail, per-layer grades, overall score, app branding. SwiftUI's `ImageRenderer` (iOS 16+) is the cleanest path |
| Saved / favorited addresses | Users evaluating multiple neighborhoods return to compare; favorites enable comparison over time without re-searching | LOW-MEDIUM | Persist via `UserDefaults` or a simple JSON file in Documents directory. No backend needed. UI: star button in address search result, separate "Saved" list accessible from toolbar. Show saved address pins on map in a distinct color |
| 10-layer composite scoring (existing) | No competitor shows crime + earthquake + fire + schools + air quality + noise + electric lines in a single interface | — | Already built; the differentiator is real. Protect it by keeping the score methodology transparent in the report |
| Neighborhood report with A–F grades per layer (existing) | Translates raw data into actionable grades; users don't need to interpret density values | — | Existing. Enhance with descriptive text per grade |
| Long-press anywhere to score (existing) | Competitors require address search first; HouseFriend scores any map point | — | Existing. Ensure works correctly after real data integration |
| Bay Area ZIP polygon boundaries (existing) | Precise neighborhood delineation vs. vague radius circles used by most apps | — | Existing. 445 polygons covering all 9 counties |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Individual crime incident dots / pins on map | "Show me exactly where crimes happened" seems informative | Creates fear-based, fear-amplifying UX (documented in Citizen app research); individual dots encourage vigilante behavior and racial bias; data staleness means dots mislead; Citizen's redesign explicitly moved away from this | Use density heatmap + aggregate statistics in report. Show "X incidents in last 6 months in this ZIP" in the neighborhood report card |
| Real-time crime alerts / push notifications | Feels like premium safety feature | Requires background location, push entitlements, server infrastructure; App Store scrutiny is high for safety notification apps; real-time data pipelines exceed the keyless API constraint; this is a reference/lookup app, not a monitoring app | Out of scope per PROJECT.md. The app is for neighborhood evaluation, not live incident tracking |
| User-submitted crime reports | Community participation feels engaging | Requires moderation, user accounts, backend, legal exposure; documented source of racial bias and misinformation in apps like Nextdoor and Citizen | Out of scope for v1. The value prop is authoritative official data, not crowdsourced reports |
| Social features (sharing scores publicly, comparing with friends) | Discovery/virality appeal | Requires user accounts, backend, identity; PROJECT.md explicitly out of scope; meaningfully increases attack surface and App Store privacy label complexity | One-tap share via UIActivityViewController (system share sheet) covers the social use case without an account system |
| User accounts / sign-in | Sync saved addresses across devices feels premium | Requires backend, authentication, privacy disclosures, account deletion flow (App Store-mandated); all current state is local and works without accounts | Local persistence via UserDefaults + JSON. If cross-device sync becomes a top user request post-launch, revisit with iCloud sync (no custom backend needed) |
| iPad-optimized layout | Universal app is already functional on iPad | Dedicated iPad layout is a separate design effort with different split-view and sidebar conventions; deferred per PROJECT.md | Universal build works; mark iPad as supported but untested in App Store metadata. Dedicated layout is v2+ |

---

## Feature Dependencies

```
Real crime data (SF Open Data, Oakland API)
    └──enables──> Accurate neighborhood crime score (A–F grade)
                      └──feeds into──> Shareable score card (accurate data to show)

School ratings data (GreatSchools / CA Dashboard)
    └──enables──> School pins on map
                      └──feeds into──> Shareable score card

Dark mode support
    └──requires──> Asset catalog semantic colors for all overlay renderers
    └──requires──> Testing heatmap tile colors under .dark traitCollection

Saved addresses
    └──enhances──> Address search (star button contextual to search result)
    └──enhances──> Long-press report (save this location from report sheet)

Shareable score card
    └──requires──> Neighborhood report with real data (otherwise card shows placeholder grades)
    └──requires──> Address search or long-press to generate the report first

Loading spinners (all layers)
    └──requires──> Consistent isLoaded / isLoading state pattern across all 11 services

Layer descriptive text
    └──enhances──> Neighborhood report card (plain-language interpretation of each grade)
    └──enhances──> Shareable score card (context makes the card more meaningful to recipients)

App Store preparation
    └──requires──> Privacy policy (hosted URL)
    └──requires──> App icon (1024x1024 + all sizes)
    └──requires──> Screenshots (6.7" + 5.5" at minimum)
    └──requires──> Real data integration (crime, schools) so screenshots show real content
```

### Dependency Notes

- **Real crime data blocks score card accuracy:** The score card is a differentiator only if data is real. Ship real data integration before share feature to avoid sharing placeholder grades.
- **Dark mode requires testing all custom renderers:** `NoiseSmokeRenderer` and `CrimeTileOverlay` use hardcoded colors today. Both need `traitCollectionDidChange` handling or `UIColor(dynamicProvider:)` to avoid invisible/wrong-color overlays in dark mode.
- **Saved addresses enhances but does not block anything:** It's independent and can ship in any order.
- **App Store screenshots depend on real data:** Screenshots with placeholder crime data will look odd; real data integration should precede screenshot capture.

---

## MVP Definition

The app already has a working 10-layer system. "MVP for App Store" means:

### Launch With (v1 / this milestone)

- [x] Real crime data — data accuracy is foundational trust; without it the safety claim is hollow
- [x] School ratings data — expected by every user who sees a "schools" layer
- [x] Loading spinners on all layers — without this the app feels broken when layers load slowly
- [x] Descriptive text per layer — grades without context feel arbitrary
- [x] Dark mode — App Store reviewers test dark mode; failure is a rejection risk
- [x] Saved addresses — low effort, high-frequency use case for house hunters comparing 3–5 neighborhoods
- [x] Share feature (score card) — core viral/utility loop; couples and families comparing neighborhoods
- [x] Privacy policy accessible in-app — required for App Store submission
- [x] App icon + screenshots — required for App Store submission

### Add After Validation (v1.x)

- [ ] Expanded supportive housing data (SF, Oakland, Berkeley, San Mateo) — adds accuracy but not blocking
- [ ] Expanded electric lines (sub-115kV distribution) — incremental data improvement
- [ ] iCloud sync for saved addresses — only if users request cross-device sync after launch

### Future Consideration (v2+)

- [ ] iPad-optimized split-view layout — functional now, dedicated layout is substantial design work
- [ ] Additional data layers (transit scores, walkability, flood zones) — validate current 10 are enough first
- [ ] Historical trend view (crime over time, air quality trends) — requires time-series data pipeline

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Real crime data integration | HIGH | MEDIUM | P1 |
| School ratings data | HIGH | MEDIUM | P1 |
| Loading spinners (all layers) | HIGH | LOW | P1 |
| Dark mode | MEDIUM | MEDIUM | P1 |
| Descriptive text per layer | HIGH | LOW | P1 |
| Share score card | HIGH | MEDIUM | P1 |
| Saved addresses | MEDIUM | LOW | P1 |
| Privacy policy in-app | LOW (user) / HIGH (App Store) | LOW | P1 |
| App icon + screenshots | LOW (user) / HIGH (App Store) | MEDIUM | P1 |
| Expanded supportive housing data | MEDIUM | MEDIUM | P2 |
| Expanded electric lines | LOW | MEDIUM | P2 |
| iCloud address sync | MEDIUM | MEDIUM | P3 |
| iPad-optimized layout | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | Zillow / Redfin | Citizen / Nextdoor | HouseFriend Approach |
|---------|-----------------|-------------------|----------------------|
| Crime data | Aggregate stats, no map layer (Redfin); CrimeCheck score (Zillow) | Individual incident dots on map, real-time alerts | Heatmap density (existing), switch to real data; avoid individual dots |
| School ratings | GreatSchools 1–10, boundary overlay on map, filter by school when searching | No school data | School pins on map at zoom ≥ 13, tap for detail sheet, GreatSchools rating |
| Dark mode | Both support system dark mode | Citizen: yes; Nextdoor: yes | MKMapView auto-adapts; custom renderers need explicit color adaptation |
| Share | Deep-link to listing (Zillow/Redfin); standard share sheet | Incident share (Citizen); post share (Nextdoor) | Branded score card image + link, via UIActivityViewController |
| Saved locations | Full favorites list, synced to account (Zillow/Redfin) | Nextdoor uses home address | Local-only favorites (no account required); UserDefaults persistence |
| Multi-layer scoring | Not available — single-dimension overlays at most | Not applicable | Core differentiator — 10 simultaneous layers, A–F composite score |
| Data transparency | Score methodology often opaque | No methodology shown | Show data source per layer in report (SF Open Data, USGS, etc.) |

---

## Crime Data Display: Responsible Design Notes

Research on Citizen, Nextdoor, and academic studies (AIGA Eye on Design, ACM CHI) surfaces a consistent finding: individual crime incident maps increase perceived danger without improving decision-making, and correlate with racial bias in user reports and reactions.

**What this means for HouseFriend:**

1. Display crime as aggregate density (heatmap) — not individual pins. The existing Gaussian heatmap model is the right visual metaphor; replace the data source, not the visualization type.
2. Include base rate context in the neighborhood report: "X incidents per 1,000 residents" is more honest than raw count.
3. Show data recency: "Based on incidents reported Jan–Jun 2025 from SF Open Data."
4. Avoid red-only color scales; the crime heatmap already uses a yellow-orange-red gradient which is appropriate. Ensure colorblind accessibility — add a subtle texture or intensity cue beyond color alone.
5. Grade scale calibration matters: a neighborhood scoring "D" should be genuinely at the bottom of Bay Area distribution, not just below average nationally. Normalize grades relative to Bay Area baseline.

---

## Sources

- [Neighborhood Check App — App Store](https://apps.apple.com/us/app/neighborhood-check/id6446656055)
- [Crime and Place: Stats & Map — App Store](https://apps.apple.com/us/app/crime-and-place-stats-map/id1045488584)
- [SpotCrime — App Store](https://apps.apple.com/us/app/spotcrime/id767693374)
- [GreatSchools Ratings Methodology](https://www.greatschools.org/gk/about/ratings/)
- [Redfin School Data](https://support.redfin.com/hc/en-us/articles/360001432452-School-Data)
- [Zillow Search by School (2023)](https://zillow.mediaroom.com/2023-10-11-Search-by-school-on-Zillow-makes-house-hunting-as-easy-as-ABC)
- [Crime Tracking Apps Design Problem — AIGA Eye on Design](https://eyeondesign.aiga.org/do-crime-tracking-apps-have-a-design-problem/)
- [Deceptive Design Patterns in the Citizen App — ACM CHI](https://dl.acm.org/doi/fullHtml/10.1145/3544548.3581258)
- [Dark Mode for MKMapView — copyprogramming](https://copyprogramming.com/howto/how-can-i-turn-the-mkmapview-for-dark-mode)
- [Adopting iOS Dark Mode — Sarunw](https://sarunw.com/posts/adopting-ios-dark-mode/)
- [UIActivityViewController Tips — Filip Nemecek](https://nemecek.be/blog/189/wip-sharing-data-with-uiactivityviewcontroller-tips-tricks)
- [App Store Privacy Policy Requirements 2025](https://iossubmissionguide.com/app-store-privacy-policy-requirements)
- [App Store Review Checklist 2025](https://appinstitute.com/app-store-review-checklist/)
- [MapKit WWDC 2025](https://developer.apple.com/videos/play/wwdc2025/204/)
- [Sharing an image using ShareLink — Hacking with Swift](https://www.hackingwithswift.com/books/ios-swiftui/sharing-an-image-using-sharelink)

---
*Feature research for: HouseFriend — Bay Area Neighborhood Health Report iOS app*
*Researched: 2026-03-22*
