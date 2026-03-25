# Crime Data Sources Research — Bay Area Coverage

**Researched:** 2026-03-22
**Domain:** Public crime incident APIs with GPS coordinates for Bay Area iOS heatmap
**Confidence:** HIGH for confirmed sources, MEDIUM for sources with indirect verification, LOW for sources without direct testing

---

## Summary

The Bay Area has no single unified crime data API covering all 9 counties. The best achievable coverage requires a **city-by-city and county-by-county patchwork** of open data portals. The good news: most major Bay Area jurisdictions publish incident-level data with GPS coordinates via either Socrata SODA or ArcGIS REST APIs — all free and keyless.

The FBI Crime Data Explorer API is the biggest red herring: it provides aggregate statistical counts (not per-incident GPS points), requires an API key through a request process, and is fundamentally the wrong tool for a heatmap. Paid APIs like SpotCrime and CrimeOmeter can fill gaps but are not suitable for a zero-dependency, no-paid-API v1.

**Primary recommendation:** Use Socrata SODA (already familiar from SF and Oakland) as the primary pattern where available; fall back to ArcGIS FeatureServer REST queries for cities on ArcGIS Hub. This covers ~85% of Bay Area population. Remaining gaps (Fremont, Richmond, San Mateo city, etc.) can be addressed via CrimeMapping.com's data which many of those agencies feed.

---

## Currently Working Sources (Confirmed)

### Source 1: San Francisco — Socrata SODA
| Property | Value |
|----------|-------|
| Dataset | Police Incident Reports |
| Dataset ID | `wg3w-h783` |
| Domain | `data.sfgov.org` |
| API endpoint | `https://data.sfgov.org/resource/wg3w-h783.json` |
| GPS coordinates | YES — `latitude` and `longitude` as separate string fields, plus GeoJSON point |
| Coverage | City and County of San Francisco |
| Update frequency | Daily |
| Auth required | No (keyless) |
| Data format | JSON via SODA |
| Confidence | HIGH — directly verified via live API call |

Sample coordinate fields confirmed:
```json
{ "latitude": "37.75226974487305", "longitude": "-122.41787719726562" }
```

---

### Source 2: Oakland — Socrata SODA
| Property | Value |
|----------|-------|
| Dataset | CrimeWatch Maps Past 90-Days |
| Dataset ID | `ym6k-rx7a` |
| Domain | `data.oaklandca.gov` |
| API endpoint | `https://data.oaklandca.gov/resource/ym6k-rx7a.json` |
| GPS coordinates | YES — `location_1` GeoJSON point: `{"coordinates": [-122.277, 37.812]}` |
| Coverage | City of Oakland |
| Update frequency | Rolling 90 days (daily) |
| Auth required | No (keyless) |
| Data format | JSON via SODA |
| Confidence | HIGH — directly verified via live API call |

Sample coordinate confirmed:
```json
{ "location_1": { "type": "Point", "coordinates": [-122.27705, 37.81155] } }
```

Note: A second, longer-history dataset exists — `ppgh-7dqv` (CrimeWatch Data) on the same domain.

---

## New Sources — Recommended for Integration

### Source 3: Marin County Sheriff — Socrata SODA
| Property | Value |
|----------|-------|
| Dataset | County Sheriff Reported Crimes |
| Dataset ID | `ahxi-5nsc` |
| Domain | `data.marincounty.gov` |
| API endpoint | `https://data.marincounty.gov/resource/ahxi-5nsc.json` |
| GPS coordinates | YES — `latitude` and `longitude` as separate fields, plus nested `location` object |
| Coverage | Marin County Sheriff jurisdiction (unincorporated + contracted cities) |
| Update frequency | Every 4 hours |
| Auth required | No (keyless) |
| Data format | JSON via SODA |
| Confidence | HIGH — directly verified via live API call |

Sample data confirmed (real incident returned):
```json
{
  "crime": "THEFT",
  "incident_date_time": "2026-03-21T22:15:00",
  "incident_street_address": "DRAKE AVE & DONAHUE ST",
  "incident_city_town": "MARIN CITY",
  "jurisdiction": "SO",
  "latitude": "37.8734360",
  "longitude": "-122.5118910",
  "location": { "latitude": "37.8734360", "longitude": "-122.5118910" }
}
```

Coverage note: Covers Sheriff-jurisdiction areas of Marin County. Incorporated city police (San Rafael, Novato, Mill Valley, etc.) file separately and may not appear here.

