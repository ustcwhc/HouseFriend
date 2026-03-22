# Competitor Reference: Neighborhood Check (NH)

**App Store ID:** id6446656055
**Captured:** 2026-03-22
**Source:** Screenshots shared by user

## Layer-by-Layer Comparison

### Crime Layer
- **Data:** Various sources + local agencies, updated every 1-2 days, last 6 months
- **Methodology:** Crime Rate from historical data + ML predictions for gaps, normalization techniques
- **Display:** Heatmap base (orange gradient) + optional "Details" toggle with numbered cluster markers
- **Sources:** FBI Crime Data, NIBRS, local police, public resources, cross-validated
- **Privacy:** Last 2 address digits hidden ("XX"), some coordinates randomly offset
- **Disclaimers:** Not guaranteed accurate, use as reference only
- **HouseFriend comparison:** Our Gaussian model needs real data (Phase 2). Cluster detail toggle approved for v1.

### Noise Layer
- **Data:** U.S. Bureau of Transportation 2020
- **Methodology:** Simulated models (not measured) — highway/roads, rails, aviation. No non-transportation noise.
- **Display:** Heatmap gradient with dB legend (7 tiers: >80 to <50)
- **Coverage:** CA (Bay Area & LA), WA, NJ, NY only
- **Limitations:** National-level analysis, not precise for individual locations
- **HouseFriend comparison:** Our smoke renderer is more visually distinctive. We use real road geometry + Overpass detail. They have aviation noise we don't.

### Schools Layer
- **Data:** NCES + CAASPP 2023
- **3 categories:** Basic school info (national), CA test scores (CAASPP Smarter Balanced + CAST), attendance boundaries (beta, Bay Area only)
- **Display:** Color-coded pins by level (green=high rating, blue=mid, etc.), name + rating number on pin label (e.g., "Santa Clara High (10)")
- **Limitations:** Public schools only, no college admission rates, attendance boundaries are beta
- **HouseFriend comparison:** We plan CDE Dashboard data (same as CAASPP). Should adopt their pin label format with rating number.

### Electric Lines Layer
- **Data:** HIFLD (Homeland Infrastructure Foundation-Level Data) 2022
- **Shows:** Transmission lines (69-765 kV) including underground + substations
- **Coverage:** Lines = whole U.S., Substations = California only
- **Display:** Dense pink/magenta lines showing full distribution network
- **HouseFriend comparison:** Our current lines are transmission-only. HIFLD is the source for DATA-02 expansion. Consider adding substations.

### Superfund Layer
- **Data:** U.S. EPA 2023
- **Display:** Custom flask/beaker icons with site names as labels
- **Interaction:** Tap pin → site details + "More Details" link to EPA website
- **Status coding:** Active NPL sites vs. Deleted NPL sites (green = cleaned up)
- **Educational context:** Full CERCLA/Superfund history explanation
- **HouseFriend comparison:** Our 62 hardcoded sites could add NPL status field and EPA deep links.

### Supportive Housing Layer
- **Data:** HUD + non-profits (LifeMoves, Abode Services, HomeFirst, HomeKey, CityTeam) + local gov news/media (2023)
- **Coverage:** Bay Area only
- **Educational context:** Explains what supportive housing is, emphasizes connection to well-being
- **HouseFriend comparison:** Good data sources for our DATA-01 expansion (SF, Oakland, Berkeley, San Mateo).

### Milpitas Odor Layer
- **Display:** Dedicated layer, orange-to-transparent heatmap gradient centered on Newby Island landfill area
- **HouseFriend comparison:** Our Air Quality/Odor layer includes industrial zones — Milpitas likely covered but not called out separately.

### Population Layer
- **Data:** U.S. Census Bureau 2020
- **Multi-zoom:** 4 levels — County → Zipcode → Census Tract → Census Block
- **Interaction:** Short click = data at current zoom level, Long press = block-level + 300m aggregation
- **Coverage:** County/ZIP = whole U.S. Tract = 7 states. Block = CA/WA/NJ/NY metros only.
- **HouseFriend comparison:** Our 445 ZIP polygons with demographics sheet (racial, income, age charts) is more detailed info per ZIP than their population count.

## Design Patterns Noted

1. **Layer description modals** — each layer has an info button (?) showing: "What is it?", "Where is data from?", "Limitations"
2. **Data source attribution** on every layer description
3. **Limitation disclaimers** — transparent about data gaps and accuracy
4. **Color-coded pins** by category/rating
5. **Detail toggle** — two-tier view (overview + detail markers)
6. **Rating numbers on pin labels** — scannable without tapping
7. **Educational context** — explains unfamiliar concepts (Superfund, supportive housing)

---
*Competitive analysis captured: 2026-03-22*
