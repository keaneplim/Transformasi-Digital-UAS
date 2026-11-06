# Design System: Jelajah Taman — Tahura Ir. H. Djuanda

## 1. Visual Theme & Atmosphere
**"A field journal that became a navigation instrument."** The mood is early-morning light falling through the pine canopy of Dago Pakar: calm, airy, grounded. Deep forest greens carry the structure; a single warm sunlit amber marks what matters right now. It must feel trustworthy inside a forest (safety, closing time, offline), readable in harsh daylight, and usable one-handed while walking — or with the phone in a pocket.

- **Density 4 — Daily App Balanced.** Map-first; information lives in bottom sheets, never in crowded panels.
- **Variance 5 — Offset, but predictable chrome.** Editorial, left-aligned headers and photography break the grid; navigation controls stay in the same place on every screen (this is a safety tool).
- **Motion 5 — Fluid, purposeful.** Motion communicates location state (approaching, triggered, arrived). Never decorative.

**Signature motifs (what makes it unmistakably Tahura):**
1. **Topographic contour lines** — fine contour-map linework (Tahura's valley terrain) as a 4–6% opacity texture on headers, empty states, and the session summary.
2. **Geofence rings** — every POI marker radiates its real trigger radius as a thin ring, with a fainter outer ring for the "approaching" zone. Rings pulse when the user is near.
3. **Elevation profile sparklines** — every route and navigation leg shows its climb/descent as a small terrain line.
4. **Documentary photography** — real places: the stone mouth of Gua Jepang, the long lit tunnel of Gua Belanda, light shafts in the pine forest, the Ir. H. Djuanda monument.

## 2. Color Palette & Roles
One green-tinted neutral family throughout — never mixed with cool blue-grays.

**Neutrals**
- **Mist Canvas** (#F3F5F0) — app background
- **Pure Surface** (#FFFFFF) — bottom sheets, cards, inputs
- **Pine Ink** (#15211B) — primary text and icons (never pure black)
- **Moss Gray** (#5F6B64) — secondary text, metadata, labels
- **Lichen Line** (#DCE3DA) — 1px dividers and borders
- **Canopy Deep** (#1E4634) — dark brand surfaces: Now Playing, header bands, navigation route line
- **Canopy Night** (#0F1A15) — Cave Mode background

**Single accent**
- **Sunlit Amber** (#D99A2B) — the one primary CTA per screen, the active/triggered POI, played portion of audio. Pressed state #C4871F. **Labels on amber are always Pine Ink, never white** (contrast).

**Functional semantics (only for status, never decoration)**
- **Trail Green** (#3E8A5B) — GPS good, arrived, completed
- **Clay Red** (#B5482B) — GPS weak, closing-time warning, errors
- **Position Blue** (#2F6FB0) — user location dot and accuracy circle only (map convention)

**POI category tints** (marker fills; always paired with an icon, never color alone)
- **Sejarah** — Heritage Stone (#8B6B47)
- **Alam / Flora-Fauna** — Fern (#4F7D4B)
- **Wellness / Rekreasi** — Spring Teal (#3B7C78)
- **Fasilitas** — Slate Post (#5A6670)

All text ≥ 4.5:1 contrast. Outdoor-first: prefer Pine Ink on Pure Surface for anything read while walking.

## 3. Typography Rules
- **UI & Headlines:** **Plus Jakarta Sans** (a Jakarta-made typeface) — 500/600/700. Headlines tracked tight (-0.02em). Screen title 24/30 semibold; section title 18/24 semibold.
- **Editorial accent:** **Fraunces** 600 — ONLY for POI names on the POI Detail hero and trigger card, and the Home greeting. Never in buttons, navigation, or data.
- **Data:** **JetBrains Mono** (tabular) — distances, ETA, steps, durations, timers, GPS accuracy ("±8 m"), times ("16.00").
- **Body:** 16/24, never below 14. Max ~65 characters per line. Supports text scaling up to 200%.
- **Banned:** Inter, default Roboto look, Times/Georgia/Garamond.

## 4. Component Stylings
- **Primary button:** full-width, 56dp tall, 16dp radius, Sunlit Amber fill, Pine Ink 16 semibold label. Pressed: scale 0.98 and darken. One per screen.
- **Secondary button:** Pure Surface, 1px Lichen Line border, Pine Ink label. **Tertiary:** text-only in Canopy Deep.
- **Bottom sheet:** 28dp top radius, centered grabber, Pure Surface, soft green-tinted shadow (0 -8 24, rgba(21,33,27,0.10)). Snap states: peek (stats), half (list), full.
- **Map markers:** 40dp circle in category tint, 1.5dp white stroke, white 20dp line icon. Unvisited = solid; visited = solid with small Trail Green check badge; triggered/active = Sunlit Amber halo. Trigger radius = thin dashed ring in the category tint; approaching zone = fainter outer ring.
- **User location:** 16dp Position Blue dot, 3dp white ring, translucent accuracy circle, heading cone.
- **Status chips:** 28dp pills. "GPS baik · ±8 m" with Trail Green dot; "GPS lemah · ±45 m" with Clay Red dot; "Offline" with cloud-off icon in Moss Gray — offline is the normal state, styled neutral, not as an error.
- **Session stats strip:** 3–4 cells; value in JetBrains Mono 20, label 12 Moss Gray uppercase (+0.04em). Separated by 1px dividers — no cards.
- **POI list row:** 72dp photo thumbnail (16dp radius) left; name, category chip; distance + ETA in mono right-aligned; chevron.
- **Audio player:** bar-waveform scrubber (Canopy Deep bars, Sunlit Amber played portion), 72dp round play/pause, ±10 s skip, elapsed/total in mono.
- **Search field:** 52dp, 16dp radius, leading search icon, clear button; category filter chips below (horizontally scrollable).
- **Icons:** 24dp line icons, 1.75 stroke, rounded caps (Phosphor/Lucide style). **No emojis.**
- **Loading:** skeleton shimmer matching layout. **Empty states:** contour-line illustration + one helpful sentence + action.
- **Corner radii:** 16dp default, 24dp large media, 28dp sheets.

## 5. Layout Principles
- Mobile 360–412dp width; 20dp side margins; 8dp spacing scale (8/12/16/24/32/48).
- **Map-first:** Explore and Navigation use a full-bleed map with a floating top bar and a bottom sheet; the sheet's default state never covers more than ~45% of the map.
- **Thumb zone:** primary actions in the bottom third; the top area is for status (GPS, offline, time to close).
- Touch targets ≥ 48dp. Respect safe areas.
- No 3-equal-card rows. Route chooser = stacked selectable cards with elevation sparklines.
- Editorial headers are left-aligned; nothing overlaps text.

## 6. Motion & Interaction
- Spring physics (stiffness 100, damping 20) for sheets and cards; no linear easing.
- **Approaching:** POI geofence rings pulse (1.6 s loop); distance counts down live.
- **Trigger:** card rises from the bottom (scale 0.96 → 1) in sync with the haptic.
- **Now Playing:** waveform breathes gently while audio plays.
- Lists stagger in at 40 ms intervals. Animate transform/opacity only. Respect reduced-motion.

## 7. Modes
- **Light (default):** for daylight outdoors.
- **Cave Mode (dark):** used inside caves / GPS weak / QR scanner — Canopy Night background, Pure Surface text, amber accents. Less glare in the dark tunnel.
- **Eyes-Free / Now Playing:** Canopy Deep full screen with oversized controls.

## 8. Content & Copy
- All UI copy in **Bahasa Indonesia**, warm-formal, addressing the user as "Anda". Short, direct.
- Use real place names: Gerbang Dago Pakar, Monumen Ir. H. Djuanda, Museum Ir. H. Djuanda, Kolam Pakar, Gua Jepang, Gua Belanda, Penangkaran Rusa, Kawasan Hutan Pinus, Area Rumput/Piknik, Titik Koleksi Flora, Curug Omas.
- Indonesian number formatting: 4.820 langkah · 3,1 km · 08.00–16.00 · ±12 mnt.
- Photography: natural light, documentary, slightly muted — no posed stock models, no oversaturated HDR greens.

## 9. Anti-Patterns (Banned)
- Emojis anywhere (the wireframes use them — replace with line icons)
- Inter font; pure black #000000; white text on amber
- Neon glows, purple/blue gradients, gradient text, heavy glassmorphism over the map (floating chips may use a 92%-opaque surface with light blur only)
- Cartoon jungle illustrations, wood/leaf skeuomorphic textures, oversaturated "app-store green"
- Centered marketing-style hero on Home; 3 equal cards in a row
- Lorem ipsum, generic names, AI clichés ("Jelajahi tanpa batas", "pengalaman seamless", "next-gen")
- Out-of-scope UI: login/sign-up, profiles, social feed, sharing, leaderboards, ticket purchase, AR, SOS button (PRD NG01–NG07)
