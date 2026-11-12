# Stitch Prompts — Jelajah Taman

> **Outdated (2026-11-12).** These prompts describe design v1 (amber CTA, no mascot). The app now follows [DESIGN.md](DESIGN.md) v2 "Sunlit Field Guide"; current screens are in `test_goldens/baselines/`. Kept for history only. Issue #18 (unsourced "WWII-era" wording) still applies if the prompts are ever reused.

How to use:
1. In Stitch, create a new project and choose **App (mobile)**.
2. Open the theme settings and set: font **Plus Jakarta Sans**, primary color **#D99A2B**, corner radius **medium/large (16dp)**, light mode.
3. Paste **Prompt 0 (Master)** first. It sets the design language and generates the Home screen.
4. Then paste the screen prompts **one at a time**, in order, in the same project. Change one screen per prompt; if a result drifts, reply with a short correction ("keep the same palette and fonts as Home; remove the emojis").
5. Optional: upload `figures/fig_wire_a.png` / `fig_wire_b.png` together with the matching prompt as a layout reference, adding: "Use this wireframe only for layout; follow the design system for style and replace every emoji with a line icon."

Full design system: [DESIGN.md](DESIGN.md).

---

## Prompt 0 — Master (design language + Home screen)

```
Design a premium Android mobile app called "Jelajah Taman": an offline, location-based exploration guide for Taman Hutan Raya Ir. H. Djuanda (Tahura Djuanda), zona Dago Pakar, Bandung, Indonesia, a pine-forest conservation park with Japanese and Dutch WWII-era caves, a monument, and forest trails. When a visitor walks near a point of interest, the app vibrates, shows a notification, and plays an audio story. It also offers trail navigation, a "next place" recommendation that respects the 16.00 closing time, and a Wellness Trail mode that tracks steps, distance and duration. All UI text is in Bahasa Indonesia.

VISUAL DIRECTION: "a field journal that became a navigation instrument". Calm, airy, grounded, like morning light through a pine canopy. Premium national-park field guide, not a generic travel app. Readable in bright sunlight and usable one-handed while walking.

COLORS: background Mist Canvas #F3F5F0; surfaces Pure White #FFFFFF; primary text Pine Ink #15211B (never pure black); secondary text Moss Gray #5F6B64; dividers Lichen Line #DCE3DA; dark brand surface Canopy Deep #1E4634. ONE accent only: Sunlit Amber #D99A2B, used for the single primary button per screen and the active point of interest; button labels on amber are Pine Ink, never white. Status: Trail Green #3E8A5B (GPS good, arrived), Clay Red #B5482B (GPS weak, closing-time warning). Category marker colors: Sejarah #8B6B47, Alam #4F7D4B, Wellness #3B7C78, Fasilitas #5A6670.

TYPE: Plus Jakarta Sans for UI and headlines (tight tracking, semibold). Fraunces serif ONLY for place names in hero moments. JetBrains Mono for all numbers (distance, ETA, steps, time, GPS accuracy).

SIGNATURE DETAILS: subtle topographic contour-line texture (5% opacity) on headers; POI map markers show their trigger radius as a thin dashed ring; routes show a small elevation-profile sparkline; real documentary-style photography of the caves, pine forest and monument with natural, slightly muted color.

COMPONENTS: 16dp corner radius, 28dp top radius on bottom sheets, 56dp full-width primary buttons, 48dp minimum touch targets, 24dp line icons with rounded strokes, soft green-tinted shadows, 1px dividers instead of boxes where possible.

STRICT RULES: no emojis, no purple or neon gradients, no gradient text, no glow effects, no cartoon jungle illustrations, no login/sign-up/profile/social/ticket screens, no lorem ipsum, no 3 equal cards in a row.

SCREEN TO GENERATE: "Home - Pilih Minat & Rute". Top: left-aligned header over a soft pine-forest photo band with contour texture, small label "Tahura Djuanda · Dago Pakar", large greeting "Selamat pagi, siap menjelajah?" in Fraunces, and a status row with chips "Buka 08.00–16.00" and "Offline siap". Section "Minat Anda": selectable chips Sejarah (selected), Alam (selected), Wellness, each with a line icon. Section "Pilih Rute Wellness Trail": three stacked, selectable route cards. Santai: 2,5 km · ±2 jam · mudah · 6 POI, selected with amber border. Sedang: 4 km · ±3 jam · sedang. Trekking: 6 km · ±4 jam · berat · includes Curug Omas. Each card shows a mini elevation sparkline and a difficulty indicator. Above the button, a Trail Green confirmation line: "Rute Santai selesai sebelum jam tutup 16.00". Bottom: amber primary button "Mulai Jelajah". Settings gear icon top right.
```

