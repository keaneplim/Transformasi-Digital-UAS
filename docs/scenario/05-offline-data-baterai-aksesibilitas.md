# 05 — Luring, Data, Baterai, dan Aksesibilitas (A01, A05, A06, A07)

Konvensi ID, kode metode, dan cara pencatatan hasil dijelaskan di [README.md](README.md).

## A01 — Offline Mode

"Mode pesawat" berarti data seluler dan Wi-Fi mati; GPS tetap bekerja. Aktifkan mode pesawat **sebelum** aplikasi dibuka agar tidak ada data yang sempat diambil dari internet.

| ID | Skenario | Prasyarat | Langkah | Hasil yang diharapkan | Acuan | Metode |
|---|---|---|---|---|---|---|
| SK-A01-01 | Alur F01–F08 penuh dalam mode pesawat | Mode pesawat aktif; penguji di gerbang Tahura; papan QR tersedia | 1. F01: buka peta, pastikan posisi tampil dan bergerak.<br>2. F08: pilih rute dan mulai jelajah.<br>3. F02: masuki radius satu POI hingga terpicu.<br>4. F03: buka POI Detail, periksa teks dan foto, putar audio.<br>5. F04: kunci layar, dengarkan dan jeda narasi dari notifikasi/earphone.<br>6. A02: pindai QR gua.<br>7. F05: cari `toilet`.<br>8. F06: navigasi ke hasil pencarian hingga tiba.<br>9. F07: tutup POI Detail berikutnya dan periksa rekomendasi.<br>10. F08: akhiri jelajah dan periksa ringkasan. | Seluruh langkah berhasil tanpa internet; tidak ada layar kosong, galat jaringan, atau konten yang gagal dimuat. | A01 AC, TC-13 | L |
| SK-A01-02 | Pemakaian pertama tanpa internet | Pemasangan baru (APK disalin langsung); mode pesawat aktif sebelum aplikasi pertama kali dibuka | 1. Buka aplikasi dan selesaikan onboarding.<br>2. Buka peta, satu POI Detail, dan putar audio. | Aplikasi langsung dapat dipakai; tidak ada unduhan yang diwajibkan atau gagal. | A01 (deskripsi) | P |
| SK-A01-03 | Peta luring | Mode pesawat aktif | 1. Buka tab Peta.<br>2. Geser dan perbesar peta ke seluruh zona. | Peta zona Dago Pakar, marker POI, marker fasilitas, jalur, dan titik pengguna tampil di semua tingkat perbesaran tanpa area kosong. | A01, PB05 | P |
| SK-A01-04 | Atribusi peta | Tab Peta terbuka | 1. Cari keterangan atribusi pada peta dan halaman Tentang. | Atribusi OpenStreetMap tampil. | PRD §8.1 (Map/Navigation) | P |
| SK-A01-05 | Lapisan satelit tanpa internet | Mode pesawat aktif | 1. Pilih lapisan satelit pada peta. | Aplikasi tidak macet; pengguna diberi tahu bahwa lapisan ini memerlukan internet dan peta kembali ke lapisan luring. Lapisan satelit berada di luar PRD (PROGRESS #26); kegagalannya tidak boleh mengganggu fitur inti. | A01 | P |
| SK-A01-06 | Sinyal hilang-timbul | Data seluler aktif di awal | 1. Selama sesi, nyalakan dan matikan mode pesawat beberapa kali saat berpindah layar. | Tidak ada perubahan perilaku fitur inti; tidak ada galat. | A01, PRD §2.1 (persona) | P |
| SK-A01-07 | Ukuran pemasangan | APK rilis | 1. Catat ukuran APK dan ruang terpakai setelah pemasangan. | Nilai tercatat pada laporan pengujian; aplikasi terpasang pada perangkat dengan ruang kosong ≥1 GB. | PB01, DEVICE_CHECK §1.1 | P |

## A05 — Data-Driven Content

Skenario ini memerlukan build uji dari pengembang: perubahan hanya dilakukan pada berkas di `assets/content/`, tanpa mengubah berkas `.dart`. Bukti berupa `git diff` yang hanya memuat berkas data.

| ID | Skenario | Prasyarat | Langkah | Hasil yang diharapkan | Acuan | Metode |
|---|---|---|---|---|---|---|
| SK-A05-01 | Mengubah teks satu POI | Build uji dengan teks P04 diubah pada `pois.json` | 1. Buka POI Detail P04. | Teks baru tampil; `git diff` tidak memuat perubahan kode sumber. | A05 AC | D, P |
| SK-A05-02 | Mengubah radius satu POI | Build uji dengan radius P04 diubah (mis. 30 → 45 m) | 1. Di Mode demo atau lapangan, dekati P04 dan catat jarak saat terpicu. | Pemicu mengikuti radius baru; `git diff` tidak memuat perubahan kode sumber. | A05 AC | D, M |
| SK-A05-03 | Mengubah jam operasional | Build uji dengan jam tutup diubah pada `park.json` | 1. Periksa jam tutup di Beranda.<br>2. Jalankan SK-A03-06. | Jam tutup baru tampil dan dipakai pengingat serta rekomendasi. | A05 (deskripsi), A03 | D, M |
| SK-A05-04 | Mengubah data rute | Build uji dengan nama atau durasi satu rute diubah pada `routes.json` | 1. Buka layar pilih rute. | Data rute baru tampil tanpa perubahan kode. | A05 (deskripsi) | D, P |
| SK-A05-05 | Data tidak valid ditolak | Salinan `pois.json` dengan kesalahan disengaja (ID ganda, foto tidak ada, radius di luar batas) | 1. Jalankan `python tools/validate_content.py`. | Validator melaporkan setiap kesalahan dan berakhir gagal, sehingga data rusak tidak lolos ke build. | A05 (rencana implementasi) | D |
| SK-A05-06 | Data bawaan lolos validasi | Cabang yang akan dirilis | 1. Jalankan `python tools/validate_content.py`. | Tidak ada galat; tidak ada penanda data contoh (`dummy`) pada build rilis. | A05, PB04 | D |

## A06 — Battery-Aware Tracking

| ID | Skenario | Prasyarat | Langkah | Hasil yang diharapkan | Acuan | Metode |
|---|---|---|---|---|---|---|
| SK-A06-01 | Pemakaian baterai per jam sesi | Baterai 100%; aplikasi lain ditutup; kecerahan dan mode hemat daya dicatat | 1. Mulai sesi dan catat persentase baterai.<br>2. Berjalan 60 menit dengan layar terkunci, sesekali mendengarkan narasi.<br>3. Catat persentase baterai akhir.<br>4. Ulangi pada perangkat uji kedua. | Penurunan baterai ≤15% per jam sesi pada setiap perangkat uji. | A06 AC | L |
| SK-A06-02 | Pelacakan saat diam | Sesi aktif | 1. Duduk diam 10 menit di dalam zona.<br>2. Berjalan kembali menuju POI yang belum terpicu. | Setelah kembali bergerak, posisi segera diperbarui dan pemicu tetap muncul ≤10 detik setelah memasuki radius. | A06 (deskripsi), F02 AC1 | L |

## A07 — Accessibility

Layar utama untuk pemeriksaan: Beranda, Peta, Cari, POI Detail, Mode dengar, Navigasi, Setelan.

| ID | Skenario | Prasyarat | Langkah | Hasil yang diharapkan | Acuan | Metode |
|---|---|---|---|---|---|---|
| SK-A07-01 | Accessibility Scanner | Aplikasi Accessibility Scanner (Google) terpasang | 1. Pindai setiap layar utama.<br>2. Simpan hasil pindaian. | Tidak ada isu kritis pada layar utama; isu lain dicatat beserta tangkapan layar. | A07 AC | P |
| SK-A07-02 | Ukuran teks diperbesar | Setelan aplikasi terbuka | 1. Pilih ukuran teks terbesar di Setelan aplikasi.<br>2. Naikkan pula ukuran font sistem Android ke maksimum.<br>3. Buka setiap layar utama. | Teks membesar; tidak ada teks terpotong, bertumpuk, atau tombol yang tidak dapat dijangkau. | A07 (deskripsi), UI15 | P |
| SK-A07-03 | Ukuran tombol utama | Layar utama terbuka | 1. Periksa ukuran target sentuh tombol utama melalui hasil Accessibility Scanner. | Tombol utama berukuran ≥48 dp. | A07 (deskripsi) | P |
| SK-A07-04 | Label pembaca layar | TalkBack aktif | 1. Jelajahi tombol utama pada setiap layar utama (putar/jeda, navigasi, pindai QR, pusatkan peta, mulai/akhiri jelajah). | Setiap tombol utama dibacakan dengan label berbahasa Indonesia yang bermakna, bukan "tombol tanpa label". | A07 (deskripsi) | P |
| SK-A07-05 | Kontras | Layar utama terbuka; luar ruangan di bawah sinar matahari | 1. Periksa peringatan kontras pada hasil Accessibility Scanner.<br>2. Baca layar utama di luar ruangan. | Tidak ada isu kontras kritis; teks utama terbaca di bawah sinar matahari. | A07 (deskripsi) | P, L |
