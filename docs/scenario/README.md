# Skenario Uji — Jelajah Taman

Kumpulan skenario uji untuk membuktikan pemenuhan PRD Jelajah Taman (v0.9.2). Dokumen ini adalah rincian pelaksanaan dari Lampiran A PRD (TC-01 s.d. TC-13): setiap acceptance criteria F01–F08 dan A01–A07 dipecah menjadi skenario yang dapat dijalankan dan dicatat satu per satu, ditambah skenario untuk alur utama, layar, non-goals, dan usability.

**Kedudukan dokumen.** PRD (`docs/prd/PRD.md`, dibangkitkan dari docx) tetap menjadi acuan persyaratan; bila skenario di sini berbeda dari PRD, PRD yang berlaku dan skenario diperbaiki. Skenario yang bersumber dari rencana implementasi atau panduan desain, bukan dari PRD, diberi keterangan pada kolom Acuan ("rencana implementasi", `DESIGN.md`) dan tidak menentukan status kelulusan requirement.

**Sumber.** `docs/prd/PRD.md` · `docs/engineering/IMPLEMENTATION_PLAN.md` (use case, kasus tepi) · `docs/engineering/DEVICE_CHECK.md` · `docs/engineering/SURVEY_CHECKLIST.md` · `docs/design/DESIGN.md` · `PROGRESS.md` (isu terbuka) · `assets/content/*.json`.

## Daftar berkas

| Berkas | Cakupan | Jumlah skenario |
|---|---|---|
| [01-lokasi-dan-pemicu.md](01-lokasi-dan-pemicu.md) | F01 Location Awareness, F02 Location-Based Trigger, A02 QR Fallback | 42 |
| [02-konten-dan-eyes-free.md](02-konten-dan-eyes-free.md) | F03 Multimodal Exploration, F04 Eyes-Free Interaction | 31 |
| [03-cari-dan-navigasi.md](03-cari-dan-navigasi.md) | F05 Search & Destination, A04 Facility Finder, F06 Navigation | 39 |
| [04-rekomendasi-pengingat-wellness.md](04-rekomendasi-pengingat-wellness.md) | F07 Contextual Recommendation, A03 Closing-Time Reminder, F08 Wellness Trail Explorer | 43 |
| [05-offline-data-baterai-aksesibilitas.md](05-offline-data-baterai-aksesibilitas.md) | A01 Offline Mode, A05 Data-Driven Content, A06 Battery-Aware Tracking, A07 Accessibility | 20 |
| [06-alur-utama-dan-batasan.md](06-alur-utama-dan-batasan.md) | Pemasangan (PB01), alur utama PRD §2.1, onboarding/Beranda/Setelan, cakupan UI01–UI15, non-goals NG01–NG08, teks antarmuka, ketahanan | 40 |
| [07-usability.md](07-usability.md) | Usability testing dan SUS (PB20, F04 AC4) | 4 kriteria, 6 tugas |

## Konvensi

**ID skenario:** `SK-<kelompok>-<nomor>`, mis. `SK-F02-05`. Kelompok mengikuti ID requirement PRD (F01–F08, A01–A07) atau: `INS` pemasangan, `E2E` alur utama, `ONB` onboarding, `HOM` Beranda, `SET` Setelan, `NG` non-goals, `TKS` teks antarmuka, `KTH` ketahanan, `USB` usability. ID tidak dipakai ulang; skenario baru mendapat nomor berikutnya.

**Kode metode:**

| Kode | Arti |
|---|---|
| L | Lapangan: dijalankan di Tahura zona Dago Pakar dengan GPS nyata. |
| P | Perangkat: dijalankan pada ponsel uji di mana saja. |
| M | Meja dengan Mode demo: posisi, jam, dan pengingat disimulasikan melalui Setelan → Mode demo. Hasil mode ini menjadi bukti logika, bukan pengganti uji lapangan untuk acceptance criteria yang menyebut "penguji berjalan/memasuki". |
| D | Pemeriksaan dokumen atau data (berkas JSON, naskah, `git diff`). |
| O | Bukti uji otomatis: keluaran `flutter test` pada commit yang diuji, dilampirkan sebagai pendukung. |

