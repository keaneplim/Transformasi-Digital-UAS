# 06 — Alur Utama, Layar, dan Batasan Produk

Konvensi ID, kode metode, dan cara pencatatan hasil dijelaskan di [README.md](README.md). Berkas ini mencakup skenario lintas fitur: pemasangan (PB01), alur utama PRD §2.1, onboarding dan Setelan (UI01, UI02, UI15), cakupan layar UI01–UI15, non-goals NG01–NG08, serta aturan teks antarmuka.

## Pemasangan (PB01)

| ID | Skenario | Prasyarat | Langkah | Hasil yang diharapkan | Acuan | Metode |
|---|---|---|---|---|---|---|
| SK-INS-01 | Terpasang dan terbuka di ≥2 perangkat uji | Dua ponsel Android berbeda merek; hasil DEVICE_CHECK terisi | 1. Pasang APK pada kedua perangkat.<br>2. Buka aplikasi dan jelajahi setiap tab selama 2 menit. | Aplikasi terpasang dan terbuka tanpa macet pada kedua perangkat. Catat merek, model, dan versi Android. | PB01 | P |
| SK-INS-02 | Pembaruan di atas versi lama | Versi sebelumnya terpasang | 1. Pasang APK baru tanpa menghapus yang lama.<br>2. Buka aplikasi. | Aplikasi terbuka normal; pengaturan pengguna tidak rusak. | PB21 | P |
| SK-INS-03 | Aplikasi dibuka kembali | Onboarding sudah diselesaikan | 1. Tutup aplikasi, lalu buka kembali. | Onboarding tidak diulang; pengguna langsung masuk ke Beranda. | PRD §2.1 langkah 1 | P |

## Alur utama PRD §2.1 (skenario Rina)

Satu sesi lapangan utuh oleh penguji yang memerankan pengunjung baru. Setiap langkah dicatat lulus/gagal secara terpisah.

| ID | Langkah PRD | Aksi penguji | Hasil yang diharapkan | Acuan |
|---|---|---|---|---|
| SK-E2E-01 | 1. Start | Buka aplikasi pertama kali; beri izin lokasi, notifikasi, dan aktivitas fisik; pilih minat Sejarah dan Alam; pilih rute Santai. | Onboarding singkat tampil; izin diminta dengan penjelasan; rute Santai menampilkan jarak, durasi, kesulitan, dan keterangan dapat selesai sebelum jam tutup. | UI01, UI02, F08 AC1 |
| SK-E2E-02 | 2. Explore | Ketuk "Mulai Jelajah"; masukkan ponsel ke saku dan pakai earphone. | Peta menampilkan posisi, jalur rute, marker POI dan fasilitas; penghitung langkah dan durasi mulai berjalan. | UI03, F01, F08 |
| SK-E2E-03 | 3. Location Trigger | Berjalan menuju Gua Jepang. | Ponsel bergetar dan berbunyi saat mendekat (≤50 m untuk radius 20 m); di dalam radius muncul notifikasi dan prompt suara "Anda tiba di Gua Jepang…". | UI04, UI05, F02, F04 |
| SK-E2E-04 | 4. Information | Ketuk "Dengarkan" pada notifikasi tanpa membuka aplikasi; setelah narasi, buka kartu POI; masuk ke gua dan pindai QR saat disarankan. | Narasi diputar tanpa membuka aplikasi; kartu POI memuat foto, teks, fakta kunci, estimasi lama kunjungan; saat GPS melemah aplikasi menyarankan pindai QR; konten tampil tanpa internet. | UI06, UI07, UI12, F03, A02 |
| SK-E2E-05 | 5. Recommendation | Keluar dari gua. | Tampil rekomendasi POI berikutnya yang belum dikunjungi beserta jarak, estimasi waktu, alasan, dan dua alternatif. | UI08, F07 |
| SK-E2E-06 | 6. Search Destination | Buka pencarian dan ketik `toilet`. | Daftar toilet terdekat tampil dengan jarak dan estimasi waktu jalan. | UI09, F05, A04 |
| SK-E2E-07 | 7. Navigation | Pilih toilet terdekat, ketuk "Navigasi", ikuti arahan hingga tiba. | Jalur digambar di atas jalan setapak; sisa jarak dan ETA tampil; arahan suara di persimpangan; kedatangan diumumkan. | UI10, UI11, F06 |
| SK-E2E-08 | 8. Lanjut eksplorasi dan pengingat | Lanjutkan ke POI rekomendasi; teruskan sesi hingga ambang pengingat jam tutup dan interval hidrasi. | Pengingat jam tutup muncul pada ambang terhitung dengan jam tutup dan waktu jalan ke gerbang; pengingat minum muncul setelah interval hidrasi. | UI13, A03, F08 AC3 |
| SK-E2E-09 | 9. Selesai | Di gerbang, ketuk "Akhiri Jelajah". | Ringkasan menampilkan jumlah POI dikunjungi, langkah, jarak, durasi, dan daftar POI yang belum dikunjungi. | UI14, F08 AC4 |

