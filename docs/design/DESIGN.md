# Design System v2: Jelajah Taman — "Sunlit Field Guide"

> **v2, 2026-11-12.** Replaces v1 ("field journal", amber CTA, no mascot). The app in `lib/` follows this file. Source of truth for tokens: `lib/core/theme/app_theme.dart` (`JT`, `JTText`) and the widgets in `lib/core/ui/`. Visual baselines of every screen: `test_goldens/baselines/*.png` (see §10). The v1 Stitch prompts and `screens/` mock-ups are kept for history only.

## 1. Visual Theme & Atmosphere
**"A sunny, friendly field guide that still behaves like a safety instrument."** The mood is late-morning sun over the Dago Pakar pines: a warm yellow band at the top of the screen, a cream page below, forest-green actions. It is playful in the chrome (mascot, doodles, one coloured word per headline) and calm in the information (big readable numbers, short copy, nothing operational).

References: `tmp/designs/` (Sliq: cream page, yellow header, wavy cloud edge, doodle pattern, oversized headline with one coloured word) and the Ahead screenshots (soft cards, floating pill navigation + round action button, mascot reacting to state).

Signature motifs:
1. **Sun header + canopy edge**: a yellow band (`SunHeader`) carrying a doodle pattern that drifts left to right in a seamless loop (no reset), ending in a white-rimmed scalloped edge (`CanopyEdge`) that breathes gently.
2. **Pako**: a pinecone mascot (from the Hutan Pinus) with a leaf sprout. It changes pose with the situation (see §5).
3. **Hand-drawn doodles**: 16 line icons on a 24-grid (pine, cave, deer, leaf, compass, headphones, footprints, sun, mountain, butterfly, bench, drop, map, sparkle, mushroom, binoculars), used as pattern, empty-state art and illustrated photo placeholders.
4. **Illustrated park map**: procedural contour hills, pine doodles, white-cased dashed footpaths, bubbly markers (no tiles until T05).
5. **Headline highlight**: one word of the main headline in green (`HighlightHeadline`), e.g. "Jelajahi Tahura, **lebih dekat**".

## 2. Colour Palette & Roles (`JT`)
| Token | Hex | Role |
|---|---|---|
| `cream` | #FFF6E3 | page background |
| `creamDeep` | #FBEBCB | segmented-control track, subtle fills |
| `surface` | #FFFDF8 | cards, sheets, inputs |
| `line` | #EDE3CC | 1 px dividers and borders |
| `sun` | #F7C548 | header band, play button, walked trail, selected marker ring |
| `doodle` | #DDA52A | doodles on the sun band |
| `forest` | #1E5A3A | **primary action** (white label, ~8:1), active nav, route line |
| `forestBright` | #2F7A50 | highlighted headline word, positive numbers |
| `mint` | #E4F2E2 | secondary buttons, nav indicator, info cards |
| `ink` | #1C1B16 | text and icons (never pure black) |
| `muted` | #6D685B | secondary text |
| `terracotta` | #E0573B | closing-time reminder and destructive actions only |
| `sky` | #3F86C6 | visitor's dot (map convention) |
| `dusk` | #0F2A1E | Mode dengar and QR scanner background |

Category tints (always paired with an icon): sejarah #B0683A, alam #3E8A4F, rekreasi #2B8A85, fasilitas #5B6B7A.

## 3. Typography (`JTText`)
- **Display/headlines:** **Bricolage Grotesque** (bundled variable font, family `Bricolage`), 700–800, tight tracking. `hero` 40, `display` 34, `h1`–`h3`.
- **UI/body:** **Plus Jakarta Sans** (family `Jakarta`), body 16/24, never below 13 for captions.
- **Numbers:** `JTText.number()` = Bricolage with tabular figures (distance, ETA, steps, times).
- Fonts are bundled in `assets/fonts/` (offline, A01). Text scale 1.0 / 1.15 / 1.3 in Settings on top of the system scale.

