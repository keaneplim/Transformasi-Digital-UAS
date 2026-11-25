# Hasil uji QA1 — Jacob

Penguji: Jacob Reinhard Marudut Siagian (QA1)
Perangkat: POCO X8 Pro, Android 16 (Xiaomi HyperOS 3.0.305.0), penyimpanan terpakai 165,2/528 GB. [ss](bukti/HP/perangkat_jacob_2026-11-24.jpg)

**Hasil:** `Lulus` · `Sebagian` · `Gagal` · kosong = belum dijalankan.
**Penjelasan:** angka terukur, catatan, ID cacat, dan bukti, mis. `CJ-001, [ss](bukti/F03/SK-F03-08_jacob_2026-11-23.jpg)`.
Metode, langkah, hasil yang diharapkan, label tempat uji, cara uji di luar Tahura, Fase 2, dan lintas perangkat untuk setiap ID ada di `qa/scenario/` (penjelasan kolom: `qa/scenario/README.md`, bagian *Pelaksanaan*). Aturan pengisian: `qa/README.md` §4.

## Fase 1 — di luar Tahura

Build (APK): `apk-latest` = Jelajah Taman v0.1.0+1, release build (arm64-v8a) of commit [32018e3](https://github.com/keaneplim/Transformasi-Digital-UAS/commit/32018e386d13724b5ebf258721d7d0d5cc643b05), built 2026-11-23 13:15 UTC.
Mulai: 24 November 2026 · Selesai: ____

Semua skenario dijalankan di luar Tahura. Jumlah: 107 skenario sendiri + 6 skenario lintas perangkat dari QA2 (Mike).

### 1A. Tanpa GPS: ponsel, mode demo / menu debug, dokumen (53)

| ID | Skenario | Hasil | Penjelasan |
|---|---|---|---|
| SK-F01-04 | Izin lokasi ditolak | Lulus | Izin lokasi ditolak saat onboarding, aplikasi tidak macet; peta tampil tanpa titik biru dengan kartu "Lokasi belum diizinkan" + tombol "Izinkan lokasi" dan "Pilih manual"; "Pilih manual" membuka POI (Area Rumput / Piknik, Dikunjungi). Pembukaan lewat QR dibuktikan di SK-A02-09 (QR tidak memakai lokasi; diuji saat izin lokasi sudah diberikan). [ss](bukti/F01/SK-F01-04_jacob_2026-11-24.jpg), [ss](bukti/F01/SK-F01-04_jacob_2026-11-24_2.jpg) |
| SK-F01-09 | Layanan lokasi perangkat dimatikan | Gagal | CJ-006. Lokasi dimatikan dari panel cepat: aplikasi tidak macet, tetapi tidak ada ajakan menyalakan lokasi; peta tetap menampilkan "Anda di luar kawasan · 3,0 km ke gerbang" seperti saat lokasi menyala. Setelah dinyalakan lagi tidak ada perubahan yang terlihat (penguji di luar kawasan, titik biru memang tidak tampil di peta taman). [ss](bukti/F01/SK-F01-09_jacob_2026-11-24.jpg) |
| SK-F01-10 | Penguji di luar kawasan | Lulus | Izin lokasi diberikan, ±3 km dari gerbang, sesi aktif >2 menit: label "Anda di luar kawasan · 3,0 km ke gerbang" dan panah arah di tepi peta; tidak ada pemicu; aplikasi tetap dapat dijelajahi. [ss](bukti/F01/SK-F01-10_jacob_2026-11-24.jpg) |
| SK-F01-11 | Pelacakan berhenti setelah sesi diakhiri | Lulus | "Akhiri Jelajah" → ringkasan sesi tampil; layar dikunci ±2 menit: tidak ada notifikasi layanan pemandu Jelajah Taman di layar kunci/bilah notifikasi. [ss](bukti/F01/SK-F01-11_jacob_2026-11-24.jpg), [ss](bukti/F01/SK-F01-11_jacob_2026-11-24_2.jpg) |
| SK-F02-10 | Pilihan "Nanti" tidak menandai dikunjungi | Lulus | Mode demo, Pindah ke Monumen → "Nanti": tetap "0 dikunjungi". Setelah Kolam Pakar dan Koleksi Flora ("Selesai, lihat berikutnya"), Monumen tetap muncul sebagai rekomendasi utama ("Terdekat · Sesuai minat Sejarah · Ada di rute Santai"). Catatan: lembar rekomendasi hanya muncul lewat "Selesai, lihat berikutnya", tidak lewat tombol ←. [ss](bukti/F02/SK-F02-10_jacob_2026-11-25.jpg), [ss](bukti/F02/SK-F02-10_jacob_2026-11-25_2.jpg) |
| SK-F02-11 | Pilihan "Dengarkan" menandai dikunjungi | Lulus | Mode demo, Pindah ke Kolam Pakar → kartu pemicu → "Dengarkan": narasi berputar, POI berstatus Dikunjungi. |
| SK-F02-12 | Pilihan "Lihat" menandai dikunjungi | Lulus | Mode demo, Pindah ke Titik Koleksi Flora → "Lihat": POI Detail terbuka, berstatus Dikunjungi. |
| SK-F02-14 | Lompatan GPS sesaat tidak memicu | Lulus | Uji otomatis (metode O): `test/modules/trigger/geofence_engine_test.dart` kasus "2. single fix inside r then outside → no trigger (debounce)". CI run #42 untuk build `32018e3` lulus (job "Content · format · analyze · architecture · test", 23 Nov 13:08 UTC, [log](https://github.com/keaneplim/Transformasi-Digital-UAS/actions/runs/45180612777)). Diperiksa asisten AI, bukan uji ponsel. |
| SK-F02-16 | Pemilihan POI secara manual | Lulus | Izin lokasi ditolak → kartu peta "Pilih manual" → Area Rumput / Piknik terbuka dan berstatus Dikunjungi. [ss](bukti/F01/SK-F01-04_jacob_2026-11-24_2.jpg) |
| SK-F02-18 | P11 hanya aktif pada rute Trekking | Lulus | Mode demo, jalan simulasi (navigasi Gerbang → Curug Omas, 60×). Rute Santai: tidak ada kartu pemicu; yang muncul hanya layar tiba navigasi "Anda sudah sampai!" (dengan "Dengarkan ceritanya" dan peringatan bahwa titik ini ujung rute Trekking). Rute Trekking: kartu pemicu "Anda tiba di Curug Omas · Ingin mendengar ceritanya?" + Dengarkan / Lihat detail / Nanti. Catatan: tombol "Pindah ke" di panel Mode demo memanggil pemicu manual (berlaku di semua rute, sesuai desain), jadi tidak dapat dipakai untuk skenario ini. [ss](bukti/F02/SK-F02-18_jacob_2026-11-25_2.jpg), [ss](bukti/F02/SK-F02-18_jacob_2026-11-25_3.jpg), sesi aktif tanpa pilihan rute: [ss](bukti/F02/SK-F02-18_jacob_2026-11-25.jpg) |
| SK-F02-21 | Pencatatan pemicu dan kunjungan | Sebagian | CJ-008. Sesi demo Trekking dengan pemicu jalan simulasi (Curug Omas), "Saya di sini" (Hutan Pinus), QR (P05). Ringkasan log dari menu debug: "Dikunjungi (3): P11, P08, P05 · Terpicu (6): P04, P10, P08, P06, P11, P05": cocok dengan catatan penguji. Penangkaran Rusa (dibuka lewat Detail tanpa pemicu) tidak tercatat dikunjungi: sesuai D05. Tetapi ringkasan tidak menampilkan waktu, sumber (GPS/QR/manual), dan akurasi tiap kejadian, jadi tidak dapat dicocokkan di ponsel. Menurut kode, log internal menyimpan waktu, ID, jenis, dan sumber, tetapi tidak menyimpan akurasi. Menu debug saat log disalin (jam simulasi 10.47): [ss](bukti/F02/SK-F02-21_jacob_2026-11-25.jpg) |
| SK-A02-03 | QR asing | Lulus | Pesan "QR tidak dikenali. Pastikan Anda memindai papan Jelajah Taman."; tidak ada POI terbuka; pemindai dapat dipakai lagi. Catatan: pemindai juga membaca QR di luar kotak bidik (QR P05 di bawahnya ikut terbaca), lihat CJ-007. Bila hanya QR asing yang terlihat kamera, tidak ada POI yang terbuka. [ss](bukti/A02/SK-A02-03_jacob_2026-11-24.jpg) |
| SK-A02-04 | QR berskema benar dengan ID tidak dikenal | Lulus | `jelajahtaman://poi/P99`: pesan "QR tidak dikenali"; tidak ada POI terbuka. Sesudahnya muncul petunjuk kuning "Di dalam gua sinyal lokasi melemah. Kode QR membuka ceritanya langsung." (juga pada QR asing). QR P06 di layar ikut terbaca (CJ-007). [ss](bukti/A02/SK-A02-04_jacob_2026-11-24.jpg) |
| SK-A02-05 | Pemindaian QR menandai dikunjungi | Lulus | Diuji pada pindaian QR P05 pertama (sesi baru otomatis dimulai, P05 belum dikunjungi): P05 langsung berstatus Dikunjungi, ±1 detik. Sumber "QR" di log sesi belum diperiksa (lihat SK-F02-21). [ss](bukti/A02/SK-A02-09_jacob_2026-11-24.jpg) |
| SK-A02-07 | Izin kamera ditolak | Lulus | Izin kamera tidak diminta saat onboarding; diminta saat pemindai dibuka. Setelah "Don't allow": pesan "Kamera belum diizinkan… atau pilih tempat dari daftar" + tombol "Pilih tempat dari daftar"; tidak macet. [ss](bukti/A02/SK-A02-07_jacob_2026-11-24.jpg), [ss](bukti/A02/SK-A02-07_jacob_2026-11-24_2.jpg) |
| SK-A02-08 | QR untuk POI yang sudah dikunjungi | Lulus | QR P05 dipindai ulang: Gua Jepang tetap terbuka; jumlah tetap "2 dikunjungi" (P05 + P06 yang ikut terbaca, CJ-007), tidak bertambah. Lembar rekomendasi hanya muncul pada kunjungan pertama, tidak tiap pindaian. [ss](bukti/A02/SK-A02-08_jacob_2026-11-24.jpg) |
| SK-A02-09 | QR dipindai tanpa sesi aktif | Lulus | QR P05 (di layar laptop) tanpa sesi: Gua Jepang terbuka ±1 detik, berstatus Dikunjungi, tidak macet. Sesi otomatis dimulai (sesuai desain, `guide_controller.dart:997`). Lembar rekomendasi "Berikutnya, ke sini?" (Kolam Pakar) + suara "berikutnya Kolam Pakar" juga muncul. [ss](bukti/A02/SK-A02-09_jacob_2026-11-24.jpg), [ss](bukti/A02/SK-A02-09_jacob_2026-11-24_2.jpg) |
| SK-F05-01 | Kata kunci "gua" | Lulus | 5 hasil: Gua Jepang, Gua Belanda, serta fasilitas yang namanya memuat "gua" (Toilet dekat Gua Belanda, Musala dekat Gua Belanda, Saung Jalur Gua). |
| SK-F05-02 | Kata kunci "toilet" | Lulus | 2 hasil = semua toilet di data (Toilet dekat Gerbang, Toilet dekat Gua Belanda). |
| SK-F05-03 | Pencocokan sebagian dan tidak peka huruf besar/kecil | Lulus | Diketik satu per satu: `PINUS` 2 hasil (Kawasan Hutan Pinus + Bangku Hutan Pinus), `mus` 3 (Museum + 2 musala), `Rusa` 2 (Penangkaran Rusa + Saung Penangkaran Rusa). Bila ketiganya diketik sekaligus dalam satu kotak, tidak ada hasil (bukan bagian skenario). |
| SK-F05-04 | Filter kategori | Lulus | Tiap filter (Sejarah, Alam, Rekreasi, Fasilitas) hanya menampilkan kategorinya. |
| SK-F05-05 | Filter digabung dengan kata kunci | Lulus | `gua` + Fasilitas: hanya fasilitas dekat gua; `gua` + Sejarah: hanya kedua gua. |
| SK-F05-08 | Kecepatan pencarian luring | Lulus | Mode pesawat; hasil `gua`, `toilet`, kata acak muncul < 1 detik. |
| SK-F05-09 | Kata kunci tidak ditemukan | Lulus | `xyzabc`: pesan tidak ditemukan + saran kategori, tidak macet. |
| SK-F05-10 | Satu salah ketik | Lulus | `tiolet` → toilet; `gua blanda` → Gua Belanda. Catatan: saat masih mengetik, hasil sempat kosong, lalu muncul setelah kata selesai. |
| SK-F05-11 | Batas toleransi salah ketik | Lulus | `pinsu` → Pinus, `musla` → ketemu, `pxnxs` → tidak, `belxndx` → ketemu, `gxa` → tidak. Sesuai harapan. |
| SK-F05-12 | Sinonim | Lulus | `wc` 2 hasil (toilet); `goa` 5 hasil (sama dengan `gua`). Catatan: `wc goa` → 1 hasil (Toilet dekat Gua Belanda). |
| SK-F05-13 | Memilih hasil membuka detail | Lulus | Detail POI yang benar terbuka. |
| SK-F05-14 | Memilih hasil memulai navigasi | Lulus | Mode demo, rute Trekking: Cari `musala` → tombol navigasi pada hasil → navigasi ke musala dimulai. |
| SK-F05-15 | Masukan tidak lazim | Lulus | Spasi berulang, simbol, dan tempel teks panjang: tidak macet. |
| SK-F05-16 | Pencarian tanpa posisi | Lulus | Izin lokasi ditolak: `toilet` tetap menampilkan hasil yang dapat dibuka; jarak berlabel "dari gerbang" (dilaporkan penguji; label yang sama terlihat di kartu fasilitas peta, [ss](bukti/A04/SK-A04-01_jacob_2026-11-24.jpg)). Catatan: POI Detail tetap menulis "dari Anda", lihat CJ-002. |
| SK-A04-01 | Marker fasilitas di peta | Lulus | Marker fasilitas (ikon warung, cincin putih) berbeda dari marker POI; ketukan menampilkan nama "Warung dekat Kolam", jarak "10 m · <1 mnt dari gerbang" (tanpa posisi), dan tombol Navigasi. [ss](bukti/A04/SK-A04-01_jacob_2026-11-24.jpg) |
| SK-A04-02 | Filter "Fasilitas" | Lulus | Toilet, musala, warung, titik istirahat, pos petugas tampil; tidak ada POI. |
| SK-A04-05 | Setiap jenis fasilitas dapat dicari | Lulus | `musala`, `warung`, `petugas`, `istirahat` menampilkan fasilitas yang sesuai beserta jarak. |
| SK-F06-12 | Membatalkan navigasi | Lulus | Navigasi ke musala diakhiri dengan × di bilah arahan sebelum tiba: garis rute hilang, sesi tetap berjalan, statistik sesi tidak terhapus. |
| SK-F06-13 | Titik masuk navigasi | Lulus | Mode demo. Kelima titik masuk memulai navigasi ke tujuan yang benar: marker peta (kartu Penangkaran Rusa → Navigasi, [ss](bukti/F06/SK-F06-13_jacob_2026-11-25.jpg)), POI Detail (ikon di pojok kanan atas), hasil Cari (SK-F05-14), lembar rekomendasi (dilaporkan penguji), pengingat jam tutup (panel demo → PENGINGAT → Jam tutup → navigasi ke Gerbang, sesuai A03). Catatan: tombol navigasi di POI Detail berupa ikon peta tanpa label, dikira tombol kembali ke peta, lihat CJ-011. Lembar rekomendasi sempat hanya berisi "Kembali ke gerbang" karena jam demo sudah maju jauh oleh jalan simulasi (wajar). |
| SK-F06-15 | ETA memperhitungkan tanjakan | Lulus | Jalur sama, 1,1 km. Gerbang → Gua Belanda (arah menurun): 23 mnt. Gua Belanda → Gerbang (arah menanjak): 24 mnt. Arah menanjak lebih lama, sesuai hitungan asisten dari `trail_graph.json` (1.061 m; tanjakan 15 m vs 29 m; ±22,7 vs ±24,1 mnt dengan D09). [ss](bukti/F06/SK-F06-15_jacob_2026-11-25.jpg), [ss](bukti/F06/SK-F06-15_jacob_2026-11-25_2.jpg) |
| SK-F06-16 | Rute terpendek | Lulus | Uji otomatis (metode O): `test/modules/routing/graph_trail_router_test.dart` (rute mengikuti jalur F06 AC1, biaya = waktu, D09 tanjakan, penempelan ke jalur, arahan belok/pertigaan, POI tak terjangkau). CI run #42 untuk build `32018e3` lulus (job "Content · format · analyze · architecture · test", 23 Nov 13:08 UTC, [log](https://github.com/keaneplim/Transformasi-Digital-UAS/actions/runs/45180612777)). Diperiksa asisten AI, bukan uji ponsel. |
| SK-F06-18 | Seluruh POI dan fasilitas terjangkau | Lulus | Di ponsel (mode demo) dicoba 3 tujuan: Toilet dekat Gua Belanda, Saung Jalur Gua, Penangkaran Rusa; rute muncul untuk ketiganya. Sisanya dicek asisten AI pada data build `32018e3` (metode O): ke-21 titik POI/fasilitas di `trail_graph.json` terhubung ke gerbang (P01), tidak ada yang terputus. Temuan: setiap navigasi dimulai, peta menampilkan seluruh kawasan (Museum–Curug Omas), bukan rutenya, lihat CJ-009. |
| SK-A01-02 | Pemakaian pertama tanpa internet | Lulus | Mode pesawat sebelum dibuka pertama kali; onboarding selesai, peta tampil, satu POI dibuka dan audio berputar; tidak ada unduhan yang diminta. Peta luring: [ss](bukti/F01/SK-F01-04_jacob_2026-11-24.jpg) |
| SK-A01-03 | Peta luring | Lulus | Mode pesawat, izin lokasi ditolak: zona tampil saat diperkecil dan diperbesar, tanpa area kosong; marker POI, marker fasilitas, dan jalur tampil. Titik pengguna tidak diuji (izin lokasi ditolak). [ss](bukti/A01/SK-A01-03_jacob_2026-11-24.jpg), [ss](bukti/A01/SK-A01-03_jacob_2026-11-24_2.jpg) |
| SK-A01-04 | Atribusi peta | Lulus | "© OpenStreetMap" di peta dan "Data peta © OpenStreetMap contributors" di Tentang & atribusi. [ss](bukti/A01/SK-A01-04_jacob_2026-11-24.jpg), [ss](bukti/A01/SK-A01-03_jacob_2026-11-24.jpg) |
| SK-A01-05 | Lapisan satelit tanpa internet | Lulus | Mode pesawat: pesan "Peta satelit butuh internet. Kembali ke peta biasa.", tidak macet. [ss](bukti/A01/SK-A01-05_jacob_2026-11-24.jpg) |
| SK-A01-06 | Sinyal hilang-timbul | Lulus | Mode pesawat dinyalakan/dimatikan beberapa kali sambil berpindah layar selama sesi: tidak ada galat, fitur tetap berjalan. |
| SK-A01-07 | Ukuran pemasangan | Lulus | Unduhan APK 63,76 MB; paket 60,8 MB (penginstal); penyimpanan setelah terpasang 69,81 MB. Ruang kosong HP jauh di atas 1 GB. [ss](bukti/A01/SK-A01-07_jacob_2026-11-24.jpg), [ss](bukti/A01/SK-A01-07_jacob_2026-11-24_2.jpg) |
| SK-INS-01 | Terpasang dan terbuka di ≥2 perangkat uji |  |  |
| SK-INS-02 | Pembaruan di atas versi lama | Lulus | Dilaporkan penguji: sebelum 24 Nov, APK versi lama di HP ini diperbarui ke build `32018e3` tanpa menghapus yang lama; pembaruan berhasil dan aplikasi berjalan normal. Tanpa screenshot (aplikasi kemudian dihapus untuk uji pemasangan baru). |
| SK-INS-03 | Aplikasi dibuka kembali | Lulus | Aplikasi ditutup penuh lalu dibuka lagi: onboarding tidak diulang, langsung ke Beranda. |
| SK-KTH-01 | Berpindah aplikasi selama sesi | Lulus | Narasi berputar, aplikasi Kamera dibuka ±2 menit, lalu kembali: sesi, statistik, dan audio tetap utuh. |
| SK-KTH-02 | Layar diputar | Gagal | CJ-003. Tab Peta dalam posisi mendatar: kartu statistik menumpuk di atas kartu "Lokasi belum diizinkan", kartu tempat menutupi peta, tombol peta terpotong di atas. [ss](bukti/KTH/SK-KTH-02_jacob_2026-11-24.jpg) |
| SK-KTH-03 | Baterai rendah / hemat daya | Sebagian | Mode demo, Penghemat baterai aktif, navigasi kecepatan 10×, layar dimatikan ±10 menit (dicoba 2 kali). Selama layar mati tidak ada suara/getar/notifikasi; notifikasi baru muncul saat layar dinyalakan, dan posisi sudah berpindah. Penjelasan asisten (dari kode, belum dibuktikan): jalan simulasi mode demo berjalan di dalam aplikasi (`guide_controller.dart` `_walkTimer`), bukan di layanan latar depan GPS, sehingga tertahan saat layar mati di HyperOS; setelah layar menyala titik melompat sejauh waktu yang terlewat. Jadi hasil ini belum mewakili GPS asli. Uji ulang dengan GPS asli di luar ruangan (kelompok 1C). POCO X8 Pro, HyperOS 3.0. |
| SK-KTH-04 | Sesi panjang | Lulus | Sesi demo ±2 jam: tidak macet, tidak melambat, statistik tidak kembali ke nol. Temuan sebelumnya: durasi >1 jam terpotong di kartu statistik (CJ-005). Temuan: aplikasi dibiarkan di latar belakang tanpa disentuh, titik di Penangkaran Rusa; setelah telepon selesai, narasi Gua Belanda berbunyi sendiri. Lihat CJ-010. |
| SK-KTH-05 | Tombol kembali Android | Lulus | Dari POI Detail / navigasi: kembali ke layar sebelumnya. Dari tab Beranda/Peta/Cari: aplikasi keluar (perilaku standar Android), tetapi sesi tetap berjalan: durasi terus bertambah setelah aplikasi ditutup dan dihapus dari daftar aplikasi terbaru ±10 menit. Lihat CJ-004 (ditolak). |

### 1B. Fake GPS: mock location memutar trek GPX (41)

| ID | Skenario | Hasil | Penjelasan |
|---|---|---|---|
| SK-F01-06 | Pembacaan GPS lemah tidak dipakai untuk pemicu |  |  |
| SK-F02-01 | Getaran saat mendekati POI |  |  |
| SK-F02-02 | Pemicu pada 10 POI inti |  |  |
| SK-F02-03 | Tidak ada pemicu palsu |  |  |
| SK-F02-04 | Tidak berulang selama berada di dalam radius |  |  |
| SK-F02-05 | Keluar lalu masuk kembali sebelum 10 menit |  |  |
| SK-F02-06 | Pemicu ulang setelah keluar dan lewat 10 menit |  |  |
| SK-F02-07 | Getaran tidak berulang di tepi zona mendekati |  |  |
| SK-F02-08 | Pendekatan baru setelah menjauh |  |  |
| SK-F02-09 | Melewati POI yang sudah dikunjungi |  |  |
| SK-F02-13 | Dua POI berdekatan |  |  |
| SK-F02-17 | Aturan khusus P01 Gerbang |  |  |
| SK-F02-19 | Tanpa sesi tidak ada pemicu |  |  |
| SK-F02-20 | Notifikasi pemicu pada layar terkunci |  |  |
| SK-F02-22 | Izin notifikasi ditolak |  |  |
| SK-F05-06 | Urutan menurut jarak jalan kaki |  |  |
| SK-F05-07 | Urutan berubah mengikuti posisi |  |  |
| SK-A04-03 | Fasilitas dapat dinavigasi |  |  |
| SK-A04-04 | Fasilitas tidak memicu notifikasi |  |  |
| SK-F06-01 | Rute mengikuti jalur setapak |  |  |
| SK-F06-02 | Sisa jarak dan ETA berkurang |  |  |
| SK-F06-03 | Mencapai tiga tujuan hanya dengan navigasi |  |  |
| SK-F06-04 | Hitung ulang setelah menyimpang |  |  |
| SK-F06-05 | Navigasi dalam mode pesawat |  |  |
| SK-F06-07 | Status tiba |  |  |
| SK-F06-08 | Tiba tidak memicu ulang POI |  |  |
| SK-F06-09 | Tawaran "Buka detail" saat tiba |  |  |
| SK-F06-10 | Tiba di fasilitas |  |  |
| SK-F06-11 | Arahan di persimpangan |  |  |
| SK-F06-14 | Simpangan kecil tidak menghitung ulang |  |  |
| SK-F06-17 | GPS lemah selama navigasi |  |  |
| SK-A01-01 | Alur F01–F08 penuh dalam mode pesawat |  |  |
| SK-E2E-01 | 1. Start |  |  |
| SK-E2E-02 | 2. Explore |  |  |
| SK-E2E-03 | 3. Location Trigger |  |  |
| SK-E2E-04 | 4. Information |  |  |
| SK-E2E-05 | 5. Recommendation |  |  |
| SK-E2E-06 | 6. Search Destination |  |  |
| SK-E2E-07 | 7. Navigation |  |  |
| SK-E2E-08 | 8. Lanjut eksplorasi dan pengingat |  |  |
| SK-E2E-09 | 9. Selesai |  |  |

### 1C. GPS asli di luar ruangan (10)

| ID | Skenario | Hasil | Penjelasan |
|---|---|---|---|
| SK-F01-01 | Posisi tampil setelah izin diberikan |  |  |
| SK-F01-02 | Posisi diperbarui saat berjalan |  |  |
| SK-F01-03 | Deviasi posisi terhadap titik referensi |  |  |
| SK-F01-05 | Indikator "GPS lemah" |  |  |
| SK-F01-07 | Lokasi tetap dibaca saat layar mati |  |  |
| SK-F01-08 | Pengguna diam tetap menghasilkan pembacaan |  |  |
| SK-F02-15 | Banner saat GPS lemah 60 detik |  |  |
| SK-F06-06 | Akurasi ETA |  |  |
| SK-A06-01 | Pemakaian baterai per jam sesi |  |  |
| SK-A06-02 | Pelacakan saat diam |  |  |

### 1D. Papan QR cetak (3)

| ID | Skenario | Hasil | Penjelasan |
|---|---|---|---|
| SK-A02-01 | QR Gua Jepang, luring |  |  |
| SK-A02-02 | QR Gua Belanda, luring |  |  |
| SK-A02-06 | QR di kondisi gelap |  |  |

### 1E. Skenario QA2 (Mike) yang juga diuji di HP Anda (6)

Skenario sensitif perangkat. QA2 (Mike) juga menjalankannya di HP-nya sendiri; tidak perlu bertukar HP.

| ID | Skenario | Hasil | Penjelasan |
|---|---|---|---|
| SK-F03-09 | Cadangan Text-to-Speech perangkat |  |  |
| SK-F04-01 | Satu kunjungan POI dengan layar terkunci |  |  |
| SK-F04-07 | Kontrol media di layar kunci |  |  |
| SK-F04-13 | Suara tersedia tanpa internet |  |  |
| SK-A03-02 | Suara dan notifikasi |  |  |
| SK-F08-03 | Uji 200 langkah |  |  |

## Fase 2 — di Tahura

Build (APK): ______ (APK kandidat final) · Tanggal: ____

Hanya skenario yang harus dikonfirmasi di dalam Tahura karena kondisi taman (kanopi, tanjakan, sinyal, mulut gua) dapat mengubah hasilnya. Skenario ini juga sudah dijalankan di Fase 1; hasil Fase 2 dicatat terpisah di sini.

| ID | Skenario | Hasil | Penjelasan |
|---|---|---|---|
| SK-F01-03 | Deviasi posisi terhadap titik referensi |  |  |
| SK-F02-02 | Pemicu pada 10 POI inti |  |  |
| SK-F02-03 | Tidak ada pemicu palsu |  |  |
| SK-A02-01 | QR Gua Jepang, luring |  |  |
| SK-A02-02 | QR Gua Belanda, luring |  |  |
| SK-A02-06 | QR di kondisi gelap |  |  |
| SK-F06-03 | Mencapai tiga tujuan hanya dengan navigasi |  |  |
| SK-F06-06 | Akurasi ETA |  |  |
| SK-E2E-01 | 1. Start |  |  |
| SK-E2E-02 | 2. Explore |  |  |
| SK-E2E-03 | 3. Location Trigger |  |  |
| SK-E2E-04 | 4. Information |  |  |
| SK-E2E-05 | 5. Recommendation |  |  |
| SK-E2E-06 | 6. Search Destination |  |  |
| SK-E2E-07 | 7. Navigation |  |  |
| SK-E2E-08 | 8. Lanjut eksplorasi dan pengingat |  |  |
| SK-E2E-09 | 9. Selesai |  |  |
| SK-F04-01 | Satu kunjungan POI dengan layar terkunci · bagian QA2 |  |  |
