# SURVEY CHECKLIST — Tahura Djuanda, zona Dago Pakar

One survey trip has to produce everything the app needs, so a second trip isn't required before W12. Every output below replaces a DUMMY value in `assets/content/` or closes a Lampiran B item.

## What this trip must produce

| Output | Replaces / closes | Used by |
|---|---|---|
| Coordinates of P01–P11 and FS01–FS05 (3 readings each, with accuracy) | DUMMY `lat/lng` in `pois.json`, `facilities.json`; Lampiran B #2 | F01, F02, F05, F06 |
| Confirmation that each POI exists and where the zone ends (Museum, Kolam Pakar, Penangkaran Rusa, Koleksi Flora, **Curug Omas inside NG02?**) | Lampiran B #1; PROGRESS #13 | Scope |
| GPX tracks of every trail segment, with junctions marked | DUMMY `trail_graph.json`; PB12 | F06, F08 |
| Timed walks per segment | ETA calibration (D09), route durations | F06 AC6, F08 |
| Route lengths and elevation for Santai / Sedang / Trekking | DUMMY `routes.json`; Lampiran B #3 | F08, TC-11 |
| Photos (own) of every POI | `images` | F03 |
| Photos of every signboard (the source of facts) | `sources`, narration scripts; Lampiran B #5 | F03, PB08 |
| Opening hours + ticket info, photographed or asked at the counter | `park.json hours.verified`; Lampiran B #4 | A03, F07 |
| GPS quality at canopy, valley, cave mouths, inside caves | radius calibration; Lampiran B #8 | F02, A02 |
| Permission answer for QR boards (permanent/temporary) | Lampiran B #6 | A02 |
| Replay tracks for desk testing (see §5) | `test_data/gpx/` | everyone's tests |

## 1. Before leaving (tonight)

- [ ] Weather check, plus a backup date in case of heavy rain.
- [ ] All phones charged to 100%; 2 power banks; cables.
- [ ] GPX app installed and tested on ≥2 phones (iPhone: OsmAnd or Open GPX Tracker; Android: GPSLogger or OsmAnd). Logging interval **1 s**, high accuracy, elevation on.
- [ ] Offline map of the area downloaded in the GPX app (signal is unreliable).
- [ ] Printed or offline copy of this checklist and the POI table (PRD §4.1).
- [ ] Data sheet ready: Google Sheet (works offline) or paper. Columns: `id, name, reading_no, lat, lng, accuracy_m, time, device, note`.
- [ ] Torch/headlamp for the caves; drinking water; ticket money.
- [ ] Permission/introduction letter from the PM if you have one (for the manager and for QR placement questions).
- [ ] Roles assigned (5 people):

| Role | Does |
|---|---|
| **GPS lead** | Point readings for every POI/facility (§2), keeps the data sheet |
| **Trail recorder** | Records GPX continuously (§3), marks junctions, keeps segment times |
| **Photographer** | POI photos + every signboard (§4) |
| **Content & interview** | Reads/photographs signboards, asks staff/manager: hours, history sources, rusa/museum status, QR permission |
| **QA / replay** | GPS quality notes, records the replay tracks (§5), notes where GPS goes weak |

## 2. Point readings (POIs and facilities)

For each P01–P11 and every facility you find (toilets, musala, warung, pos petugas, benches/rest points):
1. Stand at the **trigger point**:
   - caves (P05, P06): at the cave mouth, outside;
   - buildings (P03): at the entrance;
   - large areas (P08, P09): at the centre of where visitors gather;
   - P01: at the ticket gate.
2. Wait **30 s** for the fix to settle.
3. Take **3 readings** about 10 s apart. Write down lat, lng, **accuracy (m)**, time and device.
4. For large areas, also walk the rough edge and note its approximate size. This feeds the 40 m radius decision.
5. Note anything that affects the trigger: two POIs close together (e.g., Monumen and Museum), a POI that is off the trail, poor sky view.
6. **Facilities:** record every one you see, even if there are more than five. Give extra toilets new IDs (FS06, …).

## 3. Trail GPX (the trail graph depends on this)

1. Start recording at the gate and **don't stop** between segments (one long track is fine; separate files per segment are fine too).
2. At every **junction** (where paths split), drop a waypoint named `J01`, `J02`, … and write on the sheet which directions lead where.
3. Walk **every path segment visitors can use** between POIs and facilities, including the loop and spur paths. If time allows, walk the main segments **in both directions**; uphill vs downhill times are what calibrate the slope correction.
4. Walk at a **normal visitor pace**. Write down the start and end time of each segment, and subtract stops (photos, interviews).
5. Mark which segments belong to Santai / Sedang / Trekking as staff or signboards describe them. If no official routes exist, note that; the team then defines them (Change Log).
6. Curug Omas: only walk there if it's realistic. Note the distance and time from the cave area and whether it's inside the Dago Pakar zone. This decides PROGRESS #13.