Bila kolom Metode memuat dua kode (mis. "L, O"), kode pertama adalah cara utama dan kode kedua adalah bukti pendukung atau cara pendahuluan.

**Notasi:** `r` = radius pemicu POI. Waktu ditulis 24 jam dengan titik (15.30).

## Lingkungan uji

- Minimal dua ponsel Android berbeda merek yang lulus `docs/engineering/DEVICE_CHECK.md` (sensor penghitung langkah, suara TTS Indonesia luring, pengaturan baterai). iPhone tidak dapat menjalankan APK.
- Perlengkapan: earphone kabel dan Bluetooth, stopwatch, meteran atau roda ukur, power bank, senter, papan QR tercetak (P05, P06, satu ID tidak dikenal, satu QR asing), lembar catat.
- Setiap sesi uji mencatat: tanggal, penguji, versi build (hash commit atau nomor versi APK), perangkat (merek, model, versi Android), cuaca dan kondisi sinyal untuk uji lapangan.

## Pencatatan hasil

Satu baris per skenario per perangkat per putaran uji.

| ID | Tanggal | Penguji | Build | Perangkat | Hasil aktual | Status | Bukti | ID cacat |
|---|---|---|---|---|---|---|---|---|
| SK-F02-02 | | | | | | | | |

**Status:** `Lulus` (hasil sesuai harapan) · `Sebagian` (sebagian kriteria terpenuhi; jelaskan) · `Gagal` · `Terblokir` (tidak dapat dijalankan; tulis penyebabnya, mis. fitur belum ada atau data belum terverifikasi). Tiga status pertama dipetakan ke Pass / Partial / Fail pada PRD §11. Hasil aktual ditulis apa adanya, termasuk angka terukur (PRD §8.2).

**Bukti:** tangkapan layar, rekaman layar, video lapangan, atau ekspor log; beri nama `<ID>_<perangkat>_<tanggal>`, mis. `SK-F02-02_HP1_2026-11-24.mp4`. Wajah pengunjung atau anggota tim tidak ditampilkan tanpa izin.

**Tingkat cacat:** `Kritis` (fitur Must tidak berfungsi, aplikasi macet, atau data hilang) · `Mayor` (acceptance criteria tidak terpenuhi tetapi ada jalan lain) · `Minor` (tampilan, teks, atau kenyamanan). PB21 mensyaratkan tidak ada cacat kritis yang terbuka.

**Uji ulang:** setelah perbaikan, jalankan kembali skenario yang gagal beserta daftar asap berikut pada build baru: SK-INS-01, SK-F01-01, SK-F02-02 (minimal tiga POI), SK-F03-07, SK-F05-01, SK-F06-01, SK-F07-01, SK-F08-11, SK-A01-01.

## Urutan pelaksanaan yang disarankan

1. **Meja (kapan saja):** seluruh skenario berkode P, M, D, O. Mencakup TC-05, TC-07, TC-09, TC-10, TC-11 dan sebagian besar F03, F05, F07, A03, A05, A07.
2. **Lapangan hari pertama:** TC-01, TC-02, TC-03, TC-04, TC-06 (berkas 01 dan 02), disusul SK-A06-01 saat berjalan.
3. **Lapangan hari kedua:** TC-08, TC-12, TC-13 (berkas 03, 04, 05) dan alur utama SK-E2E-01 s.d. SK-E2E-09.
4. **Usability:** berkas 07, setelah cacat kritis dari langkah 1–3 diperbaiki.

Uji lapangan dijadwalkan di awal Sprint 5 dengan tanggal cadangan karena musim hujan (risiko R7).

## Matriks keterlacakan: acceptance criteria → skenario

