# Hasil uji QA1 — Jacob

Penguji: Jacob Reinhard Marudut Siagian (QA1)
Perangkat: ______ (merek, model, versi Android)

**Hasil:** `Lulus` · `Sebagian` · `Gagal` · kosong = belum dijalankan. Bukti dan cacat ditulis di sel Hasil setelah statusnya, mis. `Gagal — CJ-001, [ss](bukti/F03/SK-F03-08_jacob_2026-11-23.jpg)`.
**Metode:** P perangkat · D dokumen/data · M mode demo / menu debug · L lapangan · O uji otomatis.
Langkah, hasil yang diharapkan, label tempat uji, cara uji di luar Tahura, Fase 2, dan lintas perangkat untuk setiap ID ada di `qa/scenario/` (penjelasan kolom: `qa/scenario/README.md`, bagian *Pelaksanaan*). Aturan pengisian: `qa/README.md` §4.

## Fase 1 — di luar Tahura

Build (APK): `apk-latest` — hash commit dan tanggal build dari halaman rilis: ______
Mulai: ____ · Selesai: ____

Semua skenario dijalankan di luar Tahura. Jumlah: 107 skenario sendiri + 6 skenario lintas perangkat dari QA2 (Mike).

### 1A. Tanpa GPS: ponsel, mode demo / menu debug, dokumen (53)

| ID | Skenario | Metode | Hasil |
|---|---|---|---|
| SK-F01-04 | Izin lokasi ditolak | P |  |
| SK-F01-09 | Layanan lokasi perangkat dimatikan | P |  |
| SK-F01-10 | Penguji di luar kawasan | P |  |
| SK-F01-11 | Pelacakan berhenti setelah sesi diakhiri | P |  |
| SK-F02-10 | Pilihan "Nanti" tidak menandai dikunjungi | M, L |  |
| SK-F02-11 | Pilihan "Dengarkan" menandai dikunjungi | M, L |  |
| SK-F02-12 | Pilihan "Lihat" menandai dikunjungi | M, L |  |
| SK-F02-14 | Lompatan GPS sesaat tidak memicu | O |  |
| SK-F02-16 | Pemilihan POI secara manual | P, M |  |
| SK-F02-18 | P11 hanya aktif pada rute Trekking | M |  |
| SK-F02-21 | Pencatatan pemicu dan kunjungan | P |  |
| SK-A02-03 | QR asing | P |  |
| SK-A02-04 | QR berskema benar dengan ID tidak dikenal | P |  |
| SK-A02-05 | Pemindaian QR menandai dikunjungi | P, M |  |
| SK-A02-07 | Izin kamera ditolak | P |  |
| SK-A02-08 | QR untuk POI yang sudah dikunjungi | P |  |
| SK-A02-09 | QR dipindai tanpa sesi aktif | P |  |
| SK-F05-01 | Kata kunci "gua" | P |  |
| SK-F05-02 | Kata kunci "toilet" | P |  |
| SK-F05-03 | Pencocokan sebagian dan tidak peka huruf besar/kecil | P |  |
| SK-F05-04 | Filter kategori | P |  |
| SK-F05-05 | Filter digabung dengan kata kunci | P |  |
| SK-F05-08 | Kecepatan pencarian luring | P |  |
| SK-F05-09 | Kata kunci tidak ditemukan | P |  |
| SK-F05-10 | Satu salah ketik | P |  |
| SK-F05-11 | Batas toleransi salah ketik | P, O |  |
| SK-F05-12 | Sinonim | P |  |
| SK-F05-13 | Memilih hasil membuka detail | P |  |
| SK-F05-14 | Memilih hasil memulai navigasi | P, M |  |
| SK-F05-15 | Masukan tidak lazim | P |  |
| SK-F05-16 | Pencarian tanpa posisi | P |  |
| SK-A04-01 | Marker fasilitas di peta | P |  |
| SK-A04-02 | Filter "Fasilitas" | P |  |
| SK-A04-05 | Setiap jenis fasilitas dapat dicari | P |  |
| SK-F06-12 | Membatalkan navigasi | P, M |  |
| SK-F06-13 | Titik masuk navigasi | M, L |  |
| SK-F06-15 | ETA memperhitungkan tanjakan | M, O |  |
| SK-F06-16 | Rute terpendek | O |  |
| SK-F06-18 | Seluruh POI dan fasilitas terjangkau | M, O |  |
| SK-A01-02 | Pemakaian pertama tanpa internet | P |  |
| SK-A01-03 | Peta luring | P |  |
| SK-A01-04 | Atribusi peta | P |  |
| SK-A01-05 | Lapisan satelit tanpa internet | P |  |
| SK-A01-06 | Sinyal hilang-timbul | P |  |
| SK-A01-07 | Ukuran pemasangan | P |  |
| SK-INS-01 | Terpasang dan terbuka di ≥2 perangkat uji | P |  |
| SK-INS-02 | Pembaruan di atas versi lama | P |  |
| SK-INS-03 | Aplikasi dibuka kembali | P |  |
| SK-KTH-01 | Berpindah aplikasi selama sesi | — |  |
| SK-KTH-02 | Layar diputar | — |  |
| SK-KTH-03 | Baterai rendah / hemat daya | — |  |
| SK-KTH-04 | Sesi panjang | — |  |
| SK-KTH-05 | Tombol kembali Android | — |  |

