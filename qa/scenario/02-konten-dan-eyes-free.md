# 02 — Konten Multimodal dan Eyes-Free (F03, F04)

Konvensi ID, kode metode, dan cara pencatatan hasil dijelaskan di [README.md](README.md).

## F03 — Multimodal Exploration

### Lembar periksa kelengkapan konten (dipakai SK-F03-01 s.d. SK-F03-06)

Isi satu baris per POI dalam mode pesawat. P11 bersifat opsional tetapi tetap diperiksa karena narasinya ikut dikemas (PRD 0.9.2, PB08).

| POI | Teks 80–150 kata | Fakta kunci | Jumlah foto (1–3) | Audio dapat diputar | Durasi audio 120–180 dtk | Estimasi lama kunjungan | Konten khusus PRD §4.1 |
|---|---|---|---|---|---|---|---|
| P01 Gerbang | | | | | | | Sambutan, jam buka, tata tertib |
| P02 Monumen | | | | | | | Profil Ir. H. Djuanda dan asal penamaan Tahura |
| P03 Museum | | | | | | | Jam buka museum |
| P04 Kolam Pakar | | | | | | | Asal-usul dan fungsi kolam |
| P05 Gua Jepang | | | | | | | Tips keselamatan |
| P06 Gua Belanda | | | | | | | Tips keselamatan |
| P07 Penangkaran Rusa | | | | | | | Etika satwa |
| P08 Hutan Pinus | | | | | | | Saran istirahat/hidrasi, penanda titik istirahat |
| P09 Area Piknik | | | | | | | Aturan kebersihan |
| P10 Koleksi Flora | | | | | | | Jenis tanaman khas Tahura |
| P11 Curug Omas | | | | | | | Peringatan keselamatan, jarak dan kesulitan jalur |

### Skenario