| Req. | AC | Isi singkat | Skenario |
|---|---|---|---|
| F01 | 1 | Posisi tampil ≤10 detik | SK-F01-01 |
| F01 | 2 | Diperbarui saat berjalan 20 m | SK-F01-02 |
| F01 | 3 | Deviasi ≤15 m pada ≥80% pengukuran | SK-F01-03 |
| F01 | 4 | Izin ditolak: penjelasan, tetap dapat dipakai | SK-F01-04, SK-F01-09, SK-A02-07, SK-ONB-02, SK-ONB-04 |
| F01 | 5 | Indikator "GPS lemah" saat akurasi >30 m | SK-F01-05 |
| F01 | — | Deskripsi: GPS lemah tidak memicu, layar mati, tanpa filter jarak | SK-F01-06, SK-F01-07, SK-F01-08, SK-F01-10, SK-F01-11 |
| F02 | 1 | Notifikasi benar ≤10 detik pada ≥8 dari 10 POI | SK-F02-02 |
| F02 | 2 | Tidak berulang selama 3 menit di dalam radius | SK-F02-04 |
| F02 | 3 | Keluar >r + 15 m lalu masuk <10 menit tidak memicu ulang | SK-F02-05 |
| F02 | 4 | Getaran mendekati pada ≤r + 30 m | SK-F02-01 |
| F02 | 5 | QR membuka POI yang benar ≤3 detik luring | SK-A02-01, SK-A02-02 |
| F02 | 6 | Tanpa pemicu palsu | SK-F02-03 |
| F02 | — | Deskripsi: state, histeresis, "Nanti", POI berdekatan, banner GPS lemah, P01, P11, log | SK-F02-06 s.d. SK-F02-22 |
| F03 | 1 | 10 POI memiliki teks, ≥1 foto, audio | SK-F03-01 |
| F03 | 2 | Audio diputar, dijeda, dilanjutkan, diulang | SK-F03-07 |
| F03 | 3 | Konten lengkap dalam mode pesawat | SK-F03-01 |
| F03 | 4 | POI Detail dari notifikasi ≤2 detik | SK-F03-08 |
| F03 | — | Deskripsi: panjang teks, fakta kunci, foto, durasi audio, TTS cadangan, sumber | SK-F03-02 s.d. SK-F03-06, SK-F03-09 s.d. SK-F03-15 |
| F04 | 1 | Layar terkunci: pemicu, narasi, jeda/lanjut tanpa membuka aplikasi | SK-F04-01, SK-F04-06, SK-F04-07, SK-F04-08 |
| F04 | 2 | Auto-Play mulai ≤3 detik | SK-F04-04 |
| F04 | 3 | Arahan suara di setiap simpul belokan | SK-F04-09 |
| F04 | 4 | ≥4 dari 5 responden tanpa melihat layar | SK-F04-16, SK-USB-02 |
| F04 | — | Deskripsi: getar, prompt suara, pengingat bersuara | SK-F04-02, SK-F04-03, SK-F04-05, SK-F04-10 s.d. SK-F04-15 |
| F05 | 1 | "gua" dan "toilet" | SK-F05-01, SK-F05-02 |
| F05 | 2 | Filter kategori | SK-F05-04, SK-F05-05 |
| F05 | 3 | Terurut jarak jalan kaki, jarak + ETA | SK-F05-06, SK-F05-07 |
| F05 | 4 | Luring, hasil ≤1 detik | SK-F05-08 |
| F05 | 5 | Tak ditemukan: pesan dan saran kategori | SK-F05-09 |
| F05 | 6 | Satu salah ketik tetap benar | SK-F05-10 |
| F05 | — | Deskripsi: pencocokan sebagian, batas salah ketik, sinonim, aksi hasil | SK-F05-03, SK-F05-11 s.d. SK-F05-16 |
| F06 | 1 | Rute mengikuti jalur, tampil ≤3 detik | SK-F06-01 |
| F06 | 2 | Sisa jarak dan ETA berkurang | SK-F06-02 |
| F06 | 3 | Mencapai 3 POI hanya dengan navigasi | SK-F06-03 |
| F06 | 4 | Hitung ulang ≤5 detik setelah menyimpang >30 m | SK-F06-04 |
| F06 | 5 | Berfungsi dalam mode pesawat | SK-F06-05 |
| F06 | 6 | Selisih ETA ≤25% | SK-F06-06 |
| F06 | — | Deskripsi: status tiba, tidak memicu ulang, "Buka detail", arahan | SK-F06-07 s.d. SK-F06-18 |
| F07 | 1 | Selalu POI yang belum dikunjungi | SK-F07-01 |
| F07 | 2 | Muncul ≤2 detik | SK-F07-02 |
| F07 | 3 | Tidak melewati jam tutup − 15 menit; 15.30 di P06 kembali ke gerbang | SK-F07-04, SK-F07-05 |
| F07 | 4 | Minat mengubah urutan | SK-F07-06 |
| F07 | 5 | Navigasi satu ketukan | SK-F07-07 |
| F07 | — | Deskripsi: 1 utama + 2 alternatif, "Nanti", rute aktif, bobot | SK-F07-03, SK-F07-08 s.d. SK-F07-15 |
| F08 | 1 | Tiga rute dengan jarak, elevasi, durasi, kesulitan | SK-F08-01 |
| F08 | 2 | Selisih langkah ≤10% pada 200 langkah | SK-F08-03 |
| F08 | 3 | Pengingat hidrasi sesuai interval | SK-F08-08, SK-F08-09 |
| F08 | 4 | Ringkasan sesuai log sesi | SK-F08-11, SK-F08-12 |
| F08 | 5 | Data aktivitas hanya di perangkat | SK-F08-13 |
| F08 | — | Deskripsi: jarak, durasi, kalori, titik istirahat, flora-fauna | SK-F08-02, SK-F08-04 s.d. SK-F08-07, SK-F08-10, SK-F08-14 s.d. SK-F08-19 |
| A01 | — | Alur F01–F08 dalam mode pesawat | SK-A01-01, SK-A01-02, SK-A01-03 |
| A02 | — | QR gua ≤3 detik luring; QR tak dikenal menampilkan galat | SK-A02-01 s.d. SK-A02-04 |
| A03 | — | Pengingat tepat pada ambang terhitung | SK-A03-01, SK-A03-02 |
| A04 | — | Fasilitas pada pencarian/filter; tidak memicu | SK-A04-02, SK-A04-04 |
| A05 | — | Perubahan data tanpa perubahan kode | SK-A05-01, SK-A05-02 |
| A06 | — | Baterai ≤15% per jam | SK-A06-01 |
| A07 | — | Accessibility Scanner tanpa isu kritis | SK-A07-01 |

