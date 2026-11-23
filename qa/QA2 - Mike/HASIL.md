# Hasil uji QA2 — Mike

Penguji: Michael Dimas Sarono (QA2)
Perangkat: Samsung S25 Ultra, Android version 17

**Hasil:** `Lulus` · `Sebagian` · `Gagal` · kosong = belum dijalankan. Bukti dan cacat ditulis di sel Hasil setelah statusnya, mis. `Gagal — CD-001, [ss](bukti/F03/SK-F03-08_mike_2026-11-23.jpg)`.
**Metode:** P perangkat · D dokumen/data · M mode demo / menu debug · L lapangan · O uji otomatis.
Langkah, hasil yang diharapkan, label tempat uji, cara uji di luar Tahura, Fase 2, dan lintas perangkat untuk setiap ID ada di `qa/scenario/` (penjelasan kolom: `qa/scenario/README.md`, bagian *Pelaksanaan*). Aturan pengisian: `qa/README.md` §4.

## Fase 1 — di luar Tahura

Build (APK): Jelajah Taman v0.1.0+1, release build (arm64-v8a) of commit [32018e3](https://github.com/keaneplim/Transformasi-Digital-UAS/commit/32018e386d13724b5ebf258721d7d0d5cc643b05), built 2026-11-23 13:15 UTC.
Mulai: 23 November 2026 · Selesai: ____

Semua skenario dijalankan di luar Tahura. Jumlah: 112 skenario sendiri + 6 skenario lintas perangkat dari QA1 (Jacob).

### 1A. Tanpa GPS: ponsel, mode demo / menu debug, dokumen (93)

| ID        | Skenario                                              | Metode | Hasil    |
| --------- | ----------------------------------------------------- | ------ | -------- |
| SK-F03-01 | Kelengkapan 10 POI inti dalam mode pesawat            | P      | Lulus    |
| SK-F03-02 | Panjang dan bahasa teks                               | D, P   | Lulus    |
| SK-F03-03 | Fakta kunci                                           | P      | Lulus    |
| SK-F03-04 | Jumlah dan asal foto                                  | P, D   | Lulus    |
| SK-F03-05 | Durasi narasi audio                                   | P      | Lulus    |
| SK-F03-06 | Estimasi lama kunjungan                               | P      | Lulus    |
| SK-F03-07 | Kontrol pemutar audio                                 | P      | Sebagian |
| SK-F03-09 | Cadangan Text-to-Speech perangkat                     | P      |          |
| SK-F03-10 | Catatan keselamatan gua                               | P      | Lulus    |
| SK-F03-11 | Konten khusus per POI                                 | P      | Lulus    |
| SK-F03-12 | Sumber setiap fakta                                   | D      | Lulus    |
| SK-F03-13 | Kesesuaian audio dengan naskah                        | P, D   | Lulus    |
| SK-F03-14 | Audio berlanjut di luar layar POI Detail              | P      | Lulus    |
| SK-F03-15 | POI Detail dari setiap pintu masuk                    | P, M   | Lulus    |
| SK-F04-07 | Kontrol media di layar kunci                          | P      |          |
| SK-F04-08 | Tombol earphone                                       | P      |          |
| SK-F04-11 | Pengingat jam tutup melalui suara                     | M, L   |          |
| SK-F04-12 | Pengingat hidrasi melalui suara                       | M, L   |          |
| SK-F04-15 | Panggilan telepon saat narasi                         | P      |          |
| SK-F07-02 | Rekomendasi muncul setelah menutup POI Detail         | P, M   |          |
| SK-F07-04 | Pukul 15.30 di P06: kembali ke gerbang                | M      |          |
| SK-F07-05 | Saringan waktu sebelum jam tutup                      | M      |          |
| SK-F07-06 | Mengubah minat mengubah urutan                        | M      |          |
| SK-F07-07 | Navigasi satu ketukan                                 | P, M   |          |
| SK-F07-08 | Satu utama, dua alternatif, dan alasan                | P, M   |          |
| SK-F07-09 | POI "Nanti" tetap kandidat                            | M      |          |
| SK-F07-10 | Semua POI sudah dikunjungi                            | M      |          |
| SK-F07-11 | Pengaruh rute aktif                                   | M      |          |
| SK-F07-12 | P11 di luar rute Trekking                             | M      |          |
| SK-F07-13 | Gerbang bukan kandidat                                | M      |          |
| SK-F07-14 | Bobot dibaca dari berkas data                         | M      |          |
| SK-A03-01 | Pengingat pada ambang terhitung                       | M      |          |
| SK-A03-02 | Suara dan notifikasi                                  | M, L   |          |
| SK-A03-03 | Opsi navigasi ke gerbang                              | M      |          |
| SK-A03-04 | Ambang bergeser mengikuti posisi                      | M      |          |
| SK-A03-05 | Contoh skenario PRD                                   | M      |          |
| SK-A03-06 | Jam operasional dari data                             | M      |          |
| SK-A03-07 | Tidak berulang dalam satu sesi                        | M      |          |
| SK-A03-08 | Sesi dimulai setelah ambang                           | M      |          |
| SK-A03-09 | Tanpa sesi tidak ada pengingat                        | M      |          |
| SK-F08-01 | Tiga rute beserta datanya                             | P      |          |
| SK-F08-02 | Kelayakan rute terhadap jam tutup                     | M      |          |
| SK-F08-05 | Durasi sesi                                           | P      |          |
| SK-F08-06 | Estimasi kalori                                       | P, M   |          |
| SK-F08-07 | Berat badan opsional dan hanya di perangkat           | P      |          |
| SK-F08-08 | Pengingat hidrasi bawaan 45 menit                     | M, L   |          |
| SK-F08-09 | Interval hidrasi diubah                               | M      |          |
| SK-F08-10 | Penanda titik istirahat dan fasilitas                 | P, M   |          |
| SK-F08-12 | POI belum dikunjungi pada ringkasan                   | M      |          |
| SK-F08-13 | Data aktivitas hanya di perangkat                     | P, D   |          |
| SK-F08-14 | Konten flora-fauna                                    | P      |          |
| SK-F08-15 | Izin aktivitas fisik ditolak                          | P      |          |
| SK-F08-17 | Mulai dan akhiri jelajah                              | P      |          |
| SK-F08-18 | Aplikasi tertutup di tengah sesi                      | P      |          |
| SK-F08-19 | Rute Trekking mengaktifkan P11                        | P      |          |
| SK-A05-01 | Mengubah teks satu POI                                | D, P   |          |
| SK-A05-02 | Mengubah radius satu POI                              | D, M   |          |
| SK-A05-03 | Mengubah jam operasional                              | D, M   |          |
| SK-A05-04 | Mengubah data rute                                    | D, P   |          |
| SK-A05-05 | Data tidak valid ditolak                              | D      |          |
| SK-A05-06 | Data bawaan lolos validasi                            | D      |          |
| SK-A07-01 | Accessibility Scanner                                 | P      |          |
| SK-A07-02 | Ukuran teks diperbesar                                | P      |          |
| SK-A07-03 | Ukuran tombol utama                                   | P      |          |
| SK-A07-04 | Label pembaca layar                                   | P      |          |
| SK-A07-05 | Kontras                                               | P, L   |          |
| SK-ONB-01 | Onboarding dan permintaan izin                        | P      |          |
| SK-ONB-02 | Semua izin ditolak                                    | P      |          |
| SK-ONB-03 | Melewati onboarding                                   | P      |          |
| SK-ONB-04 | Izin diberikan belakangan                             | P      |          |
| SK-HOM-01 | Memilih minat dan rute                                | P      |          |
| SK-HOM-02 | Informasi jam operasional                             | P      |          |
| SK-SET-01 | Auto-Play                                             | M, L   |          |
| SK-SET-02 | Interval hidrasi                                      | M      |          |
| SK-SET-03 | Ukuran teks                                           | P      |          |
| SK-SET-04 | Informasi data luring                                 | P      |          |
| SK-SET-05 | Pengaturan bertahan                                   | P      |          |
| SK-NG-01  | Tanpa tiket/pembayaran                                | —     |          |
| SK-NG-02  | Hanya zona Dago Pakar                                 | —     |          |
| SK-NG-03  | Tanpa AR, beacon/BLE, computer vision                 | —     |          |
| SK-NG-04  | Tanpa CMS/dasbor admin                                | —     |          |
| SK-NG-05  | Tanpa akun dan data di server                         | —     |          |
| SK-NG-06  | Bukan alat darurat dan tanpa pelacakan oleh pengelola | —     |          |
| SK-NG-07  | Tanpa pemesanan atau transaksi                        | —     |          |
| SK-NG-08  | Hanya Bahasa Indonesia                                | —     |          |
| SK-TKS-01 | Tanpa detail operasional                              | —     |          |
| SK-TKS-02 | Sapaan dan gaya bahasa                                | —     |          |
| SK-TKS-03 | Format angka                                          | —     |          |
| SK-TKS-04 | Penanda yang tertinggal                               | —     |          |
| SK-USB-01 | Jumlah responden dan kelengkapan data                 | —     |          |
| SK-USB-02 | Kunjungan POI tanpa melihat layar (T3)                | —     |          |
| SK-USB-03 | Skor SUS                                              | —     |          |
| SK-USB-04 | Temuan dan tindak lanjut                              | —     |          |

### 1B. Fake GPS: mock location memutar trek GPX (17)

| ID        | Skenario                                     | Metode | Hasil    |
| --------- | -------------------------------------------- | ------ | -------- |
| SK-F03-08 | POI Detail dari notifikasi                   | L, P   | Berhasil |
| SK-F04-01 | Satu kunjungan POI dengan layar terkunci     | L      |          |
| SK-F04-02 | Getaran dan bunyi saat mendekati             | L      |          |
| SK-F04-03 | Prompt suara saat terpicu                    | L      |          |
| SK-F04-04 | Auto-Play aktif                              | L, M   |          |
| SK-F04-05 | Auto-Play nonaktif                           | L, M   |          |
| SK-F04-06 | Aksi "Dengarkan" tanpa membuka aplikasi      | L      |          |
| SK-F04-09 | Arahan suara di setiap simpul belokan        | L      |          |
| SK-F04-10 | Pengumuman tiba melalui suara                | L      |          |
| SK-F04-13 | Suara tersedia tanpa internet                | L      |          |
| SK-F04-14 | Arahan navigasi saat narasi diputar          | L      |          |
| SK-F04-16 | Kunjungan tanpa melihat layar oleh responden | L      |          |
| SK-F07-01 | Rekomendasi selalu POI yang belum dikunjungi | L, M   |          |
| SK-F07-03 | Rekomendasi muncul setelah keluar radius     | L      |          |
| SK-F07-15 | Rekomendasi saat layar terkunci              | L      |          |
| SK-F08-11 | Ringkasan sesi sesuai log                    | L, M   |          |
| SK-F08-16 | Statistik sesi selama menjelajah             | L      |          |

### 1C. GPS asli di luar ruangan (2)

| ID        | Skenario        | Metode | Hasil |
| --------- | --------------- | ------ | ----- |
| SK-F08-03 | Uji 200 langkah | L      |       |
| SK-F08-04 | Jarak tempuh    | L      |       |

### 1E. Skenario QA1 (Jacob) yang juga diuji di HP Anda (6)

Skenario sensitif perangkat. QA1 (Jacob) juga menjalankannya di HP-nya sendiri; tidak perlu bertukar HP.

| ID        | Skenario                                   | Metode | Hasil |
| --------- | ------------------------------------------ | ------ | ----- |
| SK-F01-01 | Posisi tampil setelah izin diberikan       | L      |       |
| SK-F01-07 | Lokasi tetap dibaca saat layar mati        | L      |       |
| SK-F02-20 | Notifikasi pemicu pada layar terkunci      | L      |       |
| SK-A02-01 | QR Gua Jepang, luring                      | L, P   |       |
| SK-A06-01 | Pemakaian baterai per jam sesi             | L      |       |
| SK-INS-01 | Terpasang dan terbuka di ≥2 perangkat uji | P      |       |

## Fase 2 — di Tahura

Build (APK): ______ (APK kandidat final) · Tanggal: ____

Hanya skenario yang harus dikonfirmasi di dalam Tahura karena kondisi taman (kanopi, tanjakan, sinyal, mulut gua) dapat mengubah hasilnya. Skenario ini juga sudah dijalankan di Fase 1; hasil Fase 2 dicatat terpisah di sini.

| ID        | Skenario                                 | Metode | Hasil |
| --------- | ---------------------------------------- | ------ | ----- |
| SK-F04-01 | Satu kunjungan POI dengan layar terkunci | L      |       |
| SK-A02-01 | QR Gua Jepang, luring · bagian QA1      | L, P   |       |