---

## Prompt 1 — UI01 Onboarding & Izin

```
Same Jelajah Taman design system. Create the onboarding flow as 3 screens with a page indicator.
Screen 1: full-bleed documentary photo of the pine forest at Tahura with light shafts, bottom white sheet with title "Pemandu yang tahu di mana Anda berada" and one short sentence explaining that information appears automatically when you approach a place, even without signal.
Screen 2: illustration made of contour lines with a phone in a pocket and sound waves; title "Dengarkan sambil berjalan"; text about audio stories, vibration and voice directions, no need to keep looking at the screen.
Screen 3: "Izin yang kami perlukan", a vertical list of 4 permission rows, each with a line icon, name and one-line reason: Lokasi (to know when you arrive at a place), Notifikasi (to tell you when you arrive, even with the screen locked), Aktivitas fisik (to count steps), Kamera (to scan QR codes in the caves). Small privacy note: "Semua data tersimpan di ponsel Anda. Tanpa akun." Amber primary button "Izinkan & Lanjutkan", text button "Nanti saja".
```

## Prompt 2 — UI03 Explore Map (di luar area POI)

```
Same design system. Screen "Explore Map". Full-bleed offline topographic map of the Dago Pakar forest area: muted green terrain with contour lines and thin walking trails, the active "Santai" route drawn in Canopy Deep #1E4634. 10 POI markers as 40dp circles in their category colors with white line icons (cave, monument, museum, pond, deer, pine tree, picnic, plant, gate); two visited ones have a small green check badge; each shows a faint dashed trigger-radius ring. Small slate facility pins for toilet, musala and warung. The user's location is a blue dot with an accuracy circle and heading cone.
Floating top: search bar "Cari POI atau fasilitas" and below it two chips, "GPS baik · ±8 m" (green dot) and "Offline". Right side: floating recenter and layers buttons.
Bottom sheet in peek state: stats strip in JetBrains Mono, 1.240 langkah | 0,8 km | 0:25 durasi | POI 2/6, separated by thin dividers. Below: "Terdekat: Gua Jepang · 180 m · ±4 mnt" with a photo thumbnail and chevron. Bottom row: secondary button "Daftar POI" and text button "Akhiri Jelajah".
```

## Prompt 3 — UI04 Approaching

```
Same design system, same map as Explore Map. State "Approaching": the user is 45 m from Gua Jepang. The Gua Jepang marker is enlarged with its trigger ring and an outer approaching ring pulsing in Heritage Stone #8B6B47. Top banner card (white, 16dp radius, slides down): vibration icon, "Mendekati Gua Jepang", big mono number "45 m" with a direction arrow "di depan", and a thin progress line shrinking toward the ring. The bottom sheet stays in peek with the stats strip. The rest of the map is slightly dimmed to focus attention.
```

## Prompt 4 — UI05 POI Trigger (in-app + lock screen)

```
Same design system. Create 2 screens.
Screen A, in-app trigger: map dimmed behind; a large card rises from the bottom with an amber halo accent line on top: small label "Anda tiba di", place name "Gua Jepang" in Fraunces, category chip "Sejarah", a wide 16:9 documentary photo of the stone cave entrance, and the question "Ingin mendengar sejarahnya?". Buttons: amber primary "Dengarkan" with play icon (full width), then two secondary buttons side by side, "Lihat Detail" and "Nanti". Small line under the buttons: "Audio · 1:30".
Screen B, Android lock screen: clock "10.52", a rich notification from Jelajah Taman, "Anda tiba di Gua Jepang. Ingin mendengar sejarahnya?" with a small photo and action buttons "Dengarkan" and "Nanti"; below it, a lock-screen media player placeholder. Show that the app works without unlocking the phone.
```

## Prompt 5 — UI06 POI Detail

