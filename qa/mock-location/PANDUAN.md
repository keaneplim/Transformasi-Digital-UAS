# Panduan mock location — uji "lapangan" tanpa ke Tahura

Status dokumen: Aktif
Untuk: skenario berlabel `TAHURA→MOCK` di `qa/<penguji>/putaran-NN/HASIL.md`.

**Prinsip:** ponsel diam di meja; aplikasi *mock location* memutar trek GPX yang berada **di dalam Tahura** sebagai posisi GPS. Jelajah Taman membaca posisi itu seperti GPS asli (aplikasi tidak menolak lokasi tiruan), sehingga pemicu, navigasi, rekomendasi, dan alur utama dapat diuji tanpa berjalan. Batasannya ada di `RENCANA_QA.md` §3.

## 1. Persiapan (sekali per HP)

1. **Aktifkan Opsi pengembang:** Setelan → Tentang ponsel → ketuk *Nomor versi* 7 kali.
2. **Pasang aplikasi mock location yang bisa mengimpor dan memutar file GPX** dengan kecepatan yang dapat diatur, dari Play Store. Contoh yang umum dipakai: *Lockito*. Pilih yang benar-benar mendukung impor GPX berupa rute (bukan hanya satu titik), dan catat nama + versinya di kepala `HASIL.md`.
3. Setelan → Opsi pengembang → **Pilih aplikasi lokasi palsu** → pilih aplikasi tersebut.
4. Salin folder `qa/mock-location/gpx/` ke ponsel (kabel USB, Drive, atau Telegram sebagai file), lalu impor trek yang dibutuhkan ke aplikasi mock.
5. **Uji coba:** putar `01_mendekati_P05_lalu_diam_4mnt.gpx`, buka Google Maps; titik biru harus berada di Tahura dan bergerak. Lalu buka Jelajah Taman → Peta: titik biru harus bergerak menuju Gua Jepang.
   - Bila titik di Jelajah Taman tidak bergerak padahal di Google Maps bergerak: cari opsi di aplikasi mock untuk menyuntikkan ke *fused/network provider* atau matikan pemindaian Wi-Fi/Bluetooth (Setelan → Lokasi → Layanan lokasi), lalu ulangi. Catat sebagai `Terblokir` bila tetap gagal, dan beri tahu Jacob.
6. Pastikan **Mode demo nonaktif** (Setelan → Mode demo), karena mode demo memakai posisi simulasinya sendiri.

## 2. Cara memakai saat uji

- Mulai sesi di Jelajah Taman (bila skenario memerlukannya) **sebelum** memutar trek, kecuali skenario "tanpa sesi" (SK-F02-19).
- Putar dengan **kecepatan 1×** (±3 km/jam, sesuai `walk_speed_m_per_min` 50) untuk skenario pemicu. Untuk trek panjang (06, 06b, 07, 08) boleh 2× bila hanya menguji urutan/kelengkapan; catat kecepatan di kolom *Catatan*.
- Untuk skenario layar terkunci: kunci layar setelah trek mulai berjalan.
- Untuk mode pesawat (SK-A01-01, SK-F04-13, SK-F06-05): aktifkan mode pesawat setelah trek berjalan; mock location tetap bekerja tanpa internet.
- Rekam layar sebagai bukti; sebut nomor trek di nama/catatan bukti, mis. `SK-F02-05_HP1_2026-11-24.mp4 (mock GPX 02)`.

## 3. Daftar trek

Semua trek dibangkitkan dari data aplikasi (`assets/content/trail_graph.json`, `pois.json`, `facilities.json`, `routes.json`) oleh `make_gpx.py`: mengikuti geometri jalur setapak, satu titik per detik, kecepatan jalan 50 m/menit, dengan jeda diam (goyangan ±0,3 m) di titik yang diperlukan. Jarak ke POI sudah diperiksa terhadap radius pemicu.

