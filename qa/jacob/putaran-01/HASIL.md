# Hasil uji putaran 01 — Jacob (QA-1)

Status dokumen: Aktif (putaran berjalan)
Penguji: Jacob (QA-1)
Build (APK): `apk-latest` — **isi hash commit / tanggal rilis saat mengunduh:** ______
Perangkat: ______ (merek, model, versi Android) — satu HP milik penguji
Mulai: ____ · Selesai: ____

Panduan isi: lihat `qa/README.md` §4. Skenario lengkap (prasyarat, langkah, hasil yang diharapkan) ada di
`docs/qa/scenario/` dengan ID yang sama. Kolom **Label** dan **Cara uji di luar Tahura** dari `qa/RENCANA_QA.md` §3.

**Hasil:** `Lulus` · `Sebagian` · `Gagal` · `Terblokir` · kosong = belum dijalankan.
**Lintas = Ya:** skenario sensitif perangkat; Dimas juga menjalankannya di HP-nya sendiri (`qa/RENCANA_QA.md` §2). Tidak perlu bertukar HP.
**Bukti:** nama berkas di Drive (`<ID>_jacob_<tanggal>.<ext>`) atau tautan. **Cacat:** ID dari `CACAT.md` (mis. `CJ-001`).

Jumlah: 107 skenario bagian sendiri (LUAR 53 · TAHURA→MOCK 41 · TAHURA→GPS 10 · TAHURA→LUAR 3) + 6 skenario lintas perangkat dari bagian Dimas.

## Skenario bagian sendiri