## 4. Photos and sources

- 3 photos per POI: wide context, the main object, one detail. Landscape orientation, natural light, **no identifiable faces** without consent.
- **Photograph every signboard in full and in readable focus.** These are the only acceptable sources for history and nature facts (PRD §8.2: no fact from AI alone).
- Photograph the opening hours / tariff sign at the gate.
- Name files on the spot or right after: `p05_1.jpg`, `p05_sign_1.jpg`, `fs01_1.jpg`, `gate_hours.jpg`.

## 5. Replay tracks for desk testing

Record these as separate GPX files; they let the coders test without coming back:
- [ ] `walk_in_out_P04.gpx`: start ~100 m away, walk into P04, stop 1 min, walk out ~100 m (TC-02).
- [ ] `linger_P08.gpx`: walk into Hutan Pinus and wander inside the radius for 3+ min (TC-03).
- [ ] `reenter_P02.gpx`: enter P02, leave ~50 m, come back within 5 min (cooldown test).
- [ ] `cave_P05.gpx`: approach the Gua Jepang mouth, go inside a few metres, come out (GPS-weak + QR banner).
- [ ] `detour.gpx`: on a navigation leg, deliberately leave the trail by more than 30 m for 1 min, then rejoin (TC-08 reroute).
- [ ] `santai_full.gpx`: the whole Santai route in one recording (the W12 demo replay).

## 6. GPS quality notes

At each of these, note the accuracy shown and the satellite count: open area at the gate, under the pine canopy, in the valley near Kolam Pakar, at each cave mouth, 5 m inside each cave (expect no fix — write "no fix" and the time it took to recover outside).

## 7. Questions for staff / the manager

- [ ] Opening and closing time (weekday/weekend); last entry time; ticket price. *(Lampiran B #4)*
- [ ] Do Museum Ir. H. Djuanda, Penangkaran Rusa and a labelled plant collection exist and are they open? *(Lampiran B #1)*
- [ ] Official sources for the history of Gua Jepang, Gua Belanda and the monument (brochure, website, document). *(Lampiran B #5)*
- [ ] May we place temporary QR boards at the cave mouths during testing (W14)? Is permanent placement possible? *(Lampiran B #6)*
- [ ] Are there official route names or distances (signboards, maps)?

## 8. After the trip (same evening)

1. Upload raw data to the team Drive: `survey/2026-11-07/{gpx,photos,signboards,sheet}`.
2. Commit **small files** to the repo: GPX in `survey/raw/2026-11-07/`, the data sheet as `survey/raw/2026-11-07/points.csv`, replay tracks in `test_data/gpx/`. Keep the original photos on Drive; only curated, resized photos (WebP ≤1280 px) go into `assets/images/`.
3. Average the 3 readings per point (drop an obvious outlier) and update `pois.json` / `facilities.json`. Remove `"coord_source": "DUMMY"` from each record you replace, and set the file-level `"dummy"` to `false` only when every record in that file is real.
4. Build the real `trail_graph.json` (owner B), **after** step 3 so POIs attach at their real positions:
   ```bash
   python tools/gpx_to_graph.py survey/raw/2026-11-07/ --update-routes
   ```
   - Pass **only the trail GPX**, never `test_data/gpx/` (the `detour.gpx` replay would become a fake trail).
   - Open `build/gpx_to_graph/preview.geojson` on https://geojson.io and check it against the sheet: every junction there, no fake shortcuts, red attach lines = POIs > 25 m from a trail.
   - Every `WARNING`/`ERROR` is a question for the survey team **tonight**, while a second visit is still possible: "P07 is 40 m from any trail" = wrong coordinate or a path not recorded; "E01: trail ends without a POI" = unfinished recording or a real dead end; "P11 not connected to the gate" = a missing segment.
   - `--update-routes` rewrites `node_path`, `distance_m`, `ascent_m` in `routes.json`; `duration_min` stays as surveyed.
5. Run `python tools/validate_content.py` and fix every error.
6. Update PROGRESS.md: which Lampiran B items are closed, what is still `[VERIFIKASI]`, and whether Curug Omas stays in scope.
7. Once all content is real, delete `tools/make_dummy_data.py` so nobody regenerates dummy data over the survey data.