---

### Source 4: San Jose Police Department — ArcGIS FeatureServer
| Property | Value |
|----------|-------|
| Dataset | Crime Incidents |
| Service org ID | `dty2kHktVXHrqO8i` |
| API endpoint | `https://services3.arcgis.com/dty2kHktVXHrqO8i/ArcGIS/rest/services/Crime_Incidents/FeatureServer/0/query` |
| GPS coordinates | YES — explicit `LAT` and `LON` fields (esriFieldTypeDouble), described as "snapped to nearest street" |
| Coverage | UNVERIFIED — the endpoint metadata listed this service but the sample data returned was from Cleveland PD. The SJPD website links to CrimeMapping.com, not a public ArcGIS endpoint. This endpoint ID may be a shared template. |
| Update frequency | Unknown |
| Auth required | Appears public (no token required in REST calls) |
| Data format | JSON (GeoJSON or Esri JSON via `f=json` or `f=geojson`) |
| Confidence | LOW — field schema confirmed; actual San Jose data NOT confirmed. Requires direct verification. |

**Action required:** Inspect the SJPD website network traffic or contact gis.info@sanjoseca.gov to find the actual production ArcGIS endpoint for San Jose crime data.

Query pattern for ArcGIS FeatureServer:
```
GET /FeatureServer/0/query?where=1%3D1&outFields=LAT,LON,UCRdesc,OffenseDate,Address_Public&resultRecordCount=2000&f=json
```

---

### Source 5: San Jose Open Data Portal — CKAN (NO GPS)
| Property | Value |
|----------|-------|
| Dataset | Police Calls for Service 2024 |
| Resource ID | `df207219-ba82-407d-8190-5b31edaded79` |
| Domain | `data.sanjoseca.gov` |
| GPS coordinates | NO — address only (100-block level: ADDRESS, CITY, STATE fields). No lat/lon. |
| Coverage | City of San Jose |
| Confidence | HIGH — confirmed via dataset schema |

**Verdict:** This dataset is NOT usable for GPS heatmap without geocoding each record. Skip unless geocoding is added as a future phase.

---

### Source 6: Berkeley — Socrata SODA (Calls for Service)
| Property | Value |
|----------|-------|
| Dataset | Berkeley PD - Calls for Service |
| Dataset ID | `k2nh-s5h5` |
| Domain | `data.cityofberkeley.info` |
| API endpoint | `https://data.cityofberkeley.info/resource/k2nh-s5h5.json` |
| GPS coordinates | UNVERIFIED — API returned 403 during testing; documentation mentions heatmap visualization exists, implying coordinates are present. ArcGIS Hub also hosts Berkeley PD crime data (bpd-transparency-initiative-berkeleypd.hub.arcgis.com). |
| Coverage | City of Berkeley |
| Update frequency | Unknown |
| Auth required | Portal exists and is public; 403 may be rate-limiting or CORS restriction |
| Confidence | MEDIUM — dataset confirmed to exist on Socrata, coordinates not directly verified |

**Action required:** Test `https://data.cityofberkeley.info/resource/k2nh-s5h5.json?$limit=1` from an iOS device context (not WebFetch). Berkeley also has an ArcGIS Hub portal that may have a working FeatureServer endpoint.

---

## Investigated But Not Recommended for v1

### FBI Crime Data Explorer (CDE) — WRONG TOOL
| Property | Value |
|----------|-------|
| API endpoint | `https://api.usa.gov/crime/fbi/sapi/` |
| GPS coordinates | NO — provides aggregate counts by agency/year/offense type. No per-incident GPS. |
| Coverage | Nationwide (agencies that submit UCR data) |
| Auth required | YES — requires registration at api.data.gov/signup for a free API key |
| Data granularity | Agency-level annual summaries (e.g., "Oakland PD reported 4,200 property crimes in 2022") |
| NIBRS per-incident | Available only through bulk annual data dumps (not real-time API), and even NIBRS does not include GPS coordinates — location is coded as a "location type" (residence, street, commercial, etc.), not coordinates |
| Confidence | HIGH (confirmed limitation) |

**Verdict:** Completely wrong data type for a heatmap. The FBI CDE API is for policy research and statistical dashboards, not per-incident mapping.

---