### 1B. Fake GPS: mock location memutar trek GPX (41)

| ID | Skenario | Metode | Hasil |
|---|---|---|---|
| SK-F01-06 | Pembacaan GPS lemah tidak dipakai untuk pemicu | L, O |  |
| SK-F02-01 | Getaran saat mendekati POI | L, M |  |
| SK-F02-02 | Pemicu pada 10 POI inti | L |  |
| SK-F02-03 | Tidak ada pemicu palsu | L |  |
| SK-F02-04 | Tidak berulang selama berada di dalam radius | L, O |  |
| SK-F02-05 | Keluar lalu masuk kembali sebelum 10 menit | L, O |  |
| SK-F02-06 | Pemicu ulang setelah keluar dan lewat 10 menit | L, O |  |
| SK-F02-07 | Getaran tidak berulang di tepi zona mendekati | L, O |  |
| SK-F02-08 | Pendekatan baru setelah menjauh | L, O |  |
| SK-F02-09 | Melewati POI yang sudah dikunjungi | L, M |  |
| SK-F02-13 | Dua POI berdekatan | L, O |  |
| SK-F02-17 | Aturan khusus P01 Gerbang | L |  |
| SK-F02-19 | Tanpa sesi tidak ada pemicu | L |  |
| SK-F02-20 | Notifikasi pemicu pada layar terkunci | L |  |
| SK-F02-22 | Izin notifikasi ditolak | L, M |  |
| SK-F05-06 | Urutan menurut jarak jalan kaki | L, M |  |
| SK-F05-07 | Urutan berubah mengikuti posisi | L, M |  |
| SK-A04-03 | Fasilitas dapat dinavigasi | L, M |  |
| SK-A04-04 | Fasilitas tidak memicu notifikasi | L |  |
| SK-F06-01 | Rute mengikuti jalur setapak | L |  |
| SK-F06-02 | Sisa jarak dan ETA berkurang | L |  |
| SK-F06-03 | Mencapai tiga tujuan hanya dengan navigasi | L |  |
| SK-F06-04 | Hitung ulang setelah menyimpang | L |  |
| SK-F06-05 | Navigasi dalam mode pesawat | L |  |
| SK-F06-07 | Status tiba | L |  |
| SK-F06-08 | Tiba tidak memicu ulang POI | L, M |  |
| SK-F06-09 | Tawaran "Buka detail" saat tiba | L, M |  |
| SK-F06-10 | Tiba di fasilitas | L, M |  |
| SK-F06-11 | Arahan di persimpangan | L |  |
| SK-F06-14 | Simpangan kecil tidak menghitung ulang | L |  |
| SK-F06-17 | GPS lemah selama navigasi | L |  |
| SK-A01-01 | Alur F01–F08 penuh dalam mode pesawat | L |  |
| SK-E2E-01 | 1. Start | — |  |
| SK-E2E-02 | 2. Explore | — |  |
| SK-E2E-03 | 3. Location Trigger | — |  |
| SK-E2E-04 | 4. Information | — |  |
| SK-E2E-05 | 5. Recommendation | — |  |
| SK-E2E-06 | 6. Search Destination | — |  |
| SK-E2E-07 | 7. Navigation | — |  |
| SK-E2E-08 | 8. Lanjut eksplorasi dan pengingat | — |  |
| SK-E2E-09 | 9. Selesai | — |  |

