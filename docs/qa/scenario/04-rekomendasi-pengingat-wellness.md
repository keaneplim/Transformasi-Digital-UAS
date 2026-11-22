# 04 — Rekomendasi, Pengingat Jam Tutup, dan Wellness Trail (F07, A03, F08)

Konvensi ID, kode metode, dan cara pencatatan hasil dijelaskan di [README.md](README.md).

Jam operasional pada data aplikasi masih 08.00–16.00 dengan status belum terverifikasi (`[VERIFIKASI]`, Lampiran B butir 4). Bila pengelola mengonfirmasi jam yang berbeda, seluruh waktu pada berkas ini disesuaikan.

Simulasi waktu dan posisi dilakukan melalui Setelan → Mode demo (pindah posisi ke sebuah tempat, atur jam, picu pengingat).

## F07 — Contextual Recommendation

Bobot skor pada PRD: kedekatan jarak jalan 0,50 · kesesuaian minat 0,25 · kesesuaian rute aktif 0,15 · tingkat kesulitan 0,10. Syarat kandidat: waktu jalan ke POI + lama kunjungan + waktu jalan POI→gerbang ≤ sisa waktu sebelum jam tutup − 15 menit.

| ID | Skenario | Prasyarat | Langkah | Hasil yang diharapkan | Acuan | Metode |
|---|---|---|---|---|---|---|
| SK-F07-01 | Rekomendasi selalu POI yang belum dikunjungi | Sesi aktif pada pagi/siang hari (waktu masih longgar) | 1. Kunjungi tiga POI berurutan (buka detail atau dengarkan narasi).<br>2. Setelah setiap POI, catat rekomendasi utama dan kedua alternatif. | Tidak ada POI yang sudah dikunjungi pada sesi tersebut di antara rekomendasi utama maupun alternatif, pada ketiga kesempatan. | F07 AC1, TC-09 | L, M |
| SK-F07-02 | Rekomendasi muncul setelah menutup POI Detail | POI baru dikunjungi; POI Detail terbuka | 1. Tutup POI Detail dan mulai stopwatch. | Lembar rekomendasi muncul dalam ≤2 detik. | F07 AC2 | P, M |
| SK-F07-03 | Rekomendasi muncul setelah keluar radius | POI baru dikunjungi melalui "Dengarkan" tanpa membuka detail | 1. Berjalan keluar dari radius POI. | Rekomendasi muncul setelah penguji meninggalkan area POI, satu kali untuk POI tersebut. | F07 (deskripsi) | L |
| SK-F07-04 | Pukul 15.30 di P06: kembali ke gerbang | Mode demo; sesi aktif; posisi dipindahkan ke P06 Gua Belanda | 1. Atur jam simulasi ke 15.30.<br>2. Buka rekomendasi. | Rekomendasi berupa "Kembali ke gerbang"; tidak ada POI yang ditawarkan. | F07 AC3, TC-10 | M |
| SK-F07-05 | Saringan waktu sebelum jam tutup | Mode demo; posisi di P06 | 1. Catat waktu jalan P06→gerbang yang ditampilkan aplikasi.<br>2. Atur jam simulasi mundur bertahap (mis. 15.00, 14.30, 14.00) dan buka rekomendasi di tiap jam.<br>3. Untuk setiap POI yang ditawarkan, jumlahkan waktu jalan ke POI + lama kunjungan + waktu jalan POI→gerbang. | Tidak ada POI yang ditawarkan bila jumlah tersebut melewati jam tutup − 15 menit; semakin sore, semakin sedikit kandidat, hingga akhirnya "Kembali ke gerbang". | F07 AC3 | M |
| SK-F07-06 | Mengubah minat mengubah urutan | Mode demo; posisi dan jam tetap; catat rekomendasi dengan minat Sejarah saja | 1. Ubah minat menjadi Alam saja.<br>2. Buka rekomendasi dari posisi dan jam yang sama. | Urutan rekomendasi berubah: POI berkategori sesuai minat baru naik peringkat. Pilih posisi uji yang memiliki kandidat Sejarah dan Alam berjarak sebanding. | F07 AC4 | M |
| SK-F07-07 | Navigasi satu ketukan | Lembar rekomendasi tampil | 1. Ketuk aksi navigasi pada rekomendasi utama. | Navigasi ke POI tersebut langsung dimulai dengan satu ketukan. | F07 AC5 | P, M |
| SK-F07-08 | Satu utama, dua alternatif, dan alasan | Minimal empat POI belum dikunjungi; waktu longgar | 1. Buka rekomendasi. | Tampil satu rekomendasi utama dan dua alternatif, masing-masing dengan jarak, estimasi waktu, dan alasan (mis. paling dekat, sesuai minat, di rute aktif). | F07 (deskripsi), UI08 | P, M |
| SK-F07-09 | POI "Nanti" tetap kandidat | Sebuah POI terpicu dan dijawab "Nanti" | 1. Kunjungi POI lain, lalu buka rekomendasi. | POI yang dijawab "Nanti" masih dapat direkomendasikan. | F07 (deskripsi) | M |
| SK-F07-10 | Semua POI sudah dikunjungi | Mode demo; seluruh POI rute dikunjungi | 1. Buka rekomendasi. | Aplikasi menyatakan tidak ada objek lain dan menawarkan kembali ke gerbang. | F07 (deskripsi) | M |
| SK-F07-11 | Pengaruh rute aktif | Mode demo; posisi dan jam tetap | 1. Catat rekomendasi dengan rute Santai.<br>2. Ganti ke rute Sedang dan buka rekomendasi dari kondisi yang sama. | POI yang berada pada rute aktif mendapat peringkat lebih tinggi; alasan "di rute" sesuai rute yang dipilih. | F07 (deskripsi) | M |
| SK-F07-12 | P11 di luar rute Trekking | Mode demo; rute Santai atau Sedang | 1. Buka rekomendasi dari beberapa posisi. | Curug Omas tidak direkomendasikan di luar rute Trekking. | PRD §4.1 (P11) | M |
| SK-F07-13 | Gerbang bukan kandidat | Sesi aktif | 1. Buka rekomendasi dari beberapa posisi. | P01 Gerbang tidak pernah muncul sebagai POI rekomendasi; gerbang hanya muncul sebagai "Kembali ke gerbang". | F07 (deskripsi) | M |
| SK-F07-14 | Bobot dibaca dari berkas data | Build uji dengan bobot minat dan jarak ditukar pada `park.json` (disiapkan pengembang) | 1. Ulangi SK-F07-06 dengan build tersebut. | Urutan rekomendasi berubah sesuai bobot baru tanpa perubahan kode. | F07 (deskripsi), A05 | M |
| SK-F07-15 | Rekomendasi saat layar terkunci | Narasi selesai diputar dengan layar terkunci | 1. Dengarkan narasi sampai habis tanpa membuka ponsel. | Rekomendasi berikutnya disampaikan melalui notifikasi dan/atau suara singkat. | F07, F04 | L |

