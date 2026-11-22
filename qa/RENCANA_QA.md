# Rencana QA — Jelajah Taman

Status dokumen: Aktif
Penyusun: Jacob (PM/QA-1), disusun dengan bantuan Claude Code pada 22 November 2026 (catat di AI & Tools Disclosure).
Acuan: `docs/prd/PRD.md` (v0.9.2), `docs/qa/scenario/` (219 skenario SK-*), `docs/qa/DEVICE_CHECK.md`, `.agents/MEMORY.md` dan `.agents/PROGRESS.md` per 22 November 2026 (commit `86ba11a`, setelah PR #15).

## 1. Tujuan dan cakupan

Menguji **fitur yang sudah ada di `main`** sedini mungkin, tidak menunggu Sprint 5, agar setiap fitur yang lulus dapat dinyatakan "disetujui QA" di `docs/qa/REKAP_QA.md` dan dilaporkan di progress report (`.agents/PROGRESS.md`).

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

Dua penguji, masing-masing memakai **dua HP Android** yang sama (HP1, HP2), agar setiap skenario teruji di ≥2 perangkat (PB01, PRD §11).

| Penguji | Kelompok skenario | Jumlah |
|---|---|---|
| **Jacob (QA-1)** | F01 Lokasi (11), F02 Pemicu (22), A02 QR (9), F05 Cari (16), A04 Fasilitas (5), F06 Navigasi (18), A01 Offline (7), A06 Baterai (2), INS Pemasangan (3), E2E Alur utama (9), KTH Ketahanan (5) | 107 |
| **Michael Dimas (QA-2)** | F03 Konten (15), F04 Eyes-free (16), F07 Rekomendasi (15), A03 Pengingat jam tutup (9), F08 Wellness (19), A05 Data (6), A07 Aksesibilitas (5), ONB/HOM/SET (11), NG Non-goals (8), TKS Teks (4), USB Usability (4) | 112 |

Log masing-masing: `qa/jacob/putaran-NN/` dan `qa/dimas/putaran-NN/`. Bila dua HP hanya ada pada satu orang, penguji bergantian memakai HP yang sama; kolom HP1/HP2 tetap merujuk ke perangkat yang sama untuk kedua penguji.

## 3. Label tempat uji

Setiap skenario di `HASIL.md` diberi label:

| Label | Arti | Jumlah (Jacob / Dimas) |
|---|---|---|
| `LUAR` | Dapat diuji di mana saja: ponsel uji, mode demo, menu debug, pemeriksaan dokumen, hasil uji otomatis. | 53 / 93 |
| `TAHURA→MOCK` | Seharusnya di Tahura (butuh posisi di taman). Di luar Tahura dijalankan dengan **mock location**: ponsel diam, aplikasi lain memutar trek GPX taman sebagai GPS (`mock-location/PANDUAN.md`). | 41 / 17 |
| `TAHURA→GPS` | Seharusnya di Tahura, tetapi yang diuji adalah perilaku GPS/sensor nyata, bukan posisi di taman. Dijalankan dengan **GPS asli di luar Tahura** (halaman kampus, lapangan, dalam gedung). | 10 / 2 |
| `TAHURA→LUAR` | Seharusnya di Tahura (QR di mulut gua). Di luar Tahura memakai **papan QR cetak** di ruangan biasa/gelap. | 3 / 0 |

Kolom **Konfirmasi Tahura = Ya** menandai skenario yang, walaupun sudah lulus di luar, diulang sekali di Tahura (§5) karena kondisi taman bisa mengubah hasil: SK-F01-03 (deviasi GPS di bawah kanopi), SK-F02-02 dan SK-F02-03 (pemicu dengan GPS asli di 10 POI), SK-F06-03 dan SK-F06-06 (navigasi dan ETA di jalur menanjak), SK-A02-01/02/06 (QR di mulut gua), SK-F04-01 (kunjungan dengan layar terkunci), dan alur utama SK-E2E-*.

### Apa yang tidak dibuktikan oleh mock location

Mock location menguji **logika aplikasi** terhadap posisi taman (radius, debounce, cooldown, histeresis, navigasi, hitung ulang, rekomendasi). Mock **tidak** menguji akurasi GPS di bawah kanopi, sinyal yang hilang, waktu tempuh nyata di tanjakan, jumlah langkah, dan pemakaian baterai (chip GPS tidak dipakai). Karena itu:

- Hasil mock ditulis dengan keterangan "(mock GPX nn)" dan dihitung sebagai `Lulus (Luar)` di rekap.
- Akurasi, GPS lemah, layar mati, langkah, dan baterai diuji dengan label `TAHURA→GPS` (GPS asli di luar Tahura).
- Akurasi ETA di tanjakan (SK-F06-06) hanya dapat dibuktikan penuh di Tahura; di luar hanya diuji pada rute datar (hasil `Sebagian` sampai hari Tahura).

## 4. Putaran uji

| Putaran | Build | Isi | Keluaran |
|---|---|---|---|
| **01** | `apk-latest` 22 Nov (setelah PR #15) | Semua skenario `LUAR`, `TAHURA→MOCK`, `TAHURA→GPS`, `TAHURA→LUAR` | `HASIL.md` + `CACAT.md` per penguji; rekap 01 ke `main` |
| **02** | APK baru setelah perbaikan | Skenario gagal/sebagian/terblokir, fitur yang kodenya berubah, daftar asap | Rekap 02 |
| **Tahura** | APK final kandidat (satu hari di akhir Sprint 5) | Skenario *Konfirmasi Tahura* + demo alur utama | Rekap akhir, bahan Testing Report |

Urutan kerja yang disarankan dalam satu putaran, per penguji:

1. **Meja (tanpa GPS):** skenario `LUAR` berkode P, M, D, O. Paling cepat, menyelesaikan sebagian besar fitur Dimas.
2. **Mock location:** skenario `TAHURA→MOCK`, dikelompokkan per trek GPX (satu trek melayani beberapa skenario, lihat `mock-location/PANDUAN.md` §3).
3. **GPS asli di luar ruangan:** skenario `TAHURA→GPS` dan `TAHURA→LUAR` (satu sesi jalan ±60 menit sekaligus untuk baterai SK-A06-01, langkah SK-F08-03, akurasi SK-F01-*).

## 5. Kriteria

**Siap mulai putaran:** APK terpasang di HP1 dan HP2 (catat hash build) · `docs/qa/DEVICE_CHECK.md` §3 terisi untuk kedua HP · suara TTS Indonesia luring terpasang · aplikasi mock location siap · papan QR tercetak (§6).

**Fitur disetujui QA (`Lulus`):** semua skenario fitur itu yang terkait acceptance criteria PRD lulus di **kedua HP**, tanpa cacat Kritis/Mayor terbuka. Bila lulusnya lewat mock/luar, kolom *Cara uji* di rekap = `Luar`; setelah hari Tahura = `Tahura`.

**Fitur `Sebagian`:** sebagian kriteria lulus, atau baru di satu HP, atau menunggu konfirmasi Tahura untuk kriteria yang tidak bisa dibuktikan di luar.

**Putaran selesai:** semua skenario terisi (Lulus/Sebagian/Gagal/Terblokir) di kedua HP; semua cacat tercatat dengan bukti.

## 6. Persiapan perangkat dan alat

- **Dua HP Android** dengan `docs/qa/DEVICE_CHECK.md` §1 (opsi pengembang aktif, sensor langkah, TTS Indonesia luring, pengaturan baterai).
- **APK:** GitHub → Releases → `apk-latest` → `jelajah-taman.apk`. Tiap versi baru: uninstall dulu (kunci tanda tangan CI berganti).
- **Mock location:** `mock-location/PANDUAN.md`.
- **Menu debug:** ketuk 7 kali baris *Versi aplikasi* di Setelan → Tentang. Menu ini membuka jam debug, GPS lemah tiruan, pratinjau panggilan akhir, salin ringkasan log sesi. Hasil dari menu debug dicatat sebagai bukti pendukung (metode M), bukan pengganti uji GPS.
- **Papan QR cetak** (buat di generator QR mana pun, teks persis): `jelajahtaman://poi/P05`, `jelajahtaman://poi/P06`, `jelajahtaman://poi/P99` (ID tidak dikenal), dan satu QR asing (mis. `https://example.com`).
- **Lain-lain:** earphone kabel dan Bluetooth, stopwatch, meteran (untuk 20 m), power bank.

## 7. Hari Tahura (konfirmasi + demo)

Satu kunjungan di akhir Sprint 5. Jalankan rute Santai atau Sedang dengan GPS asli, layar sering terkunci, dua HP:

1. SK-E2E-01 … SK-E2E-09 sebagai alur demo (rekam video).
2. Sepanjang jalan: SK-F02-02 / SK-F02-03 (catat setiap pemicu dan waktunya), SK-F01-03 di titik referensi survei (`SURVEY_EXIF`), SK-F04-01 di satu POI.
3. SK-A02-01, -02, -06 di mulut Gua Jepang dan Gua Belanda (papan QR sementara, Lampiran B butir 6).
4. SK-F06-03 dan SK-F06-06: navigasi ke tiga POI, catat ETA awal vs waktu tempuh.
5. Cadangan cuaca (musim hujan, risiko R7): bila batal, hasil `Luar` tetap berlaku dan rekap mencatat "konfirmasi Tahura tidak terlaksana".
