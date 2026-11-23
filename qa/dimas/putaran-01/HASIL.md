# Hasil uji putaran 01 — Michael Dimas (QA-2)

Status dokumen: Aktif (putaran berjalan)
Penguji: Michael Dimas (QA-2)
Build (APK): `apk-latest` — **isi hash commit / tanggal rilis saat mengunduh:** ______
Perangkat: ______ (merek, model, versi Android) — satu HP milik penguji
Mulai: ____ · Selesai: ____

Panduan isi: lihat `qa/README.md` §4. Skenario lengkap (prasyarat, langkah, hasil yang diharapkan) ada di
`docs/qa/scenario/` dengan ID yang sama. Kolom **Label** dan **Cara uji di luar Tahura** dari `qa/RENCANA_QA.md` §3.

**Hasil:** `Lulus` · `Sebagian` · `Gagal` · `Terblokir` · kosong = belum dijalankan.
**Lintas = Ya:** skenario sensitif perangkat; Jacob juga menjalankannya di HP-nya sendiri (`qa/RENCANA_QA.md` §2). Tidak perlu bertukar HP.
**Bukti:** screenshot di `bukti/` → `[ss](bukti/<ID>_dimas_<tanggal>.jpg)`; video di Drive → `[video](tautan Drive)` (`qa/README.md` §4). **Cacat:** ID dari `CACAT.md` (mis. `CD-001`).

Jumlah: 112 skenario bagian sendiri (LUAR 93 · TAHURA→MOCK 17 · TAHURA→GPS 2 · TAHURA→LUAR 0) + 6 skenario lintas perangkat dari bagian Jacob.

## Skenario bagian sendiri

