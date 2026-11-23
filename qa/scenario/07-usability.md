# 07 — Usability Testing (PB20, F04 AC4)

Konvensi umum dijelaskan di [README.md](README.md). Berkas ini berisi protokol uji usability berbasis tugas dan kuesioner SUS.

Kriteria kelulusan dari PRD:
- ≥5 responden mengikuti uji berbasis tugas dan mengisi SUS (PB20).
- Skor SUS rata-rata ≥68, atau rencana perbaikan terdokumentasi (PB20).
- ≥4 dari 5 responden menyelesaikan satu kunjungan POI tanpa melihat layar (F04 AC4).

## Responden

Minimal lima orang yang belum pernah memakai aplikasi dan bukan anggota tim. Usahakan mewakili kelompok pengguna PRD §1.2:

| Kelompok | Jumlah sasaran |
|---|---|
| Pengunjung baru (remaja–dewasa) | 2 |
| Keluarga dengan anak | 1 |
| Mahasiswa/pelajar | 1 |
| Pejalan kaki/hiker atau pengunjung rutin | 1 |

Catat untuk setiap responden: kode (R1, R2, …), kelompok, rentang usia, pernah/belum berkunjung ke Tahura, dan merek ponsel yang biasa dipakai. Jangan mencatat nama lengkap atau nomor kontak pada laporan.

## Persiapan

- Lokasi: zona Dago Pakar, mulai dari gerbang. Bila hujan atau lokasi tidak memungkinkan, tugas T1, T4, T6 dapat dijalankan di luar lokasi dengan Mode demo; tugas T2, T3, T5 wajib di lapangan.
- Perangkat uji dengan aplikasi terpasang baru (onboarding belum dijalani), baterai penuh, earphone, mode pesawat aktif.
- Papan QR P05/P06 terpasang sementara (bila izin pengelola ada).
- Satu fasilitator (memberi tugas, tidak membantu) dan satu pencatat (waktu, kesalahan, kutipan).
- Persetujuan responden: jelaskan tujuan, durasi (±40 menit), bahwa yang diuji adalah aplikasi dan bukan responden, serta mintalah izin sebelum merekam layar/video. Wajah responden tidak ditampilkan tanpa izin tertulis.

## Tugas

Bacakan skenario apa adanya. Jangan menyebut nama tombol. Tugas dinyatakan **berhasil** bila selesai tanpa bantuan dalam batas waktu, **berhasil dengan bantuan** bila perlu satu petunjuk, dan **gagal** bila lebih dari itu atau melewati batas waktu.

| Tugas | Skenario yang dibacakan | Kriteria berhasil | Batas waktu | Requirement |
|---|---|---|---|---|
| T1 | "Anda baru tiba di Tahura dan ingin berjalan santai sekitar dua jam. Siapkan aplikasi ini sampai siap dipakai menjelajah." | Onboarding selesai, minat dan rute dipilih, sesi dimulai. | 4 menit | UI01, UI02, F08 |
| T2 | "Berjalanlah menuju objek terdekat di rute Anda dan cari tahu cerita tentang tempat itu." | Responden tiba di POI, menerima pemicu, dan membuka informasi atau mendengarkan narasi. | 10 menit | F02, F03 |
| T3 | "Simpan ponsel di saku dan pakai earphone. Lanjutkan ke objek berikutnya dan dengarkan ceritanya tanpa mengeluarkan ponsel." | Narasi satu POI didengar sampai selesai tanpa responden melihat layar. Pencatat mencatat setiap kali ponsel dikeluarkan. | 12 menit | F04 AC4 |
| T4 | "Teman Anda perlu ke toilet. Temukan toilet terdekat." | Responden menemukan toilet terdekat beserta jaraknya. | 2 menit | F05, A04 |
| T5 | "Antarkan teman Anda ke toilet itu dengan bantuan aplikasi." | Responden tiba di tujuan hanya dengan mengikuti navigasi. | 10 menit | F06 |
| T6 | "Anda masih punya waktu. Tanyakan pada aplikasi ke mana sebaiknya Anda pergi berikutnya, lalu akhiri penjelajahan dan lihat hasilnya." | Responden menemukan rekomendasi, mengakhiri sesi, dan dapat menyebutkan jumlah langkah atau jarak dari ringkasan. | 4 menit | F07, F08 |

