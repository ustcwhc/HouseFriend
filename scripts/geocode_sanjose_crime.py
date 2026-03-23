#!/usr/bin/env python3
"""
Batch geocode San Jose crime data and output per-census-tract crime counts.

Strategy: Instead of geocoding all 14K unique addresses, we:
1. Sample the top ~500 most frequent addresses (covers ~60% of incidents)
2. Geocode those using Nominatim (OSM) at 1 req/sec
3. Map all incidents at those addresses to lat/lon
4. Assign to census tracts and compute density scores
5. Output as JSON for bundling into the app

Usage: python3 scripts/geocode_sanjose_crime.py
Output: HouseFriend/sanjose_crime_density.json
"""

import csv
import json
import re
import time
import urllib.request
import urllib.parse
from collections import Counter
from pathlib import Path

CSV_URL = "https://data.sanjoseca.gov/dataset/c5929f1b-7dbe-445e-83ed-35cca0d3ca8b/resource/dc0ec99c-0c6b-45fb-b1ec-faf072fe4833/download/policecalls2026.csv"
CACHE_FILE = Path("/tmp/sj_geocode_cache.json")
OUTPUT_FILE = Path(__file__).parent.parent / "HouseFriend" / "sanjose_crime_geocoded.json"
MAX_GEOCODE = 500  # Top N addresses to geocode


def download_csv():
    """Download SJ crime CSV to temp file."""
    csv_path = Path("/tmp/sj_crime_2026.csv")
    if csv_path.exists() and csv_path.stat().st_size > 1000:
        print(f"Using cached CSV: {csv_path}")
        return csv_path
    print("Downloading San Jose crime CSV...")
    urllib.request.urlretrieve(CSV_URL, csv_path)
    print(f"Downloaded: {csv_path.stat().st_size / 1024:.0f} KB")
    return csv_path


def load_address_counts(csv_path):
    """Count incidents per unique address."""
    counts = Counter()
    total = 0
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            total += 1
            addr = row.get('ADDRESS', '').strip()
            if addr:
                counts[addr] += 1
    print(f"Total incidents: {total}")
    print(f"Unique addresses: {len(counts)}")
    return counts


def clean_address(raw):
    """Convert SJ block format to geocodable address.
    '[300]-[400] E SANTA CLARA ST' -> '350 E Santa Clara St'
    'N BASCOM AV & HEATHERDALE AV' -> 'N Bascom Av and Heatherdale Av'
    """
    addr = raw.strip()
    # Convert "[300]-[400]" to midpoint
    match = re.match(r'\[(\d+)\]-\[(\d+)\]\s*(.*)', addr)
    if match:
        lo, hi = int(match.group(1)), int(match.group(2))
        mid = (lo + hi) // 2
        addr = f"{mid} {match.group(3)}"
    # Convert intersection
    addr = addr.replace(' & ', ' and ')
    return addr


def geocode_nominatim(address, city="San Jose", state="CA"):
    """Geocode an address using Nominatim. Returns (lat, lon) or None."""
    query = urllib.parse.urlencode({
        'q': f"{address}, {city}, {state}",
        'format': 'json',
        'limit': 1,
        'countrycodes': 'us'
    })
    url = f"https://nominatim.openstreetmap.org/search?{query}"
    req = urllib.request.Request(url, headers={
        'User-Agent': 'HouseFriend-DataPipeline/1.0 (crime-geocoding)'
    })
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            if data:
                lat = float(data[0]['lat'])
                lon = float(data[0]['lon'])
                # Sanity check: must be in Bay Area
                if 36.5 < lat < 38.5 and -123.0 < lon < -121.0:
                    return (lat, lon)
    except Exception as e:
        print(f"  Geocode error: {e}")
    return None


def batch_geocode(address_counts, max_count=MAX_GEOCODE):
    """Geocode top N most frequent addresses with caching."""
    # Load cache
    cache = {}
    if CACHE_FILE.exists():
        cache = json.loads(CACHE_FILE.read_text())
        print(f"Loaded {len(cache)} cached geocodes")

    # Get top addresses by frequency
    top_addresses = address_counts.most_common(max_count)
    incidents_covered = sum(c for _, c in top_addresses)
    total_incidents = sum(address_counts.values())
    print(f"\nGeocoding top {max_count} addresses (covers {incidents_covered}/{total_incidents} = {incidents_covered/total_incidents*100:.0f}% of incidents)")

    geocoded = {}
    new_count = 0

    for i, (raw_addr, count) in enumerate(top_addresses):
        cleaned = clean_address(raw_addr)

        if raw_addr in cache:
            geocoded[raw_addr] = cache[raw_addr]
            continue

        coords = geocode_nominatim(cleaned)
        if coords:
            geocoded[raw_addr] = {"lat": coords[0], "lon": coords[1]}
            cache[raw_addr] = {"lat": coords[0], "lon": coords[1]}
            new_count += 1
        else:
            cache[raw_addr] = None  # Cache misses too

        # Progress
        if (i + 1) % 50 == 0:
            print(f"  {i+1}/{max_count} addresses geocoded ({new_count} new)")

        # Rate limit: 1 request per second
        time.sleep(1.1)

    # Save cache
    CACHE_FILE.write_text(json.dumps(cache, indent=2))
    print(f"\nGeocoded {len(geocoded)} addresses ({new_count} new API calls)")

    return geocoded


def build_incident_list(csv_path, geocoded, address_counts):
    """Build list of geocoded incidents."""
    incidents = []
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            addr = row.get('ADDRESS', '').strip()
            if addr in geocoded and geocoded[addr] is not None:
                loc = geocoded[addr]
                incidents.append({
                    "lat": loc["lat"],
                    "lon": loc["lon"],
                    "category": row.get('CALL_TYPE', ''),
                    "date": row.get('OFFENSE_DATE', '')
                })

    print(f"Geocoded incidents: {len(incidents)}")
    return incidents


def main():
    csv_path = download_csv()
    address_counts = load_address_counts(csv_path)
    geocoded = batch_geocode(address_counts)
    incidents = build_incident_list(csv_path, geocoded, address_counts)

    # Output as JSON
    output = {
        "city": "San Jose",
        "source": "San Jose Police Calls for Service 2026",
        "incident_count": len(incidents),
        "incidents": incidents
    }

    OUTPUT_FILE.write_text(json.dumps(output))
    print(f"\nOutput: {OUTPUT_FILE}")
    print(f"Size: {OUTPUT_FILE.stat().st_size / 1024:.0f} KB")
    print(f"\nDone! {len(incidents)} geocoded incidents ready for bundling.")


if __name__ == "__main__":
    main()