| ID | Skenario | Metode | Label | Cara uji di luar Tahura | Konfirmasi Tahura | Lintas | Hasil | Bukti | Catatan / Cacat |
|---|---|---|---|---|---|---|---|---|---|
| SK-F03-01 | Kelengkapan 10 POI inti dalam mode pesawat | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F03-02 | Panjang dan bahasa teks | D, P | LUAR | Periksa dokumen/data. |  |  | | | |
| SK-F03-03 | Fakta kunci | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F03-04 | Jumlah dan asal foto | P, D | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F03-05 | Durasi narasi audio | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F03-06 | Estimasi lama kunjungan | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F03-07 | Kontrol pemutar audio | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F03-08 | POI Detail dari notifikasi | L, P | TAHURA→MOCK | GPX 01 dengan layar terkunci, ketuk notifikasi. |  |  | | | |
| SK-F03-09 | Cadangan Text-to-Speech perangkat | P | LUAR | Ponsel uji, di mana saja. |  | Ya | | | |
| SK-F03-10 | Catatan keselamatan gua | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F03-11 | Konten khusus per POI | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F03-12 | Sumber setiap fakta | D | LUAR | Periksa dokumen/data. |  |  | | | |
| SK-F03-13 | Kesesuaian audio dengan naskah | P, D | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F03-14 | Audio berlanjut di luar layar POI Detail | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F03-15 | POI Detail dari setiap pintu masuk | P, M | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F04-01 | Satu kunjungan POI dengan layar terkunci | L | TAHURA→MOCK | GPX 01 dengan layar terkunci dan earphone. | Ya | Ya | | | |
| SK-F04-02 | Getaran dan bunyi saat mendekati | L | TAHURA→MOCK | GPX 01. |  |  | | | |
| SK-F04-03 | Prompt suara saat terpicu | L | TAHURA→MOCK | GPX 01. |  |  | | | |
| SK-F04-04 | Auto-Play aktif | L, M | TAHURA→MOCK | GPX 01 dengan Auto-Play aktif. |  |  | | | |
| SK-F04-05 | Auto-Play nonaktif | L, M | TAHURA→MOCK | GPX 01 dengan Auto-Play nonaktif. |  |  | | | |
| SK-F04-06 | Aksi "Dengarkan" tanpa membuka aplikasi | L | TAHURA→MOCK | GPX 01 dengan layar terkunci. |  |  | | | |
| SK-F04-07 | Kontrol media di layar kunci | P | LUAR | Ponsel uji, di mana saja. |  | Ya | | | |
| SK-F04-08 | Tombol earphone | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F04-09 | Arahan suara di setiap simpul belokan | L | TAHURA→MOCK | GPX 07 sambil navigasi ke P06. |  |  | | | |
| SK-F04-10 | Pengumuman tiba melalui suara | L | TAHURA→MOCK | GPX 07. |  |  | | | |
| SK-F04-11 | Pengingat jam tutup melalui suara | M, L | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F04-12 | Pengingat hidrasi melalui suara | M, L | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F04-13 | Suara tersedia tanpa internet | L | TAHURA→MOCK | GPX 07 dalam mode pesawat. |  | Ya | | | |
| SK-F04-14 | Arahan navigasi saat narasi diputar | L | TAHURA→MOCK | GPX 07 sambil narasi diputar. |  |  | | | |
| SK-F04-15 | Panggilan telepon saat narasi | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F04-16 | Kunjungan tanpa melihat layar oleh responden | L | TAHURA→MOCK | Responden memakai GPX 01 di kampus (bagian dari usability). |  |  | | | |
| SK-F07-01 | Rekomendasi selalu POI yang belum dikunjungi | L, M | TAHURA→MOCK | GPX 06. |  |  | | | |
| SK-F07-02 | Rekomendasi muncul setelah menutup POI Detail | P, M | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F07-03 | Rekomendasi muncul setelah keluar radius | L | TAHURA→MOCK | GPX 01, lalu GPX 02 (keluar radius). |  |  | | | |
| SK-F07-04 | Pukul 15.30 di P06: kembali ke gerbang | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F07-05 | Saringan waktu sebelum jam tutup | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F07-06 | Mengubah minat mengubah urutan | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F07-07 | Navigasi satu ketukan | P, M | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F07-08 | Satu utama, dua alternatif, dan alasan | P, M | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F07-09 | POI "Nanti" tetap kandidat | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F07-10 | Semua POI sudah dikunjungi | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F07-11 | Pengaruh rute aktif | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F07-12 | P11 di luar rute Trekking | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F07-13 | Gerbang bukan kandidat | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F07-14 | Bobot dibaca dari berkas data | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F07-15 | Rekomendasi saat layar terkunci | L | TAHURA→MOCK | GPX 01 dengan layar terkunci. |  |  | | | |
| SK-A03-01 | Pengingat pada ambang terhitung | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-A03-02 | Suara dan notifikasi | M, L | LUAR | Mode demo / menu debug. |  | Ya | | | |
| SK-A03-03 | Opsi navigasi ke gerbang | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-A03-04 | Ambang bergeser mengikuti posisi | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-A03-05 | Contoh skenario PRD | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-A03-06 | Jam operasional dari data | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-A03-07 | Tidak berulang dalam satu sesi | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-A03-08 | Sesi dimulai setelah ambang | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-A03-09 | Tanpa sesi tidak ada pengingat | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F08-01 | Tiga rute beserta datanya | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F08-02 | Kelayakan rute terhadap jam tutup | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F08-03 | Uji 200 langkah | L | TAHURA→GPS | Langkah nyata: 200 langkah dihitung manual di koridor/lapangan mana saja. |  | Ya | | | |
| SK-F08-04 | Jarak tempuh | L | TAHURA→GPS | GPS nyata: jalan pada lintasan terukur (mis. lintasan lari 400 m). |  |  | | | |
| SK-F08-05 | Durasi sesi | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F08-06 | Estimasi kalori | P, M | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F08-07 | Berat badan opsional dan hanya di perangkat | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F08-08 | Pengingat hidrasi bawaan 45 menit | M, L | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F08-09 | Interval hidrasi diubah | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F08-10 | Penanda titik istirahat dan fasilitas | P, M | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F08-11 | Ringkasan sesi sesuai log | L, M | TAHURA→MOCK | GPX 06, lalu bandingkan ringkasan dengan log sesi. |  |  | | | |
| SK-F08-12 | POI belum dikunjungi pada ringkasan | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-F08-13 | Data aktivitas hanya di perangkat | P, D | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F08-14 | Konten flora-fauna | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F08-15 | Izin aktivitas fisik ditolak | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F08-16 | Statistik sesi selama menjelajah | L | TAHURA→MOCK | GPX 06 (langkah tetap 0 karena ponsel diam: catat, bukan cacat). |  |  | | | |
| SK-F08-17 | Mulai dan akhiri jelajah | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F08-18 | Aplikasi tertutup di tengah sesi | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-F08-19 | Rute Trekking mengaktifkan P11 | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A05-01 | Mengubah teks satu POI | D, P | LUAR | Periksa dokumen/data. |  |  | | | |
| SK-A05-02 | Mengubah radius satu POI | D, M | LUAR | Periksa dokumen/data. |  |  | | | |
| SK-A05-03 | Mengubah jam operasional | D, M | LUAR | Periksa dokumen/data. |  |  | | | |
| SK-A05-04 | Mengubah data rute | D, P | LUAR | Periksa dokumen/data. |  |  | | | |
| SK-A05-05 | Data tidak valid ditolak | D | LUAR | Periksa dokumen/data. |  |  | | | |
| SK-A05-06 | Data bawaan lolos validasi | D | LUAR | Periksa dokumen/data. |  |  | | | |
| SK-A07-01 | Accessibility Scanner | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A07-02 | Ukuran teks diperbesar | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A07-03 | Ukuran tombol utama | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A07-04 | Label pembaca layar | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-A07-05 | Kontras | P, L | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-ONB-01 | Onboarding dan permintaan izin | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-ONB-02 | Semua izin ditolak | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-ONB-03 | Melewati onboarding | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-ONB-04 | Izin diberikan belakangan | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-HOM-01 | Memilih minat dan rute | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-HOM-02 | Informasi jam operasional | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-SET-01 | Auto-Play | M, L | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-SET-02 | Interval hidrasi | M | LUAR | Mode demo / menu debug. |  |  | | | |
| SK-SET-03 | Ukuran teks | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-SET-04 | Informasi data luring | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-SET-05 | Pengaturan bertahan | P | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-NG-01 | Tanpa tiket/pembayaran | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-NG-02 | Hanya zona Dago Pakar | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-NG-03 | Tanpa AR, beacon/BLE, computer vision | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-NG-04 | Tanpa CMS/dasbor admin | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-NG-05 | Tanpa akun dan data di server | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-NG-06 | Bukan alat darurat dan tanpa pelacakan oleh pengelola | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-NG-07 | Tanpa pemesanan atau transaksi | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-NG-08 | Hanya Bahasa Indonesia | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-TKS-01 | Tanpa detail operasional | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-TKS-02 | Sapaan dan gaya bahasa | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-TKS-03 | Format angka | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-TKS-04 | Penanda yang tertinggal | — | LUAR | Ponsel uji, di mana saja. |  |  | | | |
| SK-USB-01 | Jumlah responden dan kelengkapan data | — | LUAR | Responden di kampus; tugas berbasis lokasi memakai GPX 01/07. |  |  | | | |
| SK-USB-02 | Kunjungan POI tanpa melihat layar (T3) | — | LUAR | Responden di kampus; tugas berbasis lokasi memakai GPX 01/07. |  |  | | | |
| SK-USB-03 | Skor SUS | — | LUAR | Responden di kampus; tugas berbasis lokasi memakai GPX 01/07. |  |  | | | |
| SK-USB-04 | Temuan dan tindak lanjut | — | LUAR | Responden di kampus; tugas berbasis lokasi memakai GPX 01/07. |  |  | | | |