## Onboarding, Beranda, dan Setelan

| ID | Skenario | Prasyarat | Langkah | Hasil yang diharapkan | Acuan | Metode |
|---|---|---|---|---|---|---|
| SK-ONB-01 | Onboarding dan permintaan izin | Pemasangan baru | 1. Jalani onboarding hingga selesai, beri semua izin. | Aplikasi menjelaskan kegunaannya secara singkat dan meminta izin lokasi, notifikasi, dan aktivitas fisik satu per satu dengan alasan; izin kamera diminta saat pemindai QR pertama kali dibuka. | UI01 | P |
| SK-ONB-02 | Semua izin ditolak | Pemasangan baru | 1. Tolak setiap izin.<br>2. Selesaikan onboarding dan buka setiap tab. | Onboarding tetap dapat diselesaikan; aplikasi menjelaskan keterbatasan yang timbul; peta, pencarian, dan POI Detail tetap dapat dipakai. | UI01, F01 AC4 | P |
| SK-ONB-03 | Melewati onboarding | Pemasangan baru | 1. Gunakan pilihan lewati pada onboarding. | Pengguna tiba di pemilihan minat/rute atau Beranda tanpa macet; izin dapat diberikan kemudian. | UI01 | P |
| SK-ONB-04 | Izin diberikan belakangan | Izin lokasi sebelumnya ditolak | 1. Gunakan ajakan mengaktifkan lokasi di aplikasi.<br>2. Beri izin (melalui dialog atau Setelan Android). | Titik biru muncul tanpa memasang ulang aplikasi. | F01 AC4 | P |
| SK-HOM-01 | Memilih minat dan rute | Beranda/penyiapan terbuka | 1. Pilih dan batalkan beberapa minat.<br>2. Pilih tiap rute bergantian. | Pilihan minat dan rute tersimpan dan tercermin pada Beranda, peta (jalur rute), serta rekomendasi. | UI02, F07, F08 | P |
| SK-HOM-02 | Informasi jam operasional | Beranda terbuka | 1. Periksa jam buka/tutup dan sisa waktu. | Jam operasional dan sisa waktu hingga tutup tampil sesuai data dan jam perangkat. | UI02, A03 | P |
| SK-SET-01 | Auto-Play | Setelan terbuka | 1. Nyalakan Auto-Play dan jalankan SK-F04-04.<br>2. Matikan dan jalankan SK-F04-05. | Pengaturan langsung berlaku. | UI15, F04 | M, L |
| SK-SET-02 | Interval hidrasi | Setelan terbuka | 1. Jalankan SK-F08-09. | Pengaturan langsung berlaku. | UI15, F08 | M |
| SK-SET-03 | Ukuran teks | Setelan terbuka | 1. Jalankan SK-A07-02. | Pengaturan langsung berlaku di seluruh layar. | UI15, A07 | P |
| SK-SET-04 | Informasi data luring | Setelan terbuka | 1. Cari keterangan ketersediaan data luring/versi konten. | Status data luring tampil; tidak ada unduhan yang menggantung. | UI15, A01 | P |
| SK-SET-05 | Pengaturan bertahan | Beberapa pengaturan diubah | 1. Tutup aplikasi sepenuhnya, lalu buka kembali. | Pengaturan yang diubah tetap tersimpan. | UI15 | P |