## Matriks keterlacakan: test case Lampiran A → skenario

| TC | Requirement | Skenario |
|---|---|---|
| TC-01 | F01 | SK-F01-01, SK-F01-02, SK-F01-03 |
| TC-02 | F02 | SK-F02-02, SK-F02-03 |
| TC-03 | F02 | SK-F02-04, SK-F02-05 |
| TC-04 | F02, A02 | SK-A02-01, SK-A02-02, SK-A02-03, SK-A02-04 |
| TC-05 | F03 | SK-F03-01 |
| TC-06 | F04 | SK-F04-01 |
| TC-07 | F05 | SK-F05-01, SK-F05-02, SK-F05-04, SK-F05-08, SK-F05-09 |
| TC-08 | F06 | SK-F06-01, SK-F06-03, SK-F06-04, SK-F06-06, SK-F04-09 |
| TC-09 | F07 | SK-F07-01 |
| TC-10 | F07, A03 | SK-F07-04, SK-A03-01 |
| TC-11 | F08 | SK-F08-01 |
| TC-12 | F08 | SK-F08-03 |
| TC-13 | A01 | SK-A01-01 |

## Kesiapan build per 16 November 2026

Disusun dari `pubspec.yaml` dan `PROGRESS.md` pada cabang `main` (commit `1a3d59c`), tanpa menjalankan aplikasi. Periksa ulang sebelum setiap putaran uji; skenario yang fiturnya belum ada dicatat `Terblokir`, bukan `Gagal`.