## Lembar pengamatan (satu per responden)

| Tugas | Hasil (berhasil / dengan bantuan / gagal) | Waktu | Jumlah kesalahan | Ponsel dikeluarkan (khusus T3) | Catatan dan kutipan |
|---|---|---|---|---|---|
| T1 | | | | — | |
| T2 | | | | — | |
| T3 | | | | | |
| T4 | | | | — | |
| T5 | | | | — | |
| T6 | | | | — | |

Setelah tugas selesai, ajukan tiga pertanyaan terbuka: bagian mana yang paling membantu, bagian mana yang paling membingungkan, dan apa yang ingin diubah.

## Kuesioner SUS

Responden mengisi sendiri segera setelah tugas terakhir. Skala 1 (sangat tidak setuju) sampai 5 (sangat setuju).

| No. | Pernyataan | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| 1 | Saya berpikir akan menggunakan aplikasi ini lagi. | | | | | |
| 2 | Saya merasa aplikasi ini rumit untuk digunakan. | | | | | |
| 3 | Saya merasa aplikasi ini mudah digunakan. | | | | | |
| 4 | Saya membutuhkan bantuan orang lain atau teknisi untuk menggunakan aplikasi ini. | | | | | |
| 5 | Saya merasa fitur-fitur aplikasi ini berjalan dengan semestinya. | | | | | |
| 6 | Saya merasa ada banyak hal yang tidak konsisten pada aplikasi ini. | | | | | |
| 7 | Saya merasa orang lain akan memahami cara menggunakan aplikasi ini dengan cepat. | | | | | |
| 8 | Saya merasa aplikasi ini membingungkan. | | | | | |
| 9 | Saya merasa tidak ada hambatan dalam menggunakan aplikasi ini. | | | | | |
| 10 | Saya perlu membiasakan diri terlebih dahulu sebelum menggunakan aplikasi ini. | | | | | |

### Cara menghitung

1. Pernyataan ganjil (1, 3, 5, 7, 9): skor = jawaban − 1.
2. Pernyataan genap (2, 4, 6, 8, 10): skor = 5 − jawaban.
3. Skor SUS responden = jumlah kesepuluh skor × 2,5 (rentang 0–100).
4. Skor SUS produk = rata-rata skor seluruh responden.

## Rekap hasil

| Responden | T1 | T2 | T3 | T4 | T5 | T6 | Skor SUS |
|---|---|---|---|---|---|---|---|
| R1 | | | | | | | |
| R2 | | | | | | | |
| R3 | | | | | | | |
| R4 | | | | | | | |
| R5 | | | | | | | |
| **Ringkasan** | | | berhasil tanpa melihat layar: … dari … | | | | rata-rata: … |

| ID | Kriteria | Hasil yang diharapkan | Acuan | Penguji | Label | Cara uji di luar Tahura | Fase 2 (Tahura) | Lintas |
|---|---|---|---|---|---|---|---|---|
| SK-USB-01 | Jumlah responden dan kelengkapan data | ≥5 responden menyelesaikan seluruh tugas dan mengisi SUS. | PB20 | QA2 | LUAR | Responden di kampus; tugas berbasis lokasi memakai GPX 01/07. |  |  |
| SK-USB-02 | Kunjungan POI tanpa melihat layar (T3) | ≥4 dari 5 responden berhasil. | F04 AC4 | QA2 | LUAR | Responden di kampus; tugas berbasis lokasi memakai GPX 01/07. |  |  |
| SK-USB-03 | Skor SUS | Rata-rata ≥68; bila di bawah itu, rencana perbaikan terdokumentasi beserta temuan prioritas. | PB20 | QA2 | LUAR | Responden di kampus; tugas berbasis lokasi memakai GPX 01/07. |  |  |
| SK-USB-04 | Temuan dan tindak lanjut | Setiap tugas yang gagal pada ≥2 responden dicatat sebagai temuan prioritas dan diuji ulang setelah perbaikan. | PB20, PB21 | QA2 | LUAR | Responden di kampus; tugas berbasis lokasi memakai GPX 01/07. |  |  |
