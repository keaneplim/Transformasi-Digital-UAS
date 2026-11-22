# 0008 Bundled Vector Basemap instead of MBTiles Raster Tiles

Status: Accepted

Date: 2026-11-12

Scope: offline map (A01), `map` module, map data pipeline

## Context

The PRD technology section specifies an offline OpenStreetMap map packaged as **MBTiles** raster tiles. Bulk-downloading OSM raster tiles conflicts with the OSM tile usage policy, raster tiles for the needed zoom range are large, and their styling cannot match the app's design system (ADR 0012). The map covers only zona Dago Pakar, a small area.

## Decision

The offline map is a **bundled vector basemap** generated from OSM data and a terrain model:

- `assets/map/basemap.json`: vector layers (landcover, water, waterways, roads, paths, buildings, Tahura boundary, 10 m contours, labels);
- `assets/map/hillshade.png`: soft relief shading, georeferenced by bounds in the JSON.

Both are drawn by `flutter_map` layers in the `map` module in the app's own palette. Online **satellite imagery** (Esri) is available only as an optional layer that requires internet and degrades gracefully without it.

## Rationale

The approach is legal (no bulk tile download), small (about 2 MB for both files), styled to the design system, and sharp at any zoom.

## Alternatives Considered

- **MBTiles raster tiles (as in the PRD):** rejected for tile-policy, size and styling reasons.
- **Vector tiles (MVT) with a style engine:** rejected; heavier tooling and plugins for a single small area.
- **Online tiles with caching:** rejected; violates A01.

## Implementation Details

- Generator: `tools/osm_to_basemap.py`. Sources: OSM via the Overpass API (cached in `survey/raw/osm/`) and terrain from the Google Elevation API on a 20 m grid (key from the local `.env.local`), with a public SRTM fallback. Without `--refresh` the build is offline and deterministic.
- Attribution (© OpenStreetMap contributors, ODbL) is shown in the app.
- `flutter_map` and `latlong2` are owned by the `map` module only (rule R5).

## Consequences

Refreshing the map is a script run, not a tile download. The PRD stack line (MBTiles) is out of date and needs a Change Log entry (PROGRESS #26).

## Validation

The map renders in airplane mode (PB05, TC-13); golden screens cover the map views.

## Risks

Raw Google Elevation responses may not be stored in the repository (their terms); they stay local and are regenerable.

## Follow-up

Add the PRD Change Log entry replacing MBTiles with the bundled vector basemap (docx → pdf → PRD.md, slide 13).