## Cakupan layar UI01–UI15

Setiap layar/keadaan pada PRD §5.1 harus muncul minimal sekali selama pengujian. Kolom terakhir menunjuk skenario yang menampilkannya.

| ID layar | Layar/keadaan | Yang diperiksa saat tampil | Skenario |
|---|---|---|---|
| UI01 | Onboarding & Permission | Penjelasan aplikasi; izin lokasi, notifikasi, aktivitas fisik, kamera | SK-ONB-01, SK-ONB-02 |
| UI02 | Home — Pilih Minat & Rute | Minat; rute dengan jarak, durasi, kesulitan | SK-HOM-01, SK-F08-01 |
| UI03 | Explore Map | Posisi, marker POI dan fasilitas, rute aktif, statistik sesi | SK-A01-03, SK-F08-16 |
| UI04 | Approaching State | Banner jarak ke POI, getar dan bunyi | SK-F02-01 |
| UI05 | POI Trigger Notification | Aksi Dengarkan/Lihat/Nanti | SK-F02-20 |
| UI06 | POI Detail | Foto, teks, fakta kunci, pemutar audio, estimasi lama kunjungan | SK-F03-01 |
| UI07 | Eyes-Free / Layar Kunci | Notifikasi dan kontrol audio di layar kunci/earphone | SK-F04-01, SK-F04-07 |
| UI08 | Recommendation Sheet | Rekomendasi utama, dua alternatif, alasan | SK-F07-08 |
| UI09 | Search | Pencarian nama dan kategori, terurut jarak | SK-F05-01, SK-F05-04 |
| UI10 | Navigation | Jalur, sisa jarak, ETA, arahan berikutnya dan suara | SK-F06-01, SK-F06-11 |
| UI11 | Arrived | Konfirmasi tiba; "Buka detail" tanpa memicu ulang | SK-F06-07, SK-F06-09 |
| UI12 | GPS Lemah / QR Scanner | Banner GPS lemah; pemindai QR | SK-F02-15, SK-A02-01 |
| UI13 | Closing / Hydration Reminder | Pengingat jam tutup dengan navigasi ke gerbang; pengingat minum | SK-A03-01, SK-F08-08 |
| UI14 | Session Summary | POI dikunjungi/belum, langkah, jarak, durasi | SK-F08-11 |
| UI15 | Settings | Auto-Play, interval hidrasi, ukuran teks, data luring | SK-SET-01 s.d. SK-SET-05 |

## Non-goals (pemeriksaan negatif)

Tujuannya memastikan produk tidak memuat hal yang dinyatakan di luar lingkup. Jelajahi seluruh layar, menu, dan Setelan.