```
Same design system. Screen "POI Detail: Gua Jepang". Top: edge-to-edge photo carousel (3 photos, 24dp bottom radius) of the cave entrance and tunnel, with back button and page dots. Title "Gua Jepang" in Fraunces, category chip "Sejarah", and a mono meta line "±15 mnt kunjungan · 120 m dari Anda".
Audio player card: waveform scrubber (Canopy Deep bars, amber played portion), 72dp play/pause, rewind 10 and forward 10 buttons, "0:32 / 1:30" in mono, and a small "Mode Audio" button.
"Fakta kunci" as a 2-column definition list separated by dividers: Dibangun [tahun], Fungsi [fungsi], Lorong [jumlah], Kategori Sejarah (use clear placeholder brackets, not invented facts). Then a body paragraph of about 100 words of Indonesian history text.
A Clay Red safety callout with a flashlight icon: "Bawa senter, lorong gelap dan lantai licin." Small source line "Sumber: Pengelola Tahura". Sticky bottom amber button "Selesai, lihat berikutnya".
```

## Prompt 6 — UI07 Eyes-Free / Now Playing

```
Same design system, dark variant. Screen "Now Playing": full screen Canopy Deep #1E4634 background with a faint contour texture. Square photo of Gua Jepang with 24dp radius, title "Gua Jepang" in Fraunces (white), subtitle "Narasi sejarah · Sejarah". A large breathing waveform with an amber played portion, time in mono. Oversized controls built for walking: 96dp amber play/pause in the center, 64dp rewind-10 and forward-10. Toggle row: "Putar otomatis saat tiba" (on) and "Arahan suara" (on). Hint at the bottom: "Kontrol juga tersedia di layar kunci dan earphone." No small text below 14sp.
```

## Prompt 7 — UI08 Rekomendasi Berikutnya

```
Same design system. Screen: the map is behind, with a bottom sheet at half height titled "Berikutnya untuk Anda". Main recommendation card with an amber left accent: photo thumbnail, "Gua Belanda" in Fraunces, mono line "650 m · ±12 mnt · menurun", an elevation sparkline of the walk, and reason chips "terdekat" and "sesuai minat Sejarah"; amber primary button "Navigasi ke sini". Then "Alternatif" as 2 compact list rows: "Kawasan Hutan Pinus · 400 m · ±8 mnt · Alam" and "Penangkaran Rusa · 900 m · ±17 mnt · Fauna". A footer info row with a clock icon: "Sisa waktu s.d. tutup 3 j 10 m". Text buttons "Jelajah bebas" and "Cari lain". On the map, a dashed preview line toward Gua Belanda.
```

## Prompt 8 — UI09 Search

```
Same design system. Screen "Search". Top: back arrow and a focused search field containing "toil" with a clear button. Horizontally scrollable filter chips: Semua, Sejarah, Alam, Wellness, Fasilitas (Fasilitas selected in Canopy Deep with white text). A results header "2 hasil · diurutkan menurut jarak jalan kaki". Result rows with a slate facility icon tile, name, and right-aligned mono distance/ETA: "Toilet Dekat Gerbang · 120 m · ±3 mnt" and "Toilet Area Piknik · 480 m · ±9 mnt", each with a navigate arrow button. Below, a section "Pencarian populer" with chips "Gua", "Musala", "Warung", "Hutan Pinus". Small footnote "Pencarian berjalan tanpa internet". Also show the empty state as a second screen: a contour-line illustration, "Tidak ditemukan untuk 'kawah'", and the suggestion "Coba kategori:" followed by category chips.
```

## Prompt 9 — UI10 Navigation

```
Same design system. Screen "Navigation" to Gua Belanda. Top instruction card in Canopy Deep with white text: a large turn-left arrow icon, "60 m lagi" in mono, "Ambil jalur kiri (menurun)", and a speaker icon indicating voice guidance is on. Full-bleed map: the route follows the winding forest footpath (not a straight line) as a thick Canopy Deep line with a white casing, the walked portion faded, the destination marker in Heritage Stone with its trigger ring, and the user's blue dot with heading cone. Bottom sheet: "Gua Belanda" title, mono metrics row "520 m | ETA ±10 mnt | ▼ 25 m turun", an elevation profile of the remaining path with the current position marked, and a secondary button "Akhiri Navigasi". Status chip "GPS baik · ±6 m" top right.
```

## Prompt 10 — UI11 Arrived

