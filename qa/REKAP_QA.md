# Rekap QA — Jelajah Taman

Status dokumen: Aktif
Tujuan: status persetujuan QA per fitur, menjadi bahan bagian "Status QA" di `.agents/PROGRESS.md`.
Penulis: Jacob (PM/QA), diperbarui setelah setiap fase uji selesai, dari `HASIL.md` kedua penguji (QA1 Jacob, QA2 Mike) di branch `qa`, folder `qa/`. Agen AI boleh menyusun draf dengan tanda `Draf AI`; draf baru berlaku setelah Jacob mengonfirmasi.

## Cara membaca

- **Fase uji:** Fase 1 = semua skenario di luar Tahura (tanpa GPS, mode demo, fake GPS, GPS asli di luar ruangan); Fase 2 = skenario yang harus dikonfirmasi di dalam Tahura (`qa/README.md` §3). Uji ulang setelah perbaikan dicatat di fase yang sama dengan build barunya.
- **Status QA:** `Belum diuji` · `Lulus` (semua skenario wajib lulus pada ≥2 HP) · `Sebagian` (ada kriteria yang belum terpenuhi atau baru satu HP) · `Gagal` (ada cacat Kritis/Mayor terbuka) · `Perlu uji ulang` (kode berubah setelah disetujui) · `Terblokir` (tidak dapat diuji; sebutkan sebabnya).
- **Cara uji:** `Luar` = sudah lulus di Fase 1 · `Tahura` = sudah dikonfirmasi di Fase 2.
- "Kode selesai" di `PROGRESS.md` bukan "disetujui QA". Hanya tabel ini yang menyatakan persetujuan QA.
- Detail per skenario: branch `qa`, `qa/QA1 - Jacob/HASIL.md` dan `qa/QA2 - Mike/HASIL.md`.

## Fase uji

| Fase | Build (APK) | Tanggal | Penguji | Cakupan | Status |
|---|---|---|---|---|---|
| 1 | `apk-latest` (QA2: `32018e3`; QA1: catat hash commit saat unduh) | mulai 23 Nov | Jacob, Mike | Semua skenario, di luar Tahura | Berjalan |
| 2 | APK kandidat final | akhir Sprint 5 | Jacob, Mike | Skenario Fase 2 (termasuk demo alur utama), di Tahura | Belum mulai |

## Status per fitur

| Fitur | PB | Penguji | Skenario | Status QA | Cara uji | Build | Tanggal | Cacat terbuka | Catatan |
|---|---|---|---|---|---|---|---|---|---|
| F01 Location Awareness | PB02 | Jacob | 11 | Belum diuji | — | — | — | — | |
| F02 Location-Based Trigger | PB06, PB07 | Jacob | 22 | Belum diuji | — | — | — | — | |
| F03 Multimodal Exploration | PB08, PB09 | Mike | 15 | Belum diuji | — | — | — | — | Teks POI final belum ada (PB08) |
| F04 Eyes-Free Interaction | PB11 | Mike | 16 | Belum diuji | — | — | — | — | |
| F05 Search & Destination | PB13 | Jacob | 16 | Belum diuji | — | — | — | — | |
| F06 Navigation | PB12, PB14 | Jacob | 18 | Belum diuji | — | — | — | — | |
| F07 Contextual Recommendation | PB15 | Mike | 15 | Belum diuji | — | — | — | — | |
| F08 Wellness Trail Explorer | PB16, PB18 | Mike | 19 | Belum diuji | — | — | — | — | |
| A01 Offline Mode | PB05 | Jacob | 7 | Belum diuji | — | — | — | — | |
| A02 QR Fallback | PB10 | Jacob | 9 | Belum diuji | — | — | — | — | Papan QR cetak P05/P06 belum ada |
| A03 Closing-Time Reminder | PB17 | Mike | 9 | Belum diuji | — | — | — | — | |
| A04 Facility Finder | PB13 | Jacob | 5 | Belum diuji | — | — | — | — | |
| A05 Data-Driven Content | PB04 | Mike | 6 | Belum diuji | — | — | — | — | |
| A06 Battery-Aware Tracking | PB21 | Jacob | 2 | Belum diuji | — | — | — | — | |
| A07 Accessibility | — | Mike | 5 | Belum diuji | — | — | — | — | |
| Pemasangan APK | PB01 | Jacob | 3 | Belum diuji | — | — | — | — | |
| Alur utama PRD §2.1 | — | Jacob | 9 | Belum diuji | — | — | — | — | |
| Ketahanan | — | Jacob | 5 | Belum diuji | — | — | — | — | |
| Onboarding, Beranda, Setelan | PB18 | Mike | 11 | Belum diuji | — | — | — | — | |
| Non-goals dan teks antarmuka | — | Mike | 12 | Belum diuji | — | — | — | — | |
| Usability + SUS | PB20 | Mike | 4 | Belum diuji | — | — | — | — | Butuh ≥5 responden |

## Cacat terbuka (ringkas)

| ID | Fitur | Tingkat | Ringkasan | Dilaporkan | Status |
|---|---|---|---|---|---|
| — | | | | | |

ID cacat: `CJ-nnn` (temuan Jacob), `CD-nnn` (temuan Mike). Rincian ada di `qa/QA1 - Jacob/CACAT.md` dan `qa/QA2 - Mike/CACAT.md` pada branch `qa`.

## Riwayat rekap

| Tanggal | Fase | Perubahan |
|---|---|---|
| 2026-11-22 | — | Kerangka rekap dibuat; semua fitur `Belum diuji`. |
