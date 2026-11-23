# Rencana QA — Jelajah Taman

Status dokumen: Aktif
Penyusun: Jacob (PM/QA-1), disusun dengan bantuan Claude Code pada 22 November 2026 (catat di AI & Tools Disclosure).
Acuan: `docs/prd/PRD.md` (v0.9.2), `qa/scenario/` (219 skenario SK-*), `qa/DEVICE_CHECK.md`, `.agents/MEMORY.md` dan `.agents/PROGRESS.md` per 22 November 2026 (commit `86ba11a`, setelah PR #15).

## 1. Tujuan dan cakupan

Menguji **fitur yang sudah ada di `main`** sedini mungkin, tidak menunggu Sprint 5, agar setiap fitur yang lulus dapat dinyatakan "disetujui QA" di `qa/REKAP_QA.md` dan dilaporkan di progress report (`.agents/PROGRESS.md`).

Per 22 November semua fitur F01–F08 dan A01–A07 sudah ada dalam kode, tetapi **belum pernah diuji di ponsel Android**. Yang belum ada atau belum final (diuji, dicatat `Terblokir` bila tidak dapat dijalankan):

| Hal | Skenario terdampak |
|---|---|
| Teks POI final bersumber dan fakta kunci (masih `[ISI]`) | SK-F03-02, SK-F03-12 |
| Papan QR cetak P05/P06 (bisa dicetak sendiri untuk uji, lihat §6) | SK-A02-* |
| Tautan dalam (deep link) QR | SK-A02 terkait UC-A02-4, bila ada |
| Kontrol layar kunci untuk pembacaan teks TTS cadangan (sengaja tidak dibuat) | bagian dari SK-F04-07/08 bila narasi jatuh ke TTS |
| 5 koordinat `ESTIMATE` (P02, P08, P10, FS02, FS05) | Hasil pemicu di POI ini dicatat dengan keterangan |

Tidak diuji: iPhone (tidak dapat menjalankan APK), fitur di luar PRD (non-goals NG01–NG08 hanya diperiksa ketiadaannya).

## 2. Pembagian penguji

Dua penguji, **satu orang satu HP** (merek berbeda), di tempat dan waktu masing-masing. Tidak ada uji yang perlu dua HP sekaligus dan tidak perlu bertukar HP.

| Penguji | Kelompok skenario | Jumlah |
|---|---|---|
| **Jacob (QA-1)** | F01 Lokasi (11), F02 Pemicu (22), A02 QR (9), F05 Cari (16), A04 Fasilitas (5), F06 Navigasi (18), A01 Offline (7), A06 Baterai (2), INS Pemasangan (3), E2E Alur utama (9), KTH Ketahanan (5) | 107 |
| **Michael Dimas (QA-2)** | F03 Konten (15), F04 Eyes-free (16), F07 Rekomendasi (15), A03 Pengingat jam tutup (9), F08 Wellness (19), A05 Data (6), A07 Aksesibilitas (5), ONB/HOM/SET (11), NG Non-goals (8), TKS Teks (4), USB Usability (4) | 112 |

Hasil masing-masing: `qa/QA1 - Jacob/HASIL.md` dan `qa/QA2 - Mike/HASIL.md`. Setiap skenario bagian sendiri cukup diuji sekali, di HP penguji.

**Uji lintas perangkat.** Dua belas skenario yang hasilnya dapat berbeda antar-merek HP (izin, layanan latar, notifikasi, mesin suara, sensor langkah, kamera, pemborosan baterai) dijalankan oleh **kedua** penguji, masing-masing di HP-nya sendiri. Dengan ini aplikasi teruji di ≥2 perangkat (PB01) tanpa mengulang semua skenario. Di `HASIL.md` skenario ini bertanda *Lintas = Ya*, dan 6 skenario milik penguji lain ada di bagian akhir.

| Dari bagian Jacob (juga dijalankan Dimas) | Dari bagian Dimas (juga dijalankan Jacob) |
|---|---|
| SK-INS-01 Terpasang dan terbuka | SK-F03-09 Cadangan Text-to-Speech perangkat |
| SK-F01-01 Posisi tampil setelah izin | SK-F04-01 Kunjungan POI dengan layar terkunci |
| SK-F01-07 Lokasi tetap dibaca saat layar mati | SK-F04-07 Kontrol media di layar kunci |
| SK-F02-20 Notifikasi pemicu di layar terkunci | SK-F04-13 Suara tanpa internet |
| SK-A02-01 QR Gua Jepang dengan kamera, luring | SK-A03-02 Suara dan notifikasi pengingat |
| SK-A06-01 Pemakaian baterai per jam | SK-F08-03 Uji 200 langkah |

## 3. Tempat uji dan fase

Pengujian dibagi dua fase (`qa/README.md` §3): **Fase 1** di luar Tahura untuk semua skenario, **Fase 2** di Tahura hanya untuk skenario yang harus dikonfirmasi di taman. Penguji, label tempat uji (`LUAR`, `TAHURA→MOCK`, `TAHURA→GPS`, `TAHURA→LUAR`), cara uji di luar Tahura, tanda Fase 2, dan tanda lintas perangkat tercantum di setiap skenario di `qa/scenario/` dan dijelaskan di `qa/scenario/README.md`, bagian *Pelaksanaan*.

Jumlah per label (Jacob / Mike): `LUAR` 53 / 93 · `TAHURA→MOCK` 41 / 17 · `TAHURA→GPS` 10 / 2 · `TAHURA→LUAR` 3 / 0. Fase 2: 17 skenario Jacob + 1 skenario Mike, ditambah satu skenario lintas perangkat untuk masing-masing.

### Apa yang tidak dibuktikan oleh mock location

Mock location menguji **logika aplikasi** terhadap posisi taman (radius, debounce, cooldown, histeresis, navigasi, hitung ulang, rekomendasi). Mock **tidak** menguji akurasi GPS di bawah kanopi, sinyal yang hilang, waktu tempuh nyata di tanjakan, jumlah langkah, dan pemakaian baterai (chip GPS tidak dipakai). Karena itu:

- Hasil mock ditulis dengan keterangan "(mock GPX nn)" dan dihitung sebagai `Lulus (Luar)` di rekap.
- Akurasi, GPS lemah, layar mati, langkah, dan baterai diuji dengan label `TAHURA→GPS` (GPS asli di luar Tahura).
- Akurasi ETA di tanjakan (SK-F06-06) hanya dapat dibuktikan penuh di Tahura; di luar hanya diuji pada rute datar (hasil `Sebagian` sampai Fase 2).

## 4. Fase uji

| Fase | Build | Isi | Keluaran |
|---|---|---|---|
| **Fase 1**, di luar Tahura | `apk-latest` (mulai 23 Nov); uji ulang pada APK perbaikan | Semua skenario: 1A tanpa GPS, 1B fake GPS (mock GPX), 1C GPS asli di luar ruangan, 1D papan QR cetak, 1E lintas perangkat | Bagian *Fase 1* di `HASIL.md` + `CACAT.md` per penguji; rekap Fase 1 |
| **Fase 2**, di Tahura | APK kandidat final (satu hari di akhir Sprint 5) | Skenario bertanda *Fase 2* (termasuk alur utama SK-E2E-* sebagai demo) | Bagian *Fase 2* di `HASIL.md`; rekap akhir, bahan Testing Report |

Urutan kerja yang disarankan dalam Fase 1, per penguji (sama dengan urutan bagian di `HASIL.md`):

1. **1A tanpa GPS:** skenario `LUAR` berkode P, M, D, O. Paling cepat, menyelesaikan sebagian besar fitur Mike.
2. **1B fake GPS:** skenario `TAHURA→MOCK`, dikelompokkan per trek GPX (satu trek melayani beberapa skenario, lihat `mock-location/PANDUAN.md` §3).
3. **1C/1D di luar ruangan:** skenario `TAHURA→GPS` dan `TAHURA→LUAR` (satu sesi jalan ±60 menit sekaligus untuk baterai SK-A06-01, langkah SK-F08-03, akurasi SK-F01-*).
4. **1E lintas perangkat:** skenario penguji lain yang juga dijalankan di HP sendiri.

## 5. Kriteria

**Siap mulai Fase 1:** APK terpasang di HP penguji (catat hash build) · `qa/DEVICE_CHECK.md` §3 terisi untuk HP masing-masing · suara TTS Indonesia luring terpasang · aplikasi mock location siap · papan QR tercetak (§6).

**Fitur disetujui QA (`Lulus`):** semua skenario fitur itu yang terkait acceptance criteria PRD lulus di HP penguji, dan skenario lintas perangkat fitur itu lulus di **kedua HP** (HP Jacob dan HP Dimas), tanpa cacat Kritis/Mayor terbuka. Bila lulusnya di Fase 1, kolom *Cara uji* di rekap = `Luar`; setelah Fase 2 = `Tahura`.

**Fitur `Sebagian`:** sebagian kriteria lulus, atau skenario lintas perangkatnya baru lulus di satu HP, atau menunggu konfirmasi Tahura untuk kriteria yang tidak bisa dibuktikan di luar.

**Fase 1 selesai:** semua skenario Fase 1 di `HASIL.md` kedua penguji terisi (Lulus/Sebagian/Gagal), termasuk bagian 1E lintas perangkat; semua cacat tercatat dengan bukti.

## 6. Persiapan perangkat dan alat

- **Satu HP Android per penguji** (merek berbeda) dengan `qa/DEVICE_CHECK.md` §1 (opsi pengembang aktif, sensor langkah, TTS Indonesia luring, pengaturan baterai).
- **APK:** GitHub → Releases → `apk-latest` → `jelajah-taman.apk`. Tiap versi baru: uninstall dulu (kunci tanda tangan CI berganti).
- **Mock location:** `mock-location/PANDUAN.md`.
- **Menu debug:** ketuk 7 kali baris *Versi aplikasi* di Setelan → Tentang. Menu ini membuka jam debug, GPS lemah tiruan, pratinjau panggilan akhir, salin ringkasan log sesi. Hasil dari menu debug dicatat sebagai bukti pendukung (metode M), bukan pengganti uji GPS.
- **Papan QR cetak** (buat di generator QR mana pun, teks persis): `jelajahtaman://poi/P05`, `jelajahtaman://poi/P06`, `jelajahtaman://poi/P99` (ID tidak dikenal), dan satu QR asing (mis. `https://example.com`).
- **Lain-lain:** earphone kabel dan Bluetooth, stopwatch, meteran (untuk 20 m), power bank.

## 7. Fase 2: hari Tahura (konfirmasi + demo)

Satu kunjungan di akhir Sprint 5. Jalankan rute Santai atau Sedang dengan GPS asli, layar sering terkunci, kedua penguji membawa HP masing-masing:

1. SK-E2E-01 … SK-E2E-09 sebagai alur demo (rekam video).
2. Sepanjang jalan: SK-F02-02 / SK-F02-03 (catat setiap pemicu dan waktunya), SK-F01-03 di titik referensi survei (`SURVEY_EXIF`), SK-F04-01 di satu POI.
3. SK-A02-01, -02, -06 di mulut Gua Jepang dan Gua Belanda (papan QR sementara, Lampiran B butir 6).
4. SK-F06-03 dan SK-F06-06: navigasi ke tiga POI, catat ETA awal vs waktu tempuh.
5. Cadangan cuaca (musim hujan, risiko R7): bila batal, hasil `Luar` tetap berlaku dan rekap mencatat "konfirmasi Tahura tidak terlaksana".
