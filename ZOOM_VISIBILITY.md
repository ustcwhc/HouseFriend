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

## Visibility by Layer

### Population

| Object | Rendering | Visible At | Notes |
|--------|-----------|------------|-------|
| ZIP polygon (unselected) | MKPolygon | **County** | Yellow border, 445 ZIPs |
| ZIP polygon (highlighted) | MKPolygon | **County** | Pink fill + pink border |
| ZIP code label | MKAnnotationView | **County** | White background, shows ZIP ID |

### Crime

| Object | Rendering | Visible At | Notes |
|--------|-----------|------------|-------|
| Heatmap tile | MKTileOverlay | **City** | Gaussian model, auto-cached |
| Violent crime marker | MKMarkerAnnotationView | **Neighborhood** | Purple, clickable |
| Property crime marker | MKMarkerAnnotationView | **Neighborhood** | Cyan, clickable |
| Vehicle crime marker | MKMarkerAnnotationView | **Neighborhood** | Orange, clickable |
| Vandalism marker | MKMarkerAnnotationView | **Neighborhood** | Brown, clickable |
| Other crime marker | MKMarkerAnnotationView | **Neighborhood** | Gray, clickable |

### Noise

| Object | Rendering | Visible At | Data Source | Notes |
|--------|-----------|------------|-------------|-------|
| Motorway | NoiseSmokeRenderer | **City** | Static bundle | 78 dB, 5pt, dark smoke |
| Trunk road | NoiseSmokeRenderer | **City** | Static bundle | 74 dB, 5pt |
| Primary road | NoiseSmokeRenderer | **City** | Static bundle | 68 dB, 4pt |
| Heavy rail (Caltrain, freight) | NoiseSmokeRenderer | **City** | Static bundle | 75 dB, 4pt, dashed |
| Light rail / subway (BART, VTA) | NoiseSmokeRenderer | **City** | Static bundle | 70 dB, 3.5pt, dashed |
| Secondary road | NoiseSmokeRenderer | **Neighborhood** | Overpass API | 63 dB, 3pt |
| Tertiary road | NoiseSmokeRenderer | **Neighborhood** | Overpass API | 58 dB, 2.5pt |
| Residential street | NoiseSmokeRenderer | **Neighborhood** | Overpass API | 52 dB, 2pt |
| Service road | NoiseSmokeRenderer | **Neighborhood** | Overpass API | 47 dB, 1.5pt |

### Schools

| Object | Rendering | Visible At | Notes |
|--------|-----------|------------|-------|
| High school | MKMarkerAnnotationView | **County** | Purple, graduationcap.fill |
| Middle school | MKMarkerAnnotationView | **City** | Blue, graduationcap.fill |
| Elementary school | MKMarkerAnnotationView | **Neighborhood** | Green, graduationcap.fill |

### Earthquake

| Object | Rendering | Visible At | Notes |
|--------|-----------|------------|-------|
| Major quake (M >= 5.0) | MKMarkerAnnotationView | **City** | Red, magnitude text |
| Moderate quake (M >= 4.0) | MKMarkerAnnotationView | **City** | Orange |
| Minor quake (M < 4.0) | MKMarkerAnnotationView | **City** | Yellow |

### Fire Hazard

| Object | Rendering | Visible At | Notes |
|--------|-----------|------------|-------|
| Extreme zone | MKPolygon | **County** | Dark red, 50% opacity |
| Very High zone | MKPolygon | **County** | Orange-red, 42% opacity |
| High zone | MKPolygon | **County** | Golden, 35% opacity |
| Moderate zone | MKPolygon | **County** | Yellow, 28% opacity |

### Electric Lines

| Object | Rendering | Visible At | Notes |
|--------|-----------|------------|-------|
| 115 kV transmission line | MKPolyline | **County** | Yellow, 2.5pt |
| 60 kV transmission line | MKPolyline | **County** | Yellow, 2.5pt |

### Superfund

| Object | Rendering | Visible At | Notes |
|--------|-----------|------------|-------|
| NPL / Active / Proposed site | MKMarkerAnnotationView | **City** | Orange, triangle icon |

### Supportive Housing

| Object | Rendering | Visible At | Notes |
|--------|-----------|------------|-------|
| Emergency shelter | MKMarkerAnnotationView | **Neighborhood** | Teal, house.fill |
| Transitional housing | MKMarkerAnnotationView | **Neighborhood** | Teal, house.fill |
| Permanent supportive | MKMarkerAnnotationView | **Neighborhood** | Teal, house.fill |

### Air Quality / Odor

| Object | Rendering | Visible At | Notes |
|--------|-----------|------------|-------|
| Odor zone | MKPolygon | **Neighborhood** | Brown, 30% opacity |

### Global

| Object | Rendering | Visible At | Notes |
|--------|-----------|------------|-------|
| User pin | MKMarkerAnnotationView | **All levels** | Red, mappin icon |