## Uji lintas perangkat (skenario bagian Jacob, dijalankan di HP sendiri)

Jacob juga menguji skenario ini di HP-nya. Isi hasil dari HP Anda; langkahnya ada di `docs/qa/scenario/`.

| ID | Skenario | Metode | Label | Cara uji di luar Tahura | Konfirmasi Tahura | Lintas | Hasil | Bukti | Catatan / Cacat |
|---|---|---|---|---|---|---|---|---|---|
| SK-F01-01 | Posisi tampil setelah izin diberikan | L | TAHURA→GPS | GPS nyata di area terbuka mana saja (lapangan/halaman kampus). |  | Ya | | | |
| SK-F01-07 | Lokasi tetap dibaca saat layar mati | L | TAHURA→GPS | GPS nyata: sesi aktif, layar dikunci, jalan 15 menit di luar ruangan. |  | Ya | | | |
| SK-F02-20 | Notifikasi pemicu pada layar terkunci | L | TAHURA→MOCK | GPX 01 dengan layar terkunci. |  | Ya | | | |
| SK-A02-01 | QR Gua Jepang, luring | L, P | TAHURA→LUAR | Papan QR P05 dicetak, dipindai dalam mode pesawat di mana saja. | Ya | Ya | | | |
| SK-A06-01 | Pemakaian baterai per jam sesi | L | TAHURA→GPS | GPS nyata: sesi 60 menit di luar ruangan (berjalan/duduk), catat baterai awal dan akhir. |  | Ya | | | |
| SK-INS-01 | Terpasang dan terbuka di ≥2 perangkat uji | P | LUAR | Ponsel uji, di mana saja. |  | Ya | | | |