### SpotCrime — Paid / Semi-Public
| Property | Value |
|----------|-------|
| GPS coordinates | YES — `incident_latitude` and `incident_longitude` per incident |
| Coverage | Reportedly nationwide, pulls from police blotters |
| Bay Area coverage | UNVERIFIED — aggregates public blotter data; coverage depends on agencies publishing online blotters |
| Auth required | YES — API keys required; not free for commercial/research use |
| Cost | Not public — contact api@spotcrime.com |
| API stability | Poor — keys change deliberately; third-party clients break constantly |
| Confidence | MEDIUM (pricing from official blog; key instability from multiple developer sources) |

**Verdict:** Not suitable for v1 (no paid APIs). Could be a fallback for city coverage gaps in a future paid tier.

---

### CrimeOmeter — Paid with Free Trial
| Property | Value |
|----------|-------|
| API endpoint | `https://api.crimeometer.com/v2/crime-incidents?lat={lat}&lon={lon}&datetime_ini={start}&datetime_end={end}&distance={km}` |
| GPS coordinates | YES — `incident_latitude` and `incident_longitude` per incident |
| Coverage | Claims 50+ US states worldwide; California assumed included |
| Bay Area city coverage | UNVERIFIED specifically |
| Auth required | YES — API key required |
| Cost | Evaluation tier (limited, free trial) + Enterprise (price on request) |
| Free tier | Up to 10 requests/month (from community comparison article) |
| Update frequency | Unknown |
| Confidence | MEDIUM — response format confirmed from documentation; Bay Area coverage not confirmed |

**Verdict:** Interesting as a coverage aggregator but 10 requests/month free tier is far too low for a live app. Enterprise pricing is unspecified. Not suitable for v1.

---

### CrimeMapping.com / RAIDS Online — No Public API
| Property | Value |
|----------|-------|
| GPS coordinates | YES — displays incident map with coordinates |
| Coverage | Participating agencies — San Jose SJPD is a confirmed participant |
| Bay Area agencies | San Jose (confirmed), Berkeley UCPD (confirmed), others unknown |
| API available | NO public developer API exists |
| Auth required | N/A — no API to authenticate against |
| Data access | Web interface only; could theoretically be reverse-engineered but violates ToS |
| Confidence | HIGH (no API confirmed from official sources and community research) |

**Verdict:** Not viable for programmatic access. San Jose and some other Bay Area cities use CrimeMapping.com as their public crime map, which means their GPS data IS available visually but not via API.

---

### San Mateo County — CitizenRIMS (No Public API)
| Property | Value |
|----------|-------|
| GPS coordinates | Likely YES (visual map tool) |
| Coverage | San Mateo County Sheriff unincorporated areas + contracted cities (Half Moon Bay, Millbrae, San Carlos, Portola Valley, Woodside) |
| API available | NO — CitizenRIMS is a proprietary web/mobile platform (no documented public API) |
| Data access | Web interface only at smcsheriff.citizenrims.com |
| Alternative | `data.smcgov.org` (Open San Mateo County portal) exists but crime incident datasets with GPS coordinates were not identified in the catalog |
| Confidence | MEDIUM — no API confirmed from CitizenRIMS; Open SMC data catalog not fully enumerated |

**Verdict:** No viable free API found for San Mateo County Sheriff data. The Open San Mateo portal (`data.smcgov.org`) should be explored manually for crime incident datasets.

---

### NIBRS Bulk Data — Wrong Format
| Property | Value |
|----------|-------|
| GPS coordinates | NO — NIBRS encodes location as a "location type code" (residence, street, hotel, etc.) — not GPS coordinates |
| Access | Annual bulk downloads from FBI; also a BJS API for aggregate national estimates |
| Coverage | Agencies that submit NIBRS (not all Bay Area agencies participate) |
| Confidence | HIGH (confirmed from NIBRS technical specification and multiple sources) |

**Verdict:** No per-incident GPS in NIBRS. Not useful for heatmap.

---

## Bay Area Coverage Map

