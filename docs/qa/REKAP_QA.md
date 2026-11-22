# Rekap QA — Jelajah Taman

Status dokumen: Aktif
Tujuan: status persetujuan QA per fitur, menjadi bahan bagian "Status QA" di `.agents/PROGRESS.md`.
Penulis: Jacob (PM/QA), diperbarui setelah setiap putaran uji selesai, dari log kedua penguji (Jacob, Michael Dimas) di branch `qa`, folder `qa/`. Agen AI boleh menyusun draf dengan tanda `Draf AI`; draf baru berlaku setelah Jacob mengonfirmasi.

## Cara membaca

- **Putaran uji** = satu kali menjalankan sekumpulan skenario pada satu versi APK yang sama. APK baru berarti putaran baru.
- **Status QA:** `Belum diuji` · `Lulus` (semua skenario wajib lulus pada ≥2 HP) · `Sebagian` (ada kriteria yang belum terpenuhi atau baru satu HP) · `Gagal` (ada cacat Kritis/Mayor terbuka) · `Perlu uji ulang` (kode berubah setelah disetujui) · `Terblokir` (tidak dapat diuji; sebutkan sebabnya).
- **Cara uji:** `Luar` = sudah lulus di luar Tahura (perangkat, mode demo, mock location, atau GPS nyata non-Tahura) · `Tahura` = sudah dikonfirmasi di lokasi.
- "Kode selesai" di `PROGRESS.md` bukan "disetujui QA". Hanya tabel ini yang menyatakan persetujuan QA.
- Detail per skenario: branch `qa`, `qa/<penguji>/putaran-NN/HASIL.md`.

## Putaran uji

| Putaran | Build (APK) | Tanggal | Penguji | Cakupan | Status |
|---|---|---|---|---|---|
| 01 | `apk-latest` 22 Nov (catat hash commit saat unduh) | — | Jacob, Dimas | Skenario yang dapat diuji di luar Tahura | Persiapan |

## Status per fitur

| Fitur | PB | Penguji | Skenario | Status QA | Cara uji | Build | Tanggal | Cacat terbuka | Catatan |
|---|---|---|---|---|---|---|---|---|---|
| F01 Location Awareness | PB02 | Jacob | 11 | Belum diuji | — | — | — | — | |
| F02 Location-Based Trigger | PB06, PB07 | Jacob | 22 | Belum diuji | — | — | — | — | |
| F03 Multimodal Exploration | PB08, PB09 | Dimas | 15 | Belum diuji | — | — | — | — | Teks POI final belum ada (PB08) |
| F04 Eyes-Free Interaction | PB11 | Dimas | 16 | Belum diuji | — | — | — | — | |
| F05 Search & Destination | PB13 | Jacob | 16 | Belum diuji | — | — | — | — | |
| F06 Navigation | PB12, PB14 | Jacob | 18 | Belum diuji | — | — | — | — | |
| F07 Contextual Recommendation | PB15 | Dimas | 15 | Belum diuji | — | — | — | — | |
| F08 Wellness Trail Explorer | PB16, PB18 | Dimas | 19 | Belum diuji | — | — | — | — | |
| A01 Offline Mode | PB05 | Jacob | 7 | Belum diuji | — | — | — | — | |
| A02 QR Fallback | PB10 | Jacob | 9 | Belum diuji | — | — | — | — | Papan QR cetak P05/P06 belum ada |
| A03 Closing-Time Reminder | PB17 | Dimas | 9 | Belum diuji | — | — | — | — | |
| A04 Facility Finder | PB13 | Jacob | 5 | Belum diuji | — | — | — | — | |
| A05 Data-Driven Content | PB04 | Dimas | 6 | Belum diuji | — | — | — | — | |
| A06 Battery-Aware Tracking | PB21 | Jacob | 2 | Belum diuji | — | — | — | — | |
| A07 Accessibility | — | Dimas | 5 | Belum diuji | — | — | — | — | |
| Pemasangan APK | PB01 | Jacob | 3 | Belum diuji | — | — | — | — | |
| Alur utama PRD §2.1 | — | Jacob | 9 | Belum diuji | — | — | — | — | |
| Ketahanan | — | Jacob | 5 | Belum diuji | — | — | — | — | |
| Onboarding, Beranda, Setelan | PB18 | Dimas | 11 | Belum diuji | — | — | — | — | |
| Non-goals dan teks antarmuka | — | Dimas | 12 | Belum diuji | — | — | — | — | |
| Usability + SUS | PB20 | Dimas | 4 | Belum diuji | — | — | — | — | Butuh ≥5 responden |

## Cacat terbuka (ringkas)

| ID | Fitur | Tingkat | Ringkasan | Dilaporkan | Status |
|---|---|---|---|---|---|
| — | | | | | |

ID cacat: `CJ-nnn` (temuan Jacob), `CD-nnn` (temuan Dimas). Rincian ada di `qa/<penguji>/putaran-NN/CACAT.md` pada branch `qa`.

## Riwayat rekap

| Tanggal | Putaran | Perubahan |
|---|---|---|
| 2026-11-22 | — | Kerangka rekap dibuat; semua fitur `Belum diuji`. |