| ID | Skenario | Metode | Label | Cara uji di luar Tahura | Konfirmasi Tahura | Lintas | Hasil | Bukti | Catatan / Cacat |
|---|---|---|---|---|---|---|---|---|---|
| SK-F01-01 | Posisi tampil setelah izin diberikan | L | TAHURA→GPS | GPS nyata di area terbuka mana saja (lapangan/halaman kampus). |  | Ya | | | |
| SK-F01-02 | Posisi diperbarui saat berjalan | L | TAHURA→GPS | GPS nyata: jalan lurus 20 m terukur di area terbuka. |  |  | | | |
| SK-F01-03 | Deviasi posisi terhadap titik referensi | L | TAHURA→GPS | GPS nyata pada ≥3 titik referensi di luar Tahura yang koordinatnya diketahui (mis. sudut lapangan dari peta). | Ya |  | | | |
| SK-F01-04 | Izin lokasi ditolak | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F01-05 | Indikator "GPS lemah" | L | TAHURA→GPS | GPS nyata: dari area terbuka masuk ke dalam gedung/di bawah atap beton. |  |  | | | |
| SK-F01-06 | Pembacaan GPS lemah tidak dipakai untuk pemicu | L, O | TAHURA→MOCK | GPX 01 + menu debug (7 ketukan) → GPS lemah tiruan saat mendekati P05. |  |  | | | |
| SK-F01-07 | Lokasi tetap dibaca saat layar mati | L | TAHURA→GPS | GPS nyata: sesi aktif, layar dikunci, jalan 15 menit di luar ruangan. |  | Ya | | | |
| SK-F01-08 | Pengguna diam tetap menghasilkan pembacaan | L | TAHURA→GPS | GPS nyata: sesi aktif, diam 5 menit di luar ruangan. |  |  | | | |
| SK-F01-09 | Layanan lokasi perangkat dimatikan | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F01-10 | Penguji di luar kawasan | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F01-11 | Pelacakan berhenti setelah sesi diakhiri | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F02-01 | Getaran saat mendekati POI | L, M | TAHURA→MOCK | GPX 01. |  |  | | | |
| SK-F02-02 | Pemicu pada 10 POI inti | L | TAHURA→MOCK | GPX 06b (melewati 10 POI inti); konfirmasi GPS asli di Tahura. | Ya |  | | | |
| SK-F02-03 | Tidak ada pemicu palsu | L | TAHURA→MOCK | GPX 06b: catat setiap pemicu, pastikan hanya di POI yang benar. | Ya |  | | | |
| SK-F02-04 | Tidak berulang selama berada di dalam radius | L, O | TAHURA→MOCK | GPX 01 (diam 4 menit di dalam radius). |  |  | | | |
| SK-F02-05 | Keluar lalu masuk kembali sebelum 10 menit | L, O | TAHURA→MOCK | GPX 02. |  |  | | | |
| SK-F02-06 | Pemicu ulang setelah keluar dan lewat 10 menit | L, O | TAHURA→MOCK | GPX 03. |  |  | | | |
| SK-F02-07 | Getaran tidak berulang di tepi zona mendekati | L, O | TAHURA→MOCK | GPX 04. |  |  | | | |
| SK-F02-08 | Pendekatan baru setelah menjauh | L, O | TAHURA→MOCK | GPX 04 (bagian akhir: menjauh lalu mendekat lagi). |  |  | | | |
| SK-F02-09 | Melewati POI yang sudah dikunjungi | L, M | TAHURA→MOCK | GPX 06 (berakhir kembali di P01 yang sudah dikunjungi). |  |  | | | |
| SK-F02-10 | Pilihan "Nanti" tidak menandai dikunjungi | M, L | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F02-11 | Pilihan "Dengarkan" menandai dikunjungi | M, L | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F02-12 | Pilihan "Lihat" menandai dikunjungi | M, L | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F02-13 | Dua POI berdekatan | L, O | TAHURA→MOCK | GPX 05. |  |  | | | |
| SK-F02-14 | Lompatan GPS sesaat tidak memicu | O | LUAR | Lampirkan hasil `flutter test` (CI). |  |  | | | |
| SK-F02-15 | Banner saat GPS lemah 60 detik | L | TAHURA→GPS | GPS nyata di dalam gedung ≥60 detik; atau GPX 01 + GPS lemah tiruan (menu debug). |  |  | | | |
| SK-F02-16 | Pemilihan POI secara manual | P, M | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F02-17 | Aturan khusus P01 Gerbang | L | TAHURA→MOCK | GPX 10. |  |  | | | |
| SK-F02-18 | P11 hanya aktif pada rute Trekking | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F02-19 | Tanpa sesi tidak ada pemicu | L | TAHURA→MOCK | GPX 01 tanpa memulai sesi. |  |  | | | |
| SK-F02-20 | Notifikasi pemicu pada layar terkunci | L | TAHURA→MOCK | GPX 01 dengan layar terkunci. |  | Ya | | | |
| SK-F02-21 | Pencatatan pemicu dan kunjungan | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F02-22 | Izin notifikasi ditolak | L, M | TAHURA→MOCK | GPX 01 setelah izin notifikasi ditolak. |  |  | | | |
| SK-A02-01 | QR Gua Jepang, luring | L, P | TAHURA→LUAR | Papan QR P05 dicetak, dipindai dalam mode pesawat di mana saja. | Ya | Ya | | | |
| SK-A02-02 | QR Gua Belanda, luring | L, P | TAHURA→LUAR | Papan QR P06 dicetak, dipindai dalam mode pesawat di mana saja. | Ya |  | | | |
| SK-A02-03 | QR asing | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A02-04 | QR berskema benar dengan ID tidak dikenal | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A02-05 | Pemindaian QR menandai dikunjungi | P, M | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A02-06 | QR di kondisi gelap | L | TAHURA→LUAR | Papan QR dicetak, dipindai di ruangan gelap dengan senter ponsel. | Ya |  | | | |
| SK-A02-07 | Izin kamera ditolak | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A02-08 | QR untuk POI yang sudah dikunjungi | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A02-09 | QR dipindai tanpa sesi aktif | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-01 | Kata kunci "gua" | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-02 | Kata kunci "toilet" | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-03 | Pencocokan sebagian dan tidak peka huruf besar/kecil | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-04 | Filter kategori | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-05 | Filter digabung dengan kata kunci | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-06 | Urutan menurut jarak jalan kaki | L, M | TAHURA→MOCK | GPX 07: hentikan di tengah jalan, lalu cari. |  |  | | | |
| SK-F05-07 | Urutan berubah mengikuti posisi | L, M | TAHURA→MOCK | GPX 07: cari di awal dan di akhir, bandingkan urutan. |  |  | | | |
| SK-F05-08 | Kecepatan pencarian luring | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-09 | Kata kunci tidak ditemukan | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-10 | Satu salah ketik | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-11 | Batas toleransi salah ketik | P, O | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-12 | Sinonim | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-13 | Memilih hasil membuka detail | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-14 | Memilih hasil memulai navigasi | P, M | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-15 | Masukan tidak lazim | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F05-16 | Pencarian tanpa posisi | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A04-01 | Marker fasilitas di peta | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A04-02 | Filter "Fasilitas" | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A04-03 | Fasilitas dapat dinavigasi | L, M | TAHURA→MOCK | GPX 09 sambil navigasi ke FS06. |  |  | | | |
| SK-A04-04 | Fasilitas tidak memicu notifikasi | L | TAHURA→MOCK | GPX 09. |  |  | | | |
| SK-A04-05 | Setiap jenis fasilitas dapat dicari | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F06-01 | Rute mengikuti jalur setapak | L | TAHURA→MOCK | GPX 07. |  |  | | | |
| SK-F06-02 | Sisa jarak dan ETA berkurang | L | TAHURA→MOCK | GPX 07. |  |  | | | |
| SK-F06-03 | Mencapai tiga tujuan hanya dengan navigasi | L | TAHURA→MOCK | GPX 06: navigasi ke 3 POI berurutan; konfirmasi berjalan nyata di Tahura. | Ya |  | | | |
| SK-F06-04 | Hitung ulang setelah menyimpang | L | TAHURA→MOCK | GPX 08 (menyimpang 50 m). |  |  | | | |
| SK-F06-05 | Navigasi dalam mode pesawat | L | TAHURA→MOCK | GPX 07 dalam mode pesawat. |  |  | | | |
| SK-F06-06 | Akurasi ETA | L | TAHURA→GPS | Sebagian: GPS nyata, jalan rute datar terukur di luar Tahura dan bandingkan ETA. Tanjakan nyata hanya di Tahura. | Ya |  | | | |
| SK-F06-07 | Status tiba | L | TAHURA→MOCK | GPX 07. |  |  | | | |
| SK-F06-08 | Tiba tidak memicu ulang POI | L, M | TAHURA→MOCK | GPX 07. |  |  | | | |
| SK-F06-09 | Tawaran "Buka detail" saat tiba | L, M | TAHURA→MOCK | GPX 07. |  |  | | | |
| SK-F06-10 | Tiba di fasilitas | L, M | TAHURA→MOCK | GPX 09. |  |  | | | |
| SK-F06-11 | Arahan di persimpangan | L | TAHURA→MOCK | GPX 07. |  |  | | | |
| SK-F06-12 | Membatalkan navigasi | P, M | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F06-13 | Titik masuk navigasi | M, L | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F06-14 | Simpangan kecil tidak menghitung ulang | L | TAHURA→MOCK | GPX 08 (menyimpang 15 m). |  |  | | | |
| SK-F06-15 | ETA memperhitungkan tanjakan | M, O | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F06-16 | Rute terpendek | O | LUAR | Lampirkan hasil `flutter test` (CI). |  |  | | | |
| SK-F06-17 | GPS lemah selama navigasi | L | TAHURA→MOCK | GPX 07 + GPS lemah tiruan (menu debug). |  |  | | | |
| SK-F06-18 | Seluruh POI dan fasilitas terjangkau | M, O | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-A01-01 | Alur F01–F08 penuh dalam mode pesawat | L | TAHURA→MOCK | GPX 06 dalam mode pesawat. |  |  | | | |
| SK-A01-02 | Pemakaian pertama tanpa internet | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A01-03 | Peta luring | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A01-04 | Atribusi peta | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A01-05 | Lapisan satelit tanpa internet | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A01-06 | Sinyal hilang-timbul | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A01-07 | Ukuran pemasangan | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A06-01 | Pemakaian baterai per jam sesi | L | TAHURA→GPS | GPS nyata: sesi 60 menit di luar ruangan (berjalan/duduk), catat baterai awal dan akhir. |  | Ya | | | |
| SK-A06-02 | Pelacakan saat diam | L | TAHURA→GPS | GPS nyata: sesi aktif, diam 10 menit. |  |  | | | |
| SK-INS-01 | Terpasang dan terbuka di ≥2 perangkat uji | P | LUAR | Ponsel uji, di mana saja. |  | Ya | | | |
| SK-INS-02 | Pembaruan di atas versi lama | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-INS-03 | Aplikasi dibuka kembali | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-E2E-01 | 1. Start | — | TAHURA→MOCK | GPX 06 (alur utama penuh); diulang sebagai demo di Tahura. | Ya |  | | | |
| SK-E2E-02 | 2. Explore | — | TAHURA→MOCK | GPX 06 (alur utama penuh); diulang sebagai demo di Tahura. | Ya |  | | | |
| SK-E2E-03 | 3. Location Trigger | — | TAHURA→MOCK | GPX 06 (alur utama penuh); diulang sebagai demo di Tahura. | Ya |  | | | |
| SK-E2E-04 | 4. Information | — | TAHURA→MOCK | GPX 06 (alur utama penuh); diulang sebagai demo di Tahura. | Ya |  | | | |
| SK-E2E-05 | 5. Recommendation | — | TAHURA→MOCK | GPX 06 (alur utama penuh); diulang sebagai demo di Tahura. | Ya |  | | | |
| SK-E2E-06 | 6. Search Destination | — | TAHURA→MOCK | GPX 06 (alur utama penuh); diulang sebagai demo di Tahura. | Ya |  | | | |
| SK-E2E-07 | 7. Navigation | — | TAHURA→MOCK | GPX 06 (alur utama penuh); diulang sebagai demo di Tahura. | Ya |  | | | |
| SK-E2E-08 | 8. Lanjut eksplorasi dan pengingat | — | TAHURA→MOCK | GPX 06 (alur utama penuh); diulang sebagai demo di Tahura. | Ya |  | | | |
| SK-E2E-09 | 9. Selesai | — | TAHURA→MOCK | GPX 06 (alur utama penuh); diulang sebagai demo di Tahura. | Ya |  | | | |
| SK-KTH-01 | Berpindah aplikasi selama sesi | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-KTH-02 | Layar diputar | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-KTH-03 | Baterai rendah / hemat daya | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-KTH-04 | Sesi panjang | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-KTH-05 | Tombol kembali Android | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |

## Uji lintas perangkat (skenario bagian Dimas, dijalankan di HP sendiri)

Dimas juga menguji skenario ini di HP-nya. Isi hasil dari HP Anda; langkahnya ada di `docs/qa/scenario/`.

| ID | Skenario | Metode | Label | Cara uji di luar Tahura | Konfirmasi Tahura | Lintas | Hasil | Bukti | Catatan / Cacat |
|---|---|---|---|---|---|---|---|---|---|
| SK-F03-09 | Cadangan Text-to-Speech perangkat | P | LUAR | Ponsel uji, di mana saja. |  | Ya | | | |
| SK-F04-01 | Satu kunjungan POI dengan layar terkunci | L | TAHURA→MOCK | GPX 01 dengan layar terkunci dan earphone. | Ya | Ya | | | |
| SK-F04-07 | Kontrol media di layar kunci | P | LUAR | Ponsel uji, di mana saja. |  | Ya | | | |
| SK-F04-13 | Suara tersedia tanpa internet | L | TAHURA→MOCK | GPX 07 dalam mode pesawat. |  | Ya | | | |
| SK-A03-02 | Suara dan notifikasi | M, L | LUAR | Mode demo / menu debug. |  | Ya | | | |
| SK-F08-03 | Uji 200 langkah | L | TAHURA→GPS | Langkah nyata: 200 langkah dihitung manual di koridor/lapangan mana saja. |  | Ya | | | |