## A03 — Closing-Time Reminder

Ambang pengingat = jam tutup − waktu jalan ke gerbang − 15 menit. Waktu jalan ke gerbang dibaca dari aplikasi pada posisi uji, lalu ambang dihitung dan dicatat sebelum uji dijalankan. Jangan memakai angka tetap dari dokumen lain.

| ID | Skenario | Prasyarat | Langkah | Hasil yang diharapkan | Acuan | Metode |
|---|---|---|---|---|---|---|
| SK-A03-01 | Pengingat pada ambang terhitung | Mode demo; sesi aktif; posisi di P06 | 1. Catat waktu jalan P06→gerbang (W menit).<br>2. Hitung ambang = jam tutup − W − 15 menit.<br>3. Atur jam simulasi 2 menit sebelum ambang; pastikan belum ada pengingat.<br>4. Atur jam simulasi tepat pada ambang. | Pengingat muncul tepat pada ambang yang dihitung dan belum muncul sebelum itu. Isi pengingat menyebut jam tutup dan waktu jalan ke gerbang. | A03 AC, TC-10 | M |
| SK-A03-02 | Suara dan notifikasi | Lanjutan SK-A03-01; ulangi dengan layar terkunci | 1. Capai ambang dengan layar terkunci. | Pengingat disampaikan melalui suara dan notifikasi. | A03 AC, F04 (f) | M, L |
| SK-A03-03 | Opsi navigasi ke gerbang | Pengingat jam tutup tampil | 1. Ketuk opsi navigasi ke gerbang. | Navigasi ke P01 Gerbang dimulai dengan rute dan ETA. | A03 (deskripsi) | M |
| SK-A03-04 | Ambang bergeser mengikuti posisi | Mode demo | 1. Hitung ambang di P02 (dekat gerbang) dan di P06 (lebih jauh).<br>2. Uji pengingat di kedua posisi. | Pengingat di posisi yang lebih jauh muncul lebih awal, sesuai waktu jalan masing-masing. | A03 (deskripsi) | M |
| SK-A03-05 | Contoh skenario PRD | Posisi dengan waktu jalan ke gerbang ±25 menit; jam tutup 16.00 | 1. Atur jam simulasi 15.20. | Pengingat muncul sekitar pukul 15.20 dengan isi "Kawasan tutup pukul 16.00. Waktu jalan ke gerbang ±25 menit." (angka menyesuaikan waktu jalan aktual). | PRD §2.1 langkah 8 | M |
| SK-A03-06 | Jam operasional dari data | Build uji dengan jam tutup diubah pada `park.json` (disiapkan pengembang) | 1. Hitung ulang ambang dengan jam tutup baru dan ulangi SK-A03-01. | Pengingat mengikuti jam tutup baru tanpa perubahan kode. | A03 (deskripsi), A05 | M |
| SK-A03-07 | Tidak berulang dalam satu sesi | Pengingat jam tutup sudah muncul dan ditutup | 1. Lanjutkan sesi 10 menit simulasi. | Pengingat jam tutup tidak muncul berulang-ulang pada sesi yang sama. | A03 (rencana implementasi) | M |
| SK-A03-08 | Sesi dimulai setelah ambang | Mode demo; jam simulasi sudah melewati ambang | 1. Mulai sesi baru. | Pengingat segera muncul; pilihan rute menunjukkan rute yang tidak lagi cukup waktu. | A03 (rencana implementasi), F08 | M |
| SK-A03-09 | Tanpa sesi tidak ada pengingat | Tidak ada sesi aktif; jam melewati ambang | 1. Tunggu 2 menit di Beranda. | Tidak ada pengingat jam tutup di luar sesi jelajah. | A03 | M |