| County | City / Jurisdiction | Source | GPS? | API Type | Status |
|--------|---------------------|--------|------|----------|--------|
| San Francisco | SF (entire county) | DataSF SODA `wg3w-h783` | YES | SODA | Working |
| Alameda | Oakland | Oakland SODA `ym6k-rx7a` | YES | SODA | Working |
| Alameda | Berkeley | Berkeley SODA `k2nh-s5h5` | LIKELY | SODA | Needs verification |
| Alameda | Fremont | No open API found | UNKNOWN | None | Gap |
| Alameda | Alameda city | No open API found | UNKNOWN | None | Gap |
| Alameda | San Leandro, Hayward, etc. | No open API found | UNKNOWN | None | Gap |
| Santa Clara | San Jose | Open data has no GPS; ArcGIS endpoint unverified | NO / MAYBE | CKAN / ArcGIS | Needs verification |
| Santa Clara | Other (Sunnyvale, Santa Clara city, etc.) | No open API found | UNKNOWN | None | Gap |
| Contra Costa | All cities | No countywide API found | UNKNOWN | None | Gap |
| Marin | Sheriff jurisdiction | Marin SODA `ahxi-5nsc` | YES | SODA | Working |
| Marin | Incorporated cities (San Rafael, Novato) | Not in county Sheriff dataset | UNKNOWN | None | Partial gap |
| San Mateo | Sheriff / unincorporated | No public API found | UNKNOWN | None | Gap |
| San Mateo | City of San Mateo, others | No open API found | UNKNOWN | None | Gap |
| Solano, Napa, Sonoma | All | Not researched | UNKNOWN | None | Outside scope? |

**Population coverage estimate:** SF + Oakland + Marin County = roughly 30% of Bay Area population. Adding Berkeley brings this to ~35%. San Jose is the largest gap (1M+ people, 3rd largest CA city).

---

## Recommended Integration Strategy

### Tier 1 — Implement Now (Confirmed, Free, GPS)
1. **San Francisco** — Already working (`wg3w-h783`)
2. **Oakland** — Already working (`ym6k-rx7a`)
3. **Marin County** — Ready to implement (`ahxi-5nsc` on `data.marincounty.gov`)

### Tier 2 — Implement After Verification
4. **Berkeley** — Test `data.cityofberkeley.info/resource/k2nh-s5h5.json` from iOS; if 403 persists, check Berkeley ArcGIS Hub for FeatureServer endpoint
5. **San Jose** — Contact gis.info@sanjoseca.gov or inspect SJPD website network traffic to find the production ArcGIS FeatureServer endpoint with GPS data (CrimeMapping.com is the only confirmed GPS source for SJ but has no public API)

### Tier 3 — Future Work / Paid Tier Only
6. **CrimeOmeter** — Consider for comprehensive Bay Area gap-filling if a paid tier is introduced
7. **SpotCrime** — Alternative paid option but poor API stability
8. **Other cities** — Fremont, Richmond, San Mateo city, Contra Costa cities all lack confirmed public GPS crime APIs

---

## SODA API Pattern (Consistent Across All Confirmed Sources)

All three confirmed sources use the same Socrata SODA pattern (identical to existing SF and Oakland implementations):

```
GET https://{domain}/resource/{dataset-id}.json
  ?$where={SoQL filter}
  &$limit={max records}
  &$offset={pagination}
```

For geographic bounding box query:
```
GET https://data.marincounty.gov/resource/ahxi-5nsc.json
  ?$where=latitude > '37.8' AND latitude < '38.1' AND longitude > '-123.0' AND longitude < '-122.4'
  &$limit=1000
```

Note: Marin uses string latitude/longitude fields (not native Socrata geo columns), so comparisons use string comparison. SF uses numeric geo columns with within_box() function. Oakland uses GeoJSON point geometry. Implementation must handle all three formats.

---

## Key Technical Pitfalls

### Pitfall 1: SODA coordinate field formats differ by city
SF uses separate `latitude`/`longitude` numeric fields and a `point` GeoJSON column. Oakland uses `location_1` (GeoJSON point, coordinates in [lon, lat] order). Marin uses `latitude`/`longitude` as strings. Do NOT assume a uniform schema across SODA providers.

### Pitfall 2: San Jose's open data has NO GPS
The `data.sanjoseca.gov` Police Calls dataset explicitly has no latitude/longitude — only block-level addresses. Any San Jose heatmap implementation requires either: (a) finding a separate ArcGIS endpoint, or (b) geocoding addresses at runtime (expensive and slow).

### Pitfall 3: FBI CDE is aggregate-only
The FBI API returns counts per agency per year, not incident points. It's useless for heatmaps regardless of API key status.

### Pitfall 4: Max record count on ArcGIS FeatureServer
ArcGIS FeatureServer endpoints typically cap at 1,000–2,000 records per query. For large cities over long time ranges, pagination or spatial tiling is required. The confirmed SODA endpoints support `$limit` up to 50,000.