### 1C. GPS asli di luar ruangan (10)

| ID | Skenario | Metode | Hasil |
|---|---|---|---|
| SK-F01-01 | Posisi tampil setelah izin diberikan | L |  |
| SK-F01-02 | Posisi diperbarui saat berjalan | L |  |
| SK-F01-03 | Deviasi posisi terhadap titik referensi | L |  |
| SK-F01-05 | Indikator "GPS lemah" | L |  |
| SK-F01-07 | Lokasi tetap dibaca saat layar mati | L |  |
| SK-F01-08 | Pengguna diam tetap menghasilkan pembacaan | L |  |
| SK-F02-15 | Banner saat GPS lemah 60 detik | L |  |
| SK-F06-06 | Akurasi ETA | L |  |
| SK-A06-01 | Pemakaian baterai per jam sesi | L |  |
| SK-A06-02 | Pelacakan saat diam | L |  |

### 1D. Papan QR cetak (3)

| ID | Skenario | Metode | Hasil |
|---|---|---|---|
| SK-A02-01 | QR Gua Jepang, luring | L, P |  |
| SK-A02-02 | QR Gua Belanda, luring | L, P |  |
| SK-A02-06 | QR di kondisi gelap | L |  |

### 1E. Skenario QA2 (Mike) yang juga diuji di HP Anda (6)

Skenario sensitif perangkat. QA2 (Mike) juga menjalankannya di HP-nya sendiri; tidak perlu bertukar HP.

| ID | Skenario | Metode | Hasil |
|---|---|---|---|
| SK-F03-09 | Cadangan Text-to-Speech perangkat | P |  |
| SK-F04-01 | Satu kunjungan POI dengan layar terkunci | L |  |
| SK-F04-07 | Kontrol media di layar kunci | P |  |
| SK-F04-13 | Suara tersedia tanpa internet | L |  |
| SK-A03-02 | Suara dan notifikasi | M, L |  |
| SK-F08-03 | Uji 200 langkah | L |  |

## Fase 2 — di Tahura

Build (APK): ______ (APK kandidat final) · Tanggal: ____

Hanya skenario yang harus dikonfirmasi di dalam Tahura karena kondisi taman (kanopi, tanjakan, sinyal, mulut gua) dapat mengubah hasilnya. Skenario ini juga sudah dijalankan di Fase 1; hasil Fase 2 dicatat terpisah di sini.

| ID | Skenario | Metode | Hasil |
|---|---|---|---|
| SK-F01-03 | Deviasi posisi terhadap titik referensi | L |  |
| SK-F02-02 | Pemicu pada 10 POI inti | L |  |
| SK-F02-03 | Tidak ada pemicu palsu | L |  |
| SK-A02-01 | QR Gua Jepang, luring | L, P |  |
| SK-A02-02 | QR Gua Belanda, luring | L, P |  |
| SK-A02-06 | QR di kondisi gelap | L |  |
| SK-F06-03 | Mencapai tiga tujuan hanya dengan navigasi | L |  |
| SK-F06-06 | Akurasi ETA | L |  |
| SK-E2E-01 | 1. Start | — |  |
| SK-E2E-02 | 2. Explore | — |  |
| SK-E2E-03 | 3. Location Trigger | — |  |
| SK-E2E-04 | 4. Information | — |  |
| SK-E2E-05 | 5. Recommendation | — |  |
| SK-E2E-06 | 6. Search Destination | — |  |
| SK-E2E-07 | 7. Navigation | — |  |
| SK-E2E-08 | 8. Lanjut eksplorasi dan pengingat | — |  |
| SK-E2E-09 | 9. Selesai | — |  |
| SK-F04-01 | Satu kunjungan POI dengan layar terkunci · bagian QA2 | L |  |
