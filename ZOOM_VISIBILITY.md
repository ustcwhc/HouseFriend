# Zoom-Level Visibility Reference

> Code definition: `HouseFriend/Models/ZoomTier.swift`

## Zoom Tiers

```
Z0 Satellite ─── 5.0° ─── Z1 State ─── 1.2° ─── Z2 County ─── 0.3° ─── Z3 City ─── 0.08° ─── Z4 Neighborhood
```

| Tier | Name | Span (latitudeDelta) | What's Visible on Map |
|------|------|----------------------|----------------------|
| Z0 | **Satellite** | > 5° | Continents, countries |
| Z1 | **State** | 1.2° – 5° | State outlines, major cities |
| Z2 | **County** | 0.3° – 1.2° | Freeways, city boundaries |
| Z3 | **City** | 0.08° – 0.3° | Boulevards, arterials |
| Z4 | **Neighborhood** | < 0.08° | Residential streets, buildings |

---

## Complete Object Map

### Satellite / State: Nothing rendered

### County (Z2)

| Object | Layer | Rendering | Notes |
|--------|-------|-----------|-------|
| ZIP polygon | Population | MKPolygon | Yellow border, 445 ZIPs |
| ZIP label | Population | MKAnnotationView | White label with ZIP ID |
| High school | Schools | MKMarkerAnnotationView | Purple, graduationcap.fill |
| Fire zone (Extreme) | Fire Hazard | MKPolygon | Dark red, 50% opacity |
| Fire zone (Very High) | Fire Hazard | MKPolygon | Orange-red, 42% opacity |
| Fire zone (High) | Fire Hazard | MKPolygon | Golden, 35% opacity |
| Fire zone (Moderate) | Fire Hazard | MKPolygon | Yellow, 28% opacity |
| 115 kV power line | Electric | MKPolyline | Yellow, 2.5pt |
| 60 kV power line | Electric | MKPolyline | Yellow, 2.5pt |

### City (Z3) — adds these

| Object | Layer | Rendering | Notes |
|--------|-------|-----------|-------|
| Crime heatmap | Crime | MKTileOverlay | Gaussian model tiles |
| Motorway | Noise | NoiseSmokeRenderer | 78 dB, 5pt, dark smoke |
| Trunk road | Noise | NoiseSmokeRenderer | 74 dB, 5pt |
| Primary road | Noise | NoiseSmokeRenderer | 68 dB, 4pt |
| Heavy rail | Noise | NoiseSmokeRenderer | 75 dB, 4pt, dashed |
| Light rail / subway | Noise | NoiseSmokeRenderer | 70 dB, 3.5pt, dashed |
| Middle school | Schools | MKMarkerAnnotationView | Blue, graduationcap.fill |
| Earthquake (M >= 5) | Earthquake | MKMarkerAnnotationView | Red, magnitude text |
| Earthquake (M >= 4) | Earthquake | MKMarkerAnnotationView | Orange |
| Earthquake (M < 4) | Earthquake | MKMarkerAnnotationView | Yellow |
| Superfund site | Superfund | MKMarkerAnnotationView | Orange, triangle icon |

### Neighborhood (Z4) — adds these

| Object | Layer | Rendering | Notes |
|--------|-------|-----------|-------|
| Violent crime marker | Crime | MKMarkerAnnotationView | Purple, clickable |
| Property crime marker | Crime | MKMarkerAnnotationView | Cyan, clickable |
| Vehicle crime marker | Crime | MKMarkerAnnotationView | Orange, clickable |
| Vandalism marker | Crime | MKMarkerAnnotationView | Brown, clickable |
| Other crime marker | Crime | MKMarkerAnnotationView | Gray, clickable |
| Secondary road | Noise | NoiseSmokeRenderer | 63 dB, 3pt |
| Tertiary road | Noise | NoiseSmokeRenderer | 58 dB, 2.5pt |
| Residential street | Noise | NoiseSmokeRenderer | 52 dB, 2pt |
| Service road | Noise | NoiseSmokeRenderer | 47 dB, 1.5pt |
| Elementary school | Schools | MKMarkerAnnotationView | Green, graduationcap.fill |
| Emergency shelter | Housing | MKMarkerAnnotationView | Teal, house.fill |
| Transitional housing | Housing | MKMarkerAnnotationView | Teal, house.fill |
| Permanent supportive | Housing | MKMarkerAnnotationView | Teal, house.fill |
| Odor zone | Air Quality | MKPolygon | Brown, 30% opacity |

### Always Visible

| Object | Layer | Rendering | Notes |
|--------|-------|-----------|-------|
| User pin | All | MKMarkerAnnotationView | Red, mappin icon |

---

## Counts by Tier

| Tier | New Objects | Cumulative |
|------|-------------|------------|
| Satellite / State | 0 | 0 |
| County | 9 | 9 |
| City | 11 | 20 |
| Neighborhood | 14 | 34 |
| Always | 1 | 35 |
