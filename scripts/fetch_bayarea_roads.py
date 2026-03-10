#!/usr/bin/env python3
"""
Fetch Bay Area major roads & railways from Overpass API and save as JSON
for instant rendering in the HouseFriend noise layer.

Output: ../HouseFriend/bayarea_roads.json
"""

import json
import time
import urllib.request

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# Bay Area bounding box: south, west, north, east
BBOX = "36.9,-122.6,38.1,-121.5"

# Fetch major highways (motorway, trunk, primary) and railways (rail, light_rail, subway)
QUERY = f"""
[out:json][timeout:60];
(
  way["highway"~"motorway|trunk|primary"]({BBOX});
  way["railway"~"rail|light_rail|subway"]({BBOX});
);
out body;
>;
out skel qt;
"""


def fetch_overpass(query: str) -> dict:
    data = f"data={urllib.parse.quote(query)}".encode()
    req = urllib.request.Request(OVERPASS_URL, data=data, method="POST")
    req.add_header("User-Agent", "HouseFriend/1.0")
    with urllib.request.urlopen(req, timeout=90) as resp:
        return json.loads(resp.read())


def parse_elements(elements: list) -> list:
    # Build node map
    node_map = {}
    for el in elements:
        if el.get("type") == "node":
            node_map[el["id"]] = [el["lat"], el["lon"]]

    roads = []
    for el in elements:
        if el.get("type") != "way":
            continue
        tags = el.get("tags", {})
        highway = tags.get("highway", "")
        railway = tags.get("railway", "")
        if not highway and not railway:
            continue

        node_ids = el.get("nodes", [])
        coords = []
        for nid in node_ids:
            if nid in node_map:
                coords.append(node_map[nid])

        if len(coords) < 2:
            continue

        road_type = highway if highway else f"railway_{railway}"
        name = tags.get("name", "")

        roads.append({
            "wayId": el["id"],
            "type": road_type,
            "name": name,
            "coords": coords,  # [[lat, lon], ...]
        })

    return roads


def main():
    import urllib.parse

    print(f"Fetching roads & railways from Overpass ({BBOX})...")
    result = fetch_overpass(QUERY)
    elements = result.get("elements", [])
    print(f"  Got {len(elements)} elements")

    roads = parse_elements(elements)
    print(f"  Parsed {len(roads)} roads/railways")

    # Stats
    types = {}
    for r in roads:
        t = r["type"]
        types[t] = types.get(t, 0) + 1
    for t, c in sorted(types.items(), key=lambda x: -x[1]):
        print(f"    {t}: {c}")

    out_path = "../HouseFriend/bayarea_roads.json"
    with open(out_path, "w") as f:
        json.dump(roads, f, separators=(",", ":"))

    size_kb = len(open(out_path).read()) / 1024
    print(f"\nSaved {len(roads)} entries to {out_path} ({size_kb:.0f} KB)")


if __name__ == "__main__":
    main()