| ID | Batasan | Yang diperiksa | Hasil yang diharapkan | Acuan |
|---|---|---|---|---|
| SK-NG-01 | Tanpa tiket/pembayaran | Seluruh layar dan menu | Tidak ada fitur pembelian tiket atau pembayaran. | NG01 |
| SK-NG-02 | Hanya zona Dago Pakar | Daftar POI, peta, pencarian | Tidak ada POI di luar daftar PRD §4.1; peta dibatasi pada zona. P11 Curug Omas diperiksa khusus karena diduga berada di luar zona (PROGRESS #13); catat hasilnya. | NG02 |
| SK-NG-03 | Tanpa AR, beacon/BLE, computer vision | Izin aplikasi di Setelan Android; seluruh layar | Tidak ada izin Bluetooth; kamera hanya dipakai untuk memindai QR; tidak ada tampilan AR. | NG03 |
| SK-NG-04 | Tanpa CMS/dasbor admin | Seluruh layar dan menu | Tidak ada layar admin atau penyuntingan konten. | NG04 |
| SK-NG-05 | Tanpa akun dan data di server | Onboarding, Setelan, seluruh sesi dalam mode pesawat | Tidak ada pendaftaran, login, fitur sosial, atau unggahan data; seluruh fitur inti berjalan dalam mode pesawat. | NG05, F08 AC5 |
| SK-NG-06 | Bukan alat darurat dan tanpa pelacakan oleh pengelola | Seluruh layar; notifikasi setelah sesi berakhir | Tidak ada tombol SOS atau klaim darurat; lokasi tidak dibaca di luar sesi (lihat SK-F01-11). | NG06 |
| SK-NG-07 | Tanpa pemesanan atau transaksi | Seluruh layar dan menu | Tidak ada pemesanan pemandu, reservasi, atau transaksi. | NG07 |
| SK-NG-08 | Hanya Bahasa Indonesia | Seluruh teks antarmuka, konten, notifikasi, dan suara | Seluruhnya berbahasa Indonesia; tidak ada pilihan bahasa lain; tidak ada teks antarmuka berbahasa Inggris yang tertinggal. | NG08 |

## Aturan teks antarmuka

Bersumber dari `docs/design/DESIGN.md` §8 dan konvensi tim. Aturan ini bukan acceptance criteria PRD; temuan dicatat sebagai cacat tampilan.

| ID | Skenario | Langkah | Hasil yang diharapkan | Acuan |
|---|---|---|---|---|
| SK-TKS-01 | Tanpa detail operasional | Baca seluruh teks pada setiap layar pengunjung (kecuali panel Mode demo di Setelan). | Tidak ada angka radius, akurasi GPS, koordinat, label data contoh, atau teks debug. | DESIGN.md §8 |
| SK-TKS-02 | Sapaan dan gaya bahasa | Baca teks antarmuka dan konten POI. | Pengguna disapa "Anda"; gaya bahasa konsisten. | DESIGN.md §8 |
| SK-TKS-03 | Format angka | Periksa jarak, waktu, langkah, dan jam di seluruh layar. | Format Indonesia konsisten, mis. 1.722 langkah · 1,2 km · 16.00 · 37 mnt. | DESIGN.md §8 |
| SK-TKS-04 | Penanda yang tertinggal | Cari teks `[ISI]`, `[VERIFIKASI]`, atau "DUMMY" pada layar pengunjung. | Tidak ada penanda yang tampil pada build rilis. | DESIGN.md §8, CLAUDE.md |

## Ketahanan

| ID | Skenario | Langkah | Hasil yang diharapkan | Acuan |
|---|---|---|---|---|
| SK-KTH-01 | Berpindah aplikasi selama sesi | Selama sesi, buka kamera/aplikasi lain 2 menit, lalu kembali. | Sesi, statistik, dan audio tetap utuh. | PB21 |
| SK-KTH-02 | Layar diputar | Putar ponsel pada layar utama. | Tampilan tidak rusak dan data tidak hilang. | PB21 |
| SK-KTH-03 | Baterai rendah / hemat daya | Aktifkan mode hemat daya selama sesi dengan layar terkunci 10 menit. | Catat apakah pelacakan dan pemicu tetap bekerja; bila tidak, catat sebagai keterbatasan per merek perangkat. | Risiko R2 (IMPLEMENTATION_PLAN §9) |
| SK-KTH-04 | Sesi panjang | Jalankan satu sesi ≥2 jam (lapangan atau Mode demo). | Tidak ada macet, pelambatan berarti, atau statistik yang kembali ke nol. | PB21 |
| SK-KTH-05 | Tombol kembali Android | Tekan tombol kembali pada setiap layar. | Navigasi mundur wajar; aplikasi tidak tertutup tak terduga saat sesi aktif. | PB21 |