| Kemampuan | Keadaan pada build | Skenario yang terdampak |
|---|---|---|
| Notifikasi sistem dan aksi di layar kunci | Paket notifikasi belum ada; pemicu tampil sebagai kartu di dalam aplikasi | SK-F02-20, SK-F03-08, SK-F04-01, SK-F04-06, SK-F07-15 |
| Kontrol media layar kunci/earphone | Layanan media belum ada | SK-F04-07, SK-F04-08 |
| Suara TTS (prompt, arahan navigasi, pengingat) | Paket TTS belum ada | SK-F03-09, SK-F04-03, SK-F04-09 s.d. SK-F04-13, SK-F06-11 |
| Pemindai QR dengan kamera | Paket pemindai belum ada; layar pindai memakai kamera tiruan (kode dipilih dari daftar), sehingga hanya alur setelah kode terbaca yang dapat dicoba | SK-A02-01 s.d. SK-A02-09 |
| Penghitung langkah dari sensor | Paket pedometer belum ada; langkah diperkirakan dari jarak | SK-F08-03, SK-F08-15 |
| Penyimpanan dan ekspor log sesi | Basis data lokal belum ada | SK-F02-21, SK-F08-11 (bagian log), SK-F08-18 |
| Penyesuaian interval GPS (A06) | Belum dikerjakan | SK-A06-02 |
| GPS nyata di ponsel Android | Sudah dibangun, belum pernah diuji di perangkat | Seluruh skenario berkode L |

## Hal terbuka yang memengaruhi pengujian

| Hal | Dampak pada pengujian | Rujukan |
|---|---|---|
| Jam operasional 08.00–16.00 belum terverifikasi | Waktu pada TC-10, SK-A03-*, SK-F07-04/05 mengikuti data; hitung ulang bila berubah | Lampiran B butir 4 |
| Panjang dan durasi rute berbeda antara PRD dan data | SK-F08-01 mencatat selisihnya; nilai acuan menunggu keputusan tim | PROGRESS #27 |
| P11 Curug Omas diduga di luar zona | SK-NG-02, SK-F02-18, SK-F07-12 | PROGRESS #13 |
| Koordinat `ESTIMATE` (P02, P08, P10, FS02, FS05) | Tidak dipakai sebagai titik referensi SK-F01-03; hasil SK-F02-02 pada POI tersebut dicatat dengan keterangan | PROGRESS #28 |
| P07 dan P09 berjarak ±45 m dengan radius bertumpuk | SK-F02-13 | PROGRESS #29 |
| Fasilitas FS06–FS10 belum ada di PRD | SK-A04-* mencatat keberadaannya | PROGRESS #25 |
| Teks POI masih draf (`[ISI]`), fakta bertanda `[VERIFIKASI]` | SK-F03-02 dan SK-F03-12 tidak dapat lulus sebelum teks final dan sumber resmi tersedia | PRD §8.2, Lampiran B butir 5 |
| Izin pemasangan papan QR | SK-A02-* di lapangan memakai papan sementara bila izin permanen belum ada | Lampiran B butir 6 |
| Peta luring memakai basemap vektor, PRD menyebut MBTiles | SK-A01-03 menguji hasilnya (peta tampil luring), bukan teknologinya | PROGRESS #26 |
| Naskah narasi dapat merujuk urutan tempat yang lama | SK-F03-13 | PROGRESS #30 |

## Catatan penggunaan AI

Draf skenario ini disusun dengan bantuan Claude Code pada 16 November 2026 dari dokumen-dokumen di atas. Sesuai PRD §8.2, QA meninjau setiap skenario, menjalankannya secara manual, dan mencatat hasil aktual apa adanya. Catat penggunaan ini pada AI & Tools Disclosure.