| Trek | Durasi | Isi | Skenario |
|---|---|---|---|
| `01_mendekati_P05_lalu_diam_4mnt.gpx` | 8 mnt 31 dtk | Jalan ±190 m menuju Gua Jepang (P05, r = 20 m), diam 4 menit di titik POI | SK-F01-06, SK-F02-01, SK-F02-04, SK-F02-19, SK-F02-20, SK-F02-22, SK-F03-08, SK-F04-01 s.d. SK-F04-06, SK-F04-16, SK-F07-03, SK-F07-15 |
| `02_keluar_masuk_cepat_P05.gpx` | 5 mnt 17 dtk | Mulai di P05, keluar ke 45 m (> r + 15), tunggu 1 menit, kembali sebelum 10 menit, diam 2 menit | SK-F02-05, SK-F07-03 |
| `03_keluar_masuk_lewat_10mnt_P05.gpx` | 15 mnt 55 dtk | Mulai di P05, keluar ke 60 m, tunggu 11 menit, kembali, diam 2 menit | SK-F02-06 |
| `04_tepi_zona_mendekati_P05.gpx` | 10 mnt 11 dtk | Mendekat sampai 47 m, mondar-mandir 47–57 m (di antara r + 30 dan r + 40) ±3 menit, menjauh ke 75 m, mendekat lagi ke 47 m. Tidak pernah masuk radius. | SK-F02-07, SK-F02-08 |
| `05_P07_ke_P09_berdekatan.gpx` | 3 mnt | Diam 1 menit di Penangkaran Rusa (P07), jalan 43 m ke Area Piknik (P09; radius bertumpuk), diam 1 menit | SK-F02-13 |
| `06_rute_santai_penuh.gpx` | 61 mnt | Rute Santai P01 → P03 → P02 → P04 → P05 → P06 → P01, diam 90 detik di tiap POI | SK-F02-09, SK-F06-03, SK-F07-01, SK-F08-11, SK-F08-16, SK-A01-01, SK-E2E-* |
| `06b_rute_sedang_10_poi.gpx` | 142 mnt | Rute Sedang melewati 10 POI inti (P01–P10), diam 60 detik di tiap POI | SK-F02-02, SK-F02-03 |
| `07_navigasi_gerbang_ke_P06.gpx` | 24 mnt | Dari gerbang (P01) mengikuti jalur ke Gua Belanda (P06), diam 2 menit | SK-F04-09, SK-F04-10, SK-F04-13, SK-F04-14, SK-F05-06, SK-F05-07, SK-F06-01, SK-F06-02, SK-F06-05, SK-F06-07 s.d. SK-F06-09, SK-F06-11, SK-F06-17 |
| `08_navigasi_menyimpang.gpx` | 26 mnt | Seperti 07, tetapi di ±35% menyimpang 15 m selama 30 detik (tidak boleh hitung ulang) dan di ±60% menyimpang 50 m selama 40 detik (harus hitung ulang) | SK-F06-04, SK-F06-14 |
| `09_ke_toilet_FS06.gpx` | 4 mnt | Dari Gua Belanda (P06) ke Toilet dekat Gua Belanda (FS06), diam 2 menit | SK-A04-03, SK-A04-04, SK-F06-10 |
| `10_diam_di_gerbang_P01.gpx` | 10 mnt | Diam di gerbang (P01) | SK-F02-17 |

Rekaman survei asli 7 November (`survey/raw/2026-11-07/tahura-f.gpx` di `main`, ±3 jam) juga dapat diputar untuk uji jelajah bebas; hasilnya dicatat sebagai pendukung.

## 4. Membangkitkan ulang trek

Bila koordinat POI, radius, atau graf jalur berubah di `main`, perbarui branch `qa` dari `main`, lalu jalankan dari root repo:

```
python qa/mock-location/make_gpx.py . qa/mock-location/gpx
```

Periksa bahwa daftar trek dan durasinya masih sesuai tabel §3, lalu commit trek baru (Jacob).