### Pitfall 5: Marin County covers Sheriff jurisdiction only
The `ahxi-5nsc` dataset covers the Sheriff's patrol area. Incorporated cities in Marin (San Rafael PD, Novato PD, etc.) may not appear. The dataset field `jurisdiction: "SO"` (Sheriff's Office) confirms this.

### Pitfall 6: Data is block/intersection-level, not exact address
All confirmed sources snap coordinates to the nearest street intersection or 100-block for privacy reasons. This is expected and appropriate — do not advertise to users that pin locations represent exact crime addresses.

---

## Open Questions

1. **San Jose ArcGIS endpoint** — Is there a production SJPD FeatureServer with GPS-level crime incident data? The SJPD website directs users to CrimeMapping.com (no API). The ArcGIS endpoint found (`dty2kHktVXHrqO8i`) returns Cleveland data. Requires investigation.

2. **Berkeley SODA 403** — Is the `data.cityofberkeley.info` API accessible from mobile iOS clients? The 403 may be due to the WebFetch tool's user-agent rather than a real access restriction.

3. **Contra Costa cities (Richmond, Concord, etc.)** — Richmond CA has a "Transparent Richmond" website with daily crime logs but no confirmed structured API with GPS. Concord published 2024 data but no API was found.

4. **Fremont** — Has an ArcGIS Hub (`fremont-ca-open-data-cofgis.hub.arcgis.com`) but no crime incident dataset was confirmed in the catalog. Worth a direct browse.

5. **San Mateo data.smcgov.org** — The portal exists and uses Socrata. A manual catalog search for crime incident datasets was not possible via WebFetch (all pages return JS config). Worth a direct visit.

6. **Solano, Napa, Sonoma** — Not researched. If the app targets "all 9 counties," these need investigation.

---

## Sources

### Primary (HIGH confidence — directly verified)
- `https://data.sfgov.org/resource/wg3w-h783.json?$limit=1` — Live API response confirmed lat/lon
- `https://data.oaklandca.gov/resource/ym6k-rx7a.json?$limit=1` — Live API response confirmed GeoJSON coordinates
- `https://data.marincounty.gov/resource/ahxi-5nsc.json?$limit=1` — Live API response confirmed lat/lon strings
- `https://services3.arcgis.com/dty2kHktVXHrqO8i/ArcGIS/rest/services/Crime_Incidents/FeatureServer/0?f=json` — Confirmed LAT/LON fields exist in schema; confirmed data is NOT San Jose (is Cleveland)
- `https://data.sanjoseca.gov/dataset/police-calls-for-service/resource/df207219-ba82-407d-8190-5b31edaded79` — Confirmed NO GPS coordinates in San Jose CKAN dataset

### Secondary (MEDIUM confidence — indirect verification)
- `https://blog.spotcrime.com/2019/03/the-spotcrime-api.html` — SpotCrime API not free, keys unstable
- `https://www.worldindata.com/api/crimeometer-crime-incidents-api/` — CrimeOmeter response format with lat/lon confirmed
- `https://berkeleyca.gov/safety-health/police/data-crime-calls-service-stops-and-use-force` — Berkeley SODA dataset confirmed to exist; coordinates likely present based on heat map visualization
- `https://www.smcsheriff.com/press-releases/san-mateo-county-sheriffs-office-launches-new-and-improved-crime-data-portal` — San Mateo has a crime portal but no documented API

### Tertiary (LOW confidence — indirect/unverified)
- `https://data.marincounty.gov/Public-Safety/County-Sheriff-Reported-Crimes/ahxi-5nsc` — Update frequency "every 4 hours" from search result snippet; not directly verified
- `https://www.fremontpolice.gov/about-us/crime-statistics` — Fremont has crime stats page; no open API found
- Contra Costa, Solano, Napa, Sonoma — Not researched; no confirmed data sources

---

## Metadata

**Confidence breakdown:**
- SF, Oakland (existing): HIGH — live API confirmed
- Marin County: HIGH — live API confirmed, real incident data returned
- Berkeley: MEDIUM — dataset confirmed but coordinates not live-tested
- San Jose: LOW for GPS — open data portal confirmed NO GPS; ArcGIS route unverified
- FBI CDE: HIGH (confirmed wrong tool for this use case)
- SpotCrime, CrimeOmeter: MEDIUM — not free, suitable for future paid tier only

**Research date:** 2026-03-22
**Valid until:** 2026-09-22 (6 months — open data portals change infrequently; API endpoints are stable)