## F08 — Wellness Trail Explorer

### Data rute acuan (dipakai SK-F08-01)

Nilai PRD masih `[VERIFIKASI]`; nilai pada data aplikasi dihitung dari graf jalur OpenStreetMap dan berbeda dari PRD (PROGRESS #27). Catat nilai yang tampil dan selisihnya; keputusan nilai mana yang benar ada pada tim melalui Change Log.

| Rute | Nilai rencana PRD (`[VERIFIKASI]`) | Data aplikasi (`routes.json`) | Urutan POI pada data |
|---|---|---|---|
| Santai | 2,5 km · ±2 jam | 2,6 km · kenaikan 64 m · ±2 j 18 m · kesulitan 1 | P01, P03, P02, P04, P05, P06, P01 |
| Sedang | 4 km · ±3 jam | 6,6 km · kenaikan 234 m · ±4 j 46 m · kesulitan 2 | P01, P10, P03, P02, P04, P05, P08, P06, P07, P09, P01 |
| Trekking | 6 km · ±4 jam | 10,1 km · kenaikan 466 m · ±6 j 39 m · kesulitan 3 | urutan Sedang ditambah P11 sebelum kembali ke P01 |

### Skenario

| ID | Skenario | Prasyarat | Langkah | Hasil yang diharapkan | Acuan | Metode |
|---|---|---|---|---|---|---|
| SK-F08-01 | Tiga rute beserta datanya | Layar pilih rute terbuka | 1. Catat jarak, kenaikan elevasi, estimasi durasi, tingkat kesulitan, dan daftar POI setiap rute.<br>2. Bandingkan dengan tabel data rute acuan. | Tiga rute (Santai, Sedang, Trekking) tampil dengan jarak, elevasi, durasi, dan tingkat kesulitan; nilainya sama dengan data aplikasi. | F08 AC1, TC-11 | P |
| SK-F08-02 | Kelayakan rute terhadap jam tutup | Mode demo | 1. Buka pilih rute pada jam simulasi 09.00.<br>2. Ulangi pada jam simulasi 14.30. | Setiap rute menunjukkan apakah dapat selesai sebelum jam tutup; rute yang tidak cukup waktu ditandai. | PRD §2.1 langkah 1 | M |
| SK-F08-03 | Uji 200 langkah | Izin aktivitas fisik diberikan; perangkat memiliki sensor penghitung langkah (DEVICE_CHECK §1.3); sesi aktif | 1. Catat angka langkah awal.<br>2. Berjalan 200 langkah yang dihitung manual dengan ponsel di saku.<br>3. Catat angka langkah akhir.<br>4. Ulangi dengan ponsel di tangan, pada kedua perangkat uji. | Selisih langkah aplikasi terhadap hitungan manual ≤10% (180–220 langkah) pada setiap percobaan. | F08 AC2, TC-12 | L |
| SK-F08-04 | Jarak tempuh | Sesi aktif; ruas dengan panjang diketahui (mis. gerbang→P03 menurut aplikasi) | 1. Berjalan pada ruas tersebut dan catat jarak sesi.<br>2. Berdiri diam 5 menit dan catat kembali. | Jarak sesi mendekati panjang ruas; jarak tidak bertambah berarti saat penguji diam. | F08 (b) | L |
| SK-F08-05 | Durasi sesi | Sesi aktif | 1. Bandingkan durasi sesi dengan stopwatch selama 10 menit. | Durasi bertambah sesuai waktu sebenarnya. | F08 (b) | P |
| SK-F08-06 | Estimasi kalori | Sesi berjalan ≥10 menit; berat badan belum diisi | 1. Catat estimasi kalori.<br>2. Isi berat badan 80 kg di Setelan dan catat kembali. | Kalori ditampilkan sebagai estimasi; nilai bawaan memakai 60 kg; nilai naik sebanding setelah berat badan diubah. | F08 (b) | P, M |
| SK-F08-07 | Berat badan opsional dan hanya di perangkat | Setelan terbuka | 1. Kosongkan berat badan dan jalankan sesi.<br>2. Isi berat badan, tutup, dan buka kembali aplikasi. | Aplikasi berfungsi tanpa berat badan; nilai yang diisi tersimpan di perangkat dan tidak pernah diminta untuk dikirim atau didaftarkan. | F08 (b), NG05 | P |
| SK-F08-08 | Pengingat hidrasi bawaan 45 menit | Mode demo atau sesi nyata; interval bawaan | 1. Jalankan sesi hingga 45 menit (percepat dengan jam simulasi).<br>2. Ulangi dengan layar terkunci. | Pengingat hidrasi muncul pada menit ke-45 melalui suara dan notifikasi. | F08 AC3 | M, L |
| SK-F08-09 | Interval hidrasi diubah | Setelan terbuka | 1. Ubah interval ke 30 menit dan uji.<br>2. Ubah ke 60 menit dan uji.<br>3. Matikan pengingat dan uji selama 60 menit simulasi. | Pengingat muncul sesuai interval yang diatur; tidak muncul bila dimatikan. | F08 AC3, UI15 | M |
| SK-F08-10 | Penanda titik istirahat dan fasilitas | Tab Peta terbuka | 1. Perbesar peta dan periksa titik istirahat serta fasilitas.<br>2. Periksa isi pengingat hidrasi. | Titik istirahat dan fasilitas ditandai di peta; pengingat hidrasi merujuk titik istirahat. | F08 (c), PRD §4.1 (FS05) | P, M |
| SK-F08-11 | Ringkasan sesi sesuai log | Sesi uji terencana: catat secara manual POI yang dikunjungi, POI yang dijawab "Nanti", langkah, jarak, dan durasi | 1. Ketuk "Akhiri Jelajah".<br>2. Bandingkan ringkasan dengan catatan manual dan log sesi. | Ringkasan menampilkan seluruh metrik (langkah, jarak, durasi, kalori) dan daftar POI dikunjungi yang sama dengan log sesi. | F08 AC4 | L, M |
| SK-F08-12 | POI belum dikunjungi pada ringkasan | Lanjutan SK-F08-11 | 1. Periksa daftar POI yang belum dikunjungi. | POI yang hanya dilewati ("Nanti") tidak dihitung dikunjungi; daftar POI yang belum dikunjungi tampil untuk kunjungan berikutnya. | F08 (e), F02 | M |
| SK-F08-13 | Data aktivitas hanya di perangkat | Mode pesawat aktif sepanjang sesi | 1. Jalankan satu sesi penuh dalam mode pesawat hingga ringkasan.<br>2. Periksa daftar izin aplikasi di Setelan Android.<br>3. Minta bukti peninjauan kode bahwa data aktivitas tidak dikirim ke jaringan. | Sesi dan ringkasan lengkap tanpa internet; tidak ada login, unggahan, atau permintaan sinkronisasi. | F08 AC5, NG05 | P, D |
| SK-F08-14 | Konten flora-fauna | POI Detail P07, P08, P10 | 1. Baca teks dan dengarkan narasi ketiga POI. | Ketiga POI memuat konten edukasi flora/fauna (rusa, pinus, tanaman khas). | F08 (f) | P |
| SK-F08-15 | Izin aktivitas fisik ditolak | Pemasangan baru; izin aktivitas fisik ditolak | 1. Mulai sesi dan berjalan 2 menit. | Aplikasi tidak macet; jarak dan durasi tetap dicatat; ketiadaan angka langkah dijelaskan atau disembunyikan. | F08, UI01 | P |
| SK-F08-16 | Statistik sesi selama menjelajah | Sesi aktif | 1. Amati statistik pada Beranda/Peta sambil berjalan. | Langkah, jarak, durasi, dan jumlah POI dikunjungi tampil dan diperbarui selama sesi. | UI03, F08 | L |
| SK-F08-17 | Mulai dan akhiri jelajah | Rute dipilih | 1. Ketuk "Mulai Jelajah".<br>2. Setelah beberapa menit, ketuk "Akhiri Jelajah". | Sesi dimulai dengan penghitung dari nol dan jalur rute tampil di peta; setelah diakhiri, ringkasan tampil dan pelacakan berhenti. | PRD §2.1 langkah 2 dan 9, UI14 | P |
| SK-F08-18 | Aplikasi tertutup di tengah sesi | Sesi aktif dengan minimal satu POI dikunjungi | 1. Tutup paksa aplikasi dari daftar aplikasi terbaru.<br>2. Buka kembali. | Sesi dapat dilanjutkan dan data kunjungan tidak hilang; POI yang sudah dikunjungi tidak terpicu ulang. | F08 (rencana implementasi) | P |
| SK-F08-19 | Rute Trekking mengaktifkan P11 | Layar pilih rute | 1. Pilih rute Trekking dan periksa daftar POI. | Curug Omas hanya tercantum pada rute Trekking. | PRD §4.1 (P11) | P |