```
Same design system. Screen "Arrived": map zoomed on the Gua Belanda marker; a Trail Green success ring animation around it. Bottom card: green check icon, "Anda telah tiba di Gua Belanda", mono line "Waktu tempuh 11 mnt · 640 m". Amber primary button "Dengarkan cerita", secondary "Lihat Detail". Calm, celebratory but restrained, with no confetti.
```

## Prompt 11 — UI12 GPS Lemah / QR Scanner (Cave Mode)

```
Same design system, Cave Mode dark variant (background Canopy Night #0F1A15, white text, amber accents). Create 2 screens.
Screen A: a Clay Red banner at top, "Sinyal GPS lemah · ±45 m", with the text "Di dalam gua? Pindai QR pada papan informasi." Below it, a large amber primary button "Pindai QR" and a secondary button "Pilih POI manual" that opens a short list "Di sekitar Anda" (Gua Jepang, Gua Belanda).
Screen B, QR scanner: full camera viewfinder of a dark cave wall with a small signboard; a rounded square scan frame with amber corner brackets and a slow scanning line; hint "Arahkan kamera ke kode QR"; flashlight toggle button; close button. Small note "Berfungsi tanpa internet".
```

## Prompt 12 — UI13 Pengingat Jam Tutup & Hidrasi

```
Same design system. Create 2 states over the Explore map.
Screen A, closing-time reminder: a prominent bottom card with a Clay Red top accent and clock icon: "Kawasan tutup pukul 16.00", body "Waktu jalan ke gerbang ±25 menit. Sebaiknya mulai kembali sekarang." with mono "15.20". Amber primary button "Navigasi ke gerbang", text button "Ingatkan 10 menit lagi". A small speaker icon shows it was also announced by voice.
Screen B, hydration reminder: a lighter Spring Teal accented card with a water-drop icon, "Waktunya minum", "Anda sudah berjalan 45 menit", the nearest rest spot "Titik istirahat · 90 m", buttons "Oke" and "Tunda".
```

## Prompt 13 — UI14 Ringkasan Sesi

```
Same design system. Screen "Jelajah Selesai". Top: header with contour texture and a map snapshot showing the walked route as a Canopy Deep line, with visited POIs as solid markers and unvisited ones as outlined markers. Title "Jelajah selesai" in Fraunces, date "Sabtu, 7 November". Big stat grid with mono numbers (2 columns, divider-separated, not cards): POI dikunjungi 6/10, Langkah 4.820, Jarak 3,1 km, Durasi 2 j 40 m, Est. kalori ±210 kkal. An elevation profile of the whole session. Section "Sudah dikunjungi" as a horizontal row of small round photo stamps with names (Gerbang, Monumen, Gua Jepang, Gua Belanda, Hutan Pinus, Area Piknik). Section "Untuk kunjungan berikutnya" as list rows: Penangkaran Rusa, Museum Ir. H. Djuanda, Kolam Pakar, Titik Koleksi Flora. Small privacy note "Data aktivitas hanya tersimpan di ponsel ini." Amber primary button "Kembali ke Beranda". No share button.
```

## Prompt 14 — UI15 Settings

```
Same design system. Screen "Pengaturan", grouped list with section headers and 1px dividers. "Audio & suara": Putar audio otomatis saat tiba (toggle on), Arahan suara navigasi (on), Bunyi saat mendekati POI (on). "Wellness": Pengingat minum/istirahat with a stepper "45 menit", Pengingat jam tutup (on). "Tampilan": Ukuran teks slider with an "Aa" preview, Kontras tinggi (off). "Data offline": a row "Peta & konten Dago Pakar · 86 MB · Terunduh" with a green check, and a "Perbarui data" secondary button. "Tentang": Versi 1.0, Atribusi peta © OpenStreetMap contributors. No account or login section.
```

---

## Refinement prompts (use when a result drifts)
- `Keep the exact palette, fonts and radii from the Home screen. Replace every emoji with 24dp line icons.`
- `Make all numbers JetBrains Mono and increase body text to 16sp; this is read while walking in sunlight.`
- `Reduce visual noise: replace the boxed cards with 1px dividers and more whitespace.`
- `The photos look like stock images. Make them documentary, natural light, slightly muted greens, real Indonesian forest park.`
- `Only one amber button on this screen; make the others secondary or text buttons.`