| ID | Skenario | Prasyarat | Langkah | Hasil yang diharapkan | Acuan | Metode | Penguji | Label | Cara uji di luar Tahura | Fase 2 (Tahura) | Lintas |
|---|---|---|---|---|---|---|---|---|---|---|---|
| SK-F03-01 | Kelengkapan 10 POI inti dalam mode pesawat | Mode pesawat aktif sejak sebelum aplikasi dibuka | 1. Buka POI Detail P01–P10 satu per satu.<br>2. Isi lembar periksa di atas. | Kesepuluh POI inti memiliki teks, ≥1 foto, dan audio; seluruhnya tampil lengkap tanpa internet. | F03 AC1, AC3, TC-05 | P | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |
| SK-F03-02 | Panjang dan bahasa teks | Akses ke `assets/content/pois.json` atau layar POI Detail | 1. Hitung jumlah kata teks setiap POI.<br>2. Periksa bahasa dan sapaan. | Setiap teks 80–150 kata, berbahasa Indonesia, menyapa pengguna dengan "Anda", tanpa penanda `[ISI]` atau teks draf pada build rilis. | F03 (deskripsi), NG08 | D, P | QA2 | LUAR | Periksa dokumen/data. |  |  |
| SK-F03-03 | Fakta kunci | POI Detail terbuka | 1. Periksa daftar fakta kunci setiap POI. | Fakta kunci tampil (tahun, jarak/ketinggian, kategori) untuk POI yang memilikinya. | F03 (deskripsi) | P | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |
| SK-F03-04 | Jumlah dan asal foto | POI Detail terbuka | 1. Geser galeri setiap POI dan hitung fotonya.<br>2. Cocokkan dengan `assets/content/image_credits.json`. | Setiap POI memiliki 1–3 foto; setiap foto memiliki kredit yang tercatat. Foto yang bukan dokumentasi tim dicatat sebagai temuan terhadap PRD §4.1 ("foto asli hasil survei"). | F03 (deskripsi), PRD §4.1 catatan akurasi | P, D | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |
| SK-F03-05 | Durasi narasi audio | POI Detail terbuka | 1. Putar narasi tiap POI dan catat durasi total yang ditampilkan pemutar. | Durasi setiap narasi 120–180 detik. | F03 (deskripsi), PB08 | P | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |
| SK-F03-06 | Estimasi lama kunjungan | POI Detail terbuka | 1. Periksa baris informasi di bawah nama POI. | Estimasi lama kunjungan tampil untuk setiap POI. | F03 (deskripsi) | P | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |
| SK-F03-07 | Kontrol pemutar audio | POI Detail P05 terbuka | 1. Ketuk putar.<br>2. Jeda pada detik ke-20.<br>3. Lanjutkan.<br>4. Biarkan hingga selesai, lalu putar ulang. | Audio dapat diputar, dijeda, dilanjutkan dari posisi jeda, dan diulang dari awal. | F03 AC2 | P | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |
| SK-F03-08 | POI Detail dari notifikasi | POI baru terpicu; notifikasi tampil | 1. Ketuk "Lihat" pada notifikasi dan mulai stopwatch.<br>2. Ulangi dengan aplikasi di latar belakang dan dengan aplikasi tertutup. | POI Detail yang benar terbuka dalam ≤2 detik pada kedua kondisi; catat waktu masing-masing pada perangkat uji yang lebih lambat. | F03 AC4 | L, P | QA2 | TAHURA→MOCK | GPX 01 dengan layar terkunci, ketuk notifikasi. |  |  |
| SK-F03-09 | Cadangan Text-to-Speech perangkat | Build uji dengan satu POI tanpa berkas audio (disiapkan pengembang); suara TTS Indonesia terpasang luring | 1. Buka POI tersebut dan ketuk putar dalam mode pesawat. | Teks POI dibacakan oleh TTS perangkat dalam Bahasa Indonesia; pemutar menunjukkan bahwa narasi memakai suara sintetis perangkat. | F03 (deskripsi) | P | QA2 | LUAR | Ponsel uji, di mana saja. |  | Ya |
| SK-F03-10 | Catatan keselamatan gua | POI Detail P05 dan P06 | 1. Periksa kartu catatan keselamatan. | Tips keselamatan tampil pada kedua gua. | PRD §4.1 (P05, P06) | P | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |
| SK-F03-11 | Konten khusus per POI | POI Detail seluruh POI | 1. Periksa kolom "Konten khusus" pada lembar periksa. | Setiap konten khusus yang disyaratkan PRD §4.1 tersedia. | PRD §4.1 | P | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |
| SK-F03-12 | Sumber setiap fakta | Akses ke `pois.json` (`sources`) dan `docs/content/narration/` | 1. Untuk setiap POI, cocokkan fakta pada teks dan naskah narasi dengan rujukan sumbernya.<br>2. Tandai fakta yang masih `[VERIFIKASI]`. | Setiap fakta memiliki sumber tercatat (pengelola, papan informasi, atau pengukuran survei); tidak ada fakta yang hanya bersumber dari AI. Fakta tanpa sumber resmi dicatat sebagai temuan. | PRD §4.1 catatan akurasi, §8.2 | D | QA2 | LUAR | Periksa dokumen/data. |  |  |
| SK-F03-13 | Kesesuaian audio dengan naskah | Naskah `docs/content/narration/P01–P11.md` | 1. Dengarkan setiap narasi sambil membaca naskahnya. | Isi audio sesuai naskah, tanpa kata yang salah ucap secara berarti atau terpotong; narasi tidak merujuk "tempat berikutnya" yang salah (PROGRESS #30). | PRD §8.2 (Audio narasi) | P, D | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |
| SK-F03-14 | Audio berlanjut di luar layar POI Detail | Narasi sedang diputar | 1. Kembali ke peta.<br>2. Kunci layar selama 30 detik. | Narasi tetap diputar saat berpindah layar dan saat layar terkunci. | F03, F04 | P | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |
| SK-F03-15 | POI Detail dari setiap pintu masuk | Sesi aktif | 1. Buka POI Detail dari marker peta, hasil pencarian, rekomendasi, QR, dan layar tiba. | POI yang benar terbuka dari setiap pintu masuk. | F03, UI06 | P, M | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |

## F04 — Eyes-Free Interaction

Perlengkapan: earphone kabel dan earphone Bluetooth, suara TTS Bahasa Indonesia terpasang luring (DEVICE_CHECK §1.4), pengaturan baterai sudah disesuaikan (DEVICE_CHECK §1.5).

| ID | Skenario | Prasyarat | Langkah | Hasil yang diharapkan | Acuan | Metode | Penguji | Label | Cara uji di luar Tahura | Fase 2 (Tahura) | Lintas |
|---|---|---|---|---|---|---|---|---|---|---|---|
| SK-F04-01 | Satu kunjungan POI dengan layar terkunci | Sesi aktif; earphone terpasang; ponsel terkunci di saku; mulai dari luar zona mendekati sebuah POI | 1. Berjalan menuju POI tanpa mengeluarkan ponsel.<br>2. Saat terpicu, mulai narasi melalui aksi notifikasi di layar kunci atau tombol earphone.<br>3. Jeda dan lanjutkan narasi melalui earphone/notifikasi.<br>4. Dengarkan sampai selesai. | Penguji menerima pemicu, mendengar narasi, serta menjeda dan melanjutkan audio tanpa membuka aplikasi. POI berstatus dikunjungi. | F04 AC1, TC-06 | L | QA2 | TAHURA→MOCK | GPX 01 dengan layar terkunci dan earphone. | Ya | Ya |
| SK-F04-02 | Getaran dan bunyi saat mendekati | Ponsel terkunci di saku | 1. Berjalan mendekati POI yang belum terpicu. | Getaran dan bunyi singkat terasa/terdengar dari dalam saku saat jarak ≤r + 30 m. | F04 (a) | L | QA2 | TAHURA→MOCK | GPX 01. |  |  |
| SK-F04-03 | Prompt suara saat terpicu | Ponsel terkunci di saku; earphone terpasang | 1. Masuki radius POI. | Terdengar prompt suara yang menyebut nama POI yang benar, mis. "Anda tiba di Gua Jepang. Ingin mendengar sejarahnya?". | F04 (b) | L | QA2 | TAHURA→MOCK | GPX 01. |  |  |
| SK-F04-04 | Auto-Play aktif | Pengaturan Auto-Play dinyalakan; sesi aktif | 1. Masuki radius POI.<br>2. Ukur waktu dari notifikasi pemicu hingga narasi mulai. | Narasi mulai dalam ≤3 detik setelah pemicu tanpa interaksi; POI berstatus dikunjungi. | F04 AC2 | L, M | QA2 | TAHURA→MOCK | GPX 01 dengan Auto-Play aktif. |  |  |
| SK-F04-05 | Auto-Play nonaktif | Pengaturan Auto-Play dimatikan | 1. Masuki radius POI dan tunggu 15 detik tanpa menyentuh ponsel. | Narasi tidak diputar otomatis; hanya getaran, notifikasi, dan prompt suara. | F04 (c) | L, M | QA2 | TAHURA→MOCK | GPX 01 dengan Auto-Play nonaktif. |  |  |
| SK-F04-06 | Aksi "Dengarkan" tanpa membuka aplikasi | Layar terkunci; notifikasi pemicu tampil | 1. Ketuk "Dengarkan" pada notifikasi di layar kunci. | Narasi diputar tanpa aplikasi tampil ke depan dan tanpa membuka kunci. | F04 AC1, (d) | L | QA2 | TAHURA→MOCK | GPX 01 dengan layar terkunci. |  |  |
| SK-F04-07 | Kontrol media di layar kunci | Narasi sedang diputar; layar terkunci | 1. Gunakan kontrol media di layar kunci untuk jeda dan lanjut. | Kontrol media menampilkan judul narasi dan dapat menjeda serta melanjutkan audio. | F04 (d), UI07 | P | QA2 | LUAR | Ponsel uji, di mana saja. |  | Ya |
| SK-F04-08 | Tombol earphone | Narasi sedang diputar | 1. Tekan tombol putar/jeda pada earphone kabel.<br>2. Ulangi dengan earphone Bluetooth. | Tombol earphone menjeda dan melanjutkan narasi pada kedua jenis earphone. | F04 AC1, (d) | P | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |
| SK-F04-09 | Arahan suara di setiap simpul belokan | Navigasi aktif pada rute uji yang memiliki persimpangan; daftar simpul belokan rute uji | 1. Ikuti rute dengan ponsel di saku.<br>2. Centang setiap persimpangan yang diumumkan. | Arahan suara terdengar di setiap simpul belokan rute uji dan isinya benar (arah serta tanjakan/turunan). | F04 AC3, TC-08 | L | QA2 | TAHURA→MOCK | GPX 07 sambil navigasi ke P06. |  |  |
| SK-F04-10 | Pengumuman tiba melalui suara | Navigasi aktif; ponsel di saku | 1. Berjalan hingga tujuan. | Kedatangan diumumkan melalui suara dengan nama tujuan yang benar. | F04 (e) | L | QA2 | TAHURA→MOCK | GPX 07. |  |  |
| SK-F04-11 | Pengingat jam tutup melalui suara | Lihat SK-A03-01; layar terkunci | 1. Capai ambang pengingat jam tutup dengan layar terkunci. | Pengingat disampaikan melalui suara dan notifikasi. | F04 (f), A03 | M, L | QA2 | LUAR | Mode demo / menu debug. |  |  |
| SK-F04-12 | Pengingat hidrasi melalui suara | Lihat SK-F08-08; layar terkunci | 1. Capai interval hidrasi dengan layar terkunci. | Pengingat disampaikan melalui suara dan notifikasi. | F04 (f), F08 AC3 | M, L | QA2 | LUAR | Mode demo / menu debug. |  |  |
| SK-F04-13 | Suara tersedia tanpa internet | Mode pesawat aktif | 1. Ulangi SK-F04-03 dan SK-F04-09 dalam mode pesawat. | Prompt suara dan arahan navigasi tetap terdengar dalam Bahasa Indonesia. | F04, A01 | L | QA2 | TAHURA→MOCK | GPX 07 dalam mode pesawat. |  | Ya |
| SK-F04-14 | Arahan navigasi saat narasi diputar | Narasi sedang diputar; navigasi aktif | 1. Dekati persimpangan saat narasi masih berjalan. | Arahan navigasi tetap terdengar jelas; narasi tidak hilang (dipelankan atau dijeda lalu dilanjutkan). | F04 (rencana implementasi: prioritas suara) | L | QA2 | TAHURA→MOCK | GPX 07 sambil narasi diputar. |  |  |
| SK-F04-15 | Panggilan telepon saat narasi | Narasi sedang diputar | 1. Terima panggilan masuk, lalu akhiri. | Narasi berhenti selama panggilan dan dapat dilanjutkan sesudahnya; aplikasi tidak macet. | F04 (rencana implementasi) | P | QA2 | LUAR | Ponsel uji, di mana saja. |  |  |
| SK-F04-16 | Kunjungan tanpa melihat layar oleh responden | Lihat [07-usability.md](07-usability.md) tugas T3 | 1. Jalankan tugas T3 pada ≥5 responden. | ≥4 dari 5 responden menyelesaikan satu kunjungan POI tanpa melihat layar. | F04 AC4, PB20 | L | QA2 | TAHURA→MOCK | Responden memakai GPX 01 di kampus (bagian dari usability). |  |  |