## 4. Components (`lib/core/ui/components.dart`)
**Flat, no shadows.** Depth comes from colour (cream page, surface cards, mint secondary), borders and the sun band, never from drop shadows.
- `PrimaryPill`: 58 dp pill, forest fill, white label, optional icon. One per screen.
- `SoftButton`: 54 dp pill, mint fill, ink label.
- `CircleIconButton`: 48 dp flat disc with tooltip.
- `SkipChip`, `ChipToggle` (category/interest chips with pop + haptic), `Pill` (meta labels), `JTCard` (22 dp radius surface), `PageDots`, `AnimatedCount`, `SectionHeader`, `Grabber`, `showJTSheet`.
- Visuals (`visuals.dart`): `SceneImage` (photo, or an illustrated duotone landscape in the category tint: sky, haloed sun, cloud, three hills with pines, and the place's doodle as a white stamp; same ratio, so a real photo simply replaces it), `Waveform`, `Sparkline` (route elevation), `LeafConfetti`, `PulseRings`.
- Motion (`motion.dart`): `Pressable` (spring scale 0.96 + selection haptic), `Entrance` (delayed fade/slide/scale).
- Place widgets (`shell/src/ui/widgets.dart`): `PlaceCard` (polaroid: inset photo + category pill, white footer with name, walk meta, mint arrow), `PlaceTile` (thumbnail with `VisitedTick`, `CategoryLabel` eyebrow in the category tint, `MatchText` name with the search match on sun yellow, `WalkMeta`, chevron or custom trailing), `StatStrip` (icons under each value).
- Home: start card as a **trail ticket** (sun-tinted stub, perforated tear line with side notches, one doodle layer across both halves fading left, honest "Selesai ±12.54, sebelum tutup" check, stats with icons); closing time as a **sun arc** (dashed day path, sun at now, Buka/Tutup times); "Cari tempat lain" as a mint doodle card with Pako peeking from the corner.
- Map (`lib/modules/map`, R5): `ParkMapView`, `MapPin`, `ParkMapController` (fit, move, eased glide), `PlaceMarker`, `UserDot`. Facilities appear from zoom 16.9 so they never cover POI labels.
- Radii: 22 cards, 30 sheets, full pills. Touch targets ≥ 48 dp. Gutter 20 dp.

## 5. Pako (mascot, `mascot.dart`)
CustomPainter vector with random blinking, breathing loop, elastic pop on pose change and eyes that can follow a point. Poses and where they appear:
| Pose | Used on |
|---|---|
| `wave` | welcome intro (large, then glides into the onboarding header), returning-visitor splash, home header |
| `curious` | trigger card, search header |
| `navigate` (holds a map) | onboarding permissions, recommendation sheet |
| `listen` (headphones, music notes) | Mode dengar while playing |
| `cheer` | arrived, session summary |
| `thinking` | empty search, settings |
| `sleepy` (Zs) | closing reminder, "Kembali ke gerbang" |
| `drink` (bottle) | hydration reminder |
| `idle` | elsewhere |

## 6. Motion
Durations 120 / 220 / 360 / 600 ms (`JTMotion.fast/base/slow/lazy`), list stagger 40 ms, emphasized ease-out curves, elastic "pop" for markers and badges. Page transitions: fade-through, slide (detail, settings) and rise (Mode dengar, QR, arrived, summary). Ambient loops: doodle drift (left to right, 7 dp/s, wraps after one 8-column period so it never jumps), canopy breathing, Pako breathing/blink, waveform breathing, geofence pulse, route draw-on. `MediaQuery.disableAnimations` → loops stop, entrances skip.

## 7. Screens (route → content)
| Route | Screen | PRD |
|---|---|---|
| `/` | Returning visitors: rising sun, Pako wave, letter-by-letter wordmark. First run: plain sun-yellow hand-off to `/welcome` | — |
| `/welcome` | Welcome screen that **waits for the visitor**: full-screen sun band, large Pako, doodle burst that keeps floating with parallax, typed speech bubble "Halo, saya Pako!", greeting "Sampurasun! Selamat datang di Jelajah Taman", button "Ayo, mulai". No hint text. Pako's eyes follow the finger; tapping Pako makes him cheer, hop and say a new line. "Ayo, mulai" (or a tap anywhere) folds the band into the header, Pako hops and glides into page 1, then the pages rise in. Pages: "Tarik napas, mulai melangkah" (photo cards fan out beside Pako), "Biarkan hutan bercerita", permissions "Siapkan diri, kita berangkat" (band shrinks for room). Text is centred in the space below the band; "Lewati"/"Nanti saja" share one slot under the button | UI01 |
| `/setup` | Interests (2 steps, progress) → route cards with elevation sparkline + "selesai sebelum 16.00" check | UI01 |
| `/home` tab Beranda | Greeting + status pills, start/active-session card, time-to-close bar, route highlights carousel, nearest facilities | UI02 |
| `/home` tab Peta | Illustrated map, nearest strip, marker preview (Navigasi / Detail / Saya di sini) | UI03 |
| overlay | Approaching banner, trigger card, closing + hydration reminders, recommendation sheet | UI04, UI05, UI08, UI13 |
| `/poi/:id` | Parallax gallery (Hero), meta, audio card, safety note, short observational text, facts | UI06 |
| `/play/:id` | Mode dengar: dusk screen, big controls, waveform | UI07 |
| `/home` tab Cari | "Mau ke mana hari ini?" with Pako peeking at the field (thinking when nothing matches); pinned field (mint search disc that turns forest on focus) + category chips, hairline once scrolled; "Cepat temukan" quick finds (toilet, musala, saung, gua with nearest distance); results header ("Semua tempat 21" / "5 hasil untuk “gua”", terdekat dulu); rows with highlighted match and a navigate button; empty state card with suggestion chips | UI09 |
| `/navigate` | Instruction card, route drawn on, remaining distance/time/arrival, "Mulai jalan" | UI10 |
| `/arrived` | Large photo straddling the sun edge, short description, steps/km/closing pills, listen or next | UI11 |
| `/scan` | QR viewfinder (animated corners, scan line), weak-signal note, codes for the caves | UI12 |
| `/summary` | Counters, walked line on a mini map, visited / next time, on-device note | UI14 |
| `/settings` | Guide, health, display, privacy; collapsed "Mode demo" panel | UI15 |

## 8. Content & Copy
- Bahasa Indonesia, warm-formal, "Anda". Onboarding copy sells the experience (air, pines, stories, walking), not the feature list or how it works. Visitor-facing only: **no radius, GPS accuracy, coordinates, DUMMY labels or debug text in the UI.** The one exception is the collapsed "Mode demo" panel in Settings.
- Place text: until the survey/manager text exists (`[ISI]`), POIs show `draft_text`: observational copy without historical claims (PRD §8.2). Never invent history.
- Photos: survey photos 7 Nov 2026 (`assets/images/`, metadata stripped); credit line "Foto: dokumentasi tim Jelajah Taman". POIs without a photo use the illustrated placeholder.
- Number formatting: 1.722 langkah · 1,2 km · 16.00 · 37 mnt.

## 9. Anti-patterns
- Drop shadows on components and buttons; neon glows; gradient text.
- Emojis (use doodles or line icons).
- Operational/back-end detail in visitor copy (see §8).
- Out-of-scope UI: accounts, social, tickets, AR, SOS (NG01–NG07).

## 10. Visual baselines
`test_goldens/screens_golden_test.dart` renders 30 screens/states at 390×844 (incl. two welcome frames, lower Home, search results) and 11 at 360×780 with mock data and a fixed clock. Not run in CI (pixels differ per OS).
```bash
flutter test test_goldens --update-goldens   # regenerate after a UI change
flutter test test_goldens                    # diff against the saved baselines
```
