# QA Jelajah Taman — branch `qa`

Status dokumen: Aktif
Tujuan: satu-satunya folder QA (skenario, cek perangkat, rekap, log AI, rencana, hasil per penguji, panduan mock location). Folder ini **hanya ada di branch `qa`**; `docs/qa/` sudah tidak dipakai. Rekap per fitur ada di `qa/REKAP_QA.md`, ditulis Jacob setelah setiap fase.

| Peran | Orang | Folder | Cakupan |
|---|---|---|---|
| QA1 + penulis rekap | Jacob (PM) | `QA1 - Jacob/` | Lokasi, pemicu, QR, pencarian, fasilitas, navigasi, offline, baterai, pemasangan, alur utama, ketahanan |
| QA2 | Michael Dimas (Mike) | `QA2 - Mike/` | Konten, eyes-free, rekomendasi, pengingat, wellness, data, aksesibilitas, onboarding/Beranda/Setelan, non-goals, teks antarmuka, usability |

## 1. Isi folder

```
qa/
├── README.md                ← dokumen ini: aturan kerja + cara AI membantu
├── RENCANA_QA.md            ← cakupan, pembagian penguji, fase uji, kriteria approve, hari Tahura
├── REKAP_QA.md              ← status QA per fitur setelah tiap fase (Jacob)
├── DEVICE_CHECK.md          ← cek HP uji
├── AI_DISCLOSURE_LOG.md     ← log penggunaan AI (sumber AI & Tools Disclosure)
├── scenario/                ← skenario SK-* lengkap: langkah, hasil yang diharapkan, penguji,
│                              label tempat uji, cara uji di luar Tahura, Fase 2, lintas perangkat
├── mock-location/
│   ├── PANDUAN.md           ← cara memutar GPX sebagai GPS palsu + daftar trek
│   ├── gpx/                 ← trek GPX per skenario (dibangkitkan dari data aplikasi)
│   └── make_gpx.py          ← pembangkit trek (jalankan ulang bila data jalur/POI berubah)
├── QA1 - Jacob/             ← HASIL.md (Fase 1 + Fase 2) · CACAT.md · bukti/
└── QA2 - Mike/              ← HASIL.md (Fase 1 + Fase 2) · CACAT.md · bukti/
```

`HASIL.md` hanya berisi `ID | Skenario | Metode | Hasil`. Semua keterangan lain tentang skenario (langkah, label, cara uji di luar Tahura, Fase 2, lintas perangkat) ada di `qa/scenario/`; penjelasan kolomnya di `qa/scenario/README.md`, bagian *Pelaksanaan*.

## 2. Aturan branch

- **Arah merge hanya `main` → `qa`.** Sebelum memulai fase baru (dan setiap kali ada perubahan penting di `main`): GitHub Desktop → pilih branch `qa` → *Branch* → *Update from main*. Folder `qa/` tidak ada di `main`, jadi tidak akan konflik. (Catatan: `main` masih punya `docs/qa/` lama; bila update dari `main` membawanya kembali, hapus lagi dan pindahkan perubahannya ke `qa/`.)
- **Jangan pernah merge `qa` ke `main`.** Rekap ditulis Jacob di `qa/REKAP_QA.md` pada branch ini; ringkasannya dibawa ke `main` lewat `.agents/PROGRESS.md` §Status QA.
- Setiap penguji hanya meng-commit foldernya sendiri (`QA1 - Jacob/` atau `QA2 - Mike/`). File bersama (`README.md`, `RENCANA_QA.md`, `scenario/`, `mock-location/`) diubah oleh Jacob.
- Pesan commit: `qa(QA1): fase 1, F02 SK-F02-01..09` atau `qa(QA2): fase 1 cacat CD-003`.

## 3. Fase uji

Tidak ada putaran. Pengujian dibagi menjadi dua fase, masing-masing satu bagian di `HASIL.md`:

| Fase | Tempat | Isi | Build |
|---|---|---|---|
| **Fase 1** | Di luar Tahura | **Semua** skenario, dikelompokkan menurut cara uji: 1A tanpa GPS (ponsel, mode demo / menu debug, dokumen) · 1B fake GPS (mock location memutar GPX) · 1C GPS asli di luar ruangan · 1D papan QR cetak · 1E skenario lintas perangkat dari penguji lain | `apk-latest` yang berlaku saat fase dimulai |
| **Fase 2** | Di Tahura (satu hari, akhir Sprint 5) | Hanya skenario bertanda **Fase 2 = Ya** di `qa/scenario/`: hasilnya bisa berubah karena kondisi taman (kanopi, tanjakan, sinyal, mulut gua). Alur utama SK-E2E-* sekaligus menjadi demo | APK kandidat final |

**Uji ulang.** Bila APK baru memperbaiki cacat, jalankan ulang skenario itu di fase yang sama dan timpa sel Hasil dengan menyebut build-nya, mis. `Lulus (uji ulang 4f2a1c9)`. Hasil lama tetap tersimpan di riwayat git. Setelah perbaikan, jalankan juga daftar asap (`qa/scenario/README.md`, bagian *Uji ulang*).

## 4. Cara mengisi `HASIL.md`

1. Isi kepala: HP Anda (merek, model, versi Android). Di bawah judul tiap fase: build (hash commit dari halaman Release `apk-latest`) dan tanggal.
2. Buka skenarionya di `qa/scenario/` dan jalankan sesuai kolom **Cara uji di luar Tahura** (Fase 1) atau langkah aslinya di taman (Fase 2).
3. Isi kolom **Hasil**: `Lulus` · `Sebagian` · `Gagal`. Kosong = belum dijalankan. Angka terukur, ID cacat, dan bukti ditulis di sel yang sama setelah statusnya, mis. `Lulus — getar 1× di 48 m (mock GPX 01), [ss](bukti/F02/SK-F02-01_jacob_2026-11-24.jpg)`.
4. **Bukti:**
   - **Screenshot** disimpan di `bukti/<kelompok>/` di folder Anda (mis. `qa/QA2 - Mike/bukti/F03/`), format JPG, dikecilkan ke ±300 KB (lebar ±1080 px). Nama: `<ID>_<penguji>_<tanggal>.jpg`, contoh `SK-F03-07_mike_2026-11-23.jpg`; lebih dari satu gambar: tambah `_2`, `_3`.
   - Tautan relatif seperti `[ss](bukti/F03/SK-F03-07_mike_2026-11-23.jpg)` bisa diklik di GitHub dan di pratinjau Markdown VS Code (Ctrl+Shift+V).
   - **Video** (untuk hal yang tidak terlihat di gambar diam: waktu ≤10 detik, getar, suara) tidak dimasukkan ke git. Simpan di Drive tim `QA/<fase>/<penguji>/` dengan nama yang sama (`.mp4`) dan tulis tautannya di sel Hasil, mis. `[video](https://drive.google.com/...)`. Bila tanpa video, tulis angka terukur (mis. "muncul 6 dtk, getar 1×").
   - Jangan menampilkan wajah orang lain tanpa izin.
5. Cacat → baris baru di `CACAT.md` (`CJ-nnn` Jacob, `CD-nnn` Mike), lalu tulis ID-nya di sel Hasil.
6. Hasil dari mock location atau mode demo diberi keterangan "(mock GPX 01)" atau "(mode demo)" agar tidak tertukar dengan uji GPS asli.

## 5. Rekap (Jacob)

Setelah suatu fase selesai: hitung per fitur (lihat kolom *Fitur* di `qa/REKAP_QA.md`), tentukan status QA (`Lulus` hanya bila semua skenario wajib lulus dan skenario lintas perangkatnya lulus di **HP Jacob dan HP Mike**), salin cacat terbuka, lalu commit di branch `qa`: `qa: rekap fase 1`. Perbarui juga baris "Last closed phase" di `.agents/PROGRESS.md` §Status QA.

## 6. Bantuan AI (Claude Code / agen lain)

Agen boleh membantu dokumentasi QA dengan batasan `.agents/rules.md` §9.1: **tidak pernah mengarang hasil**, hanya menulis apa yang dilaporkan penguji atau terlihat dari bukti. Penggunaan AI dicatat di `qa/AI_DISCLOSURE_LOG.md`.

Perintah yang bisa langsung dipakai:

| Kebutuhan | Contoh permintaan ke agen |
|---|---|
| Mencatat hasil | "Catat SK-F02-01 Lulus Fase 1 di HASIL.md QA1, getar 1x di 48 m, buktinya `Downloads/Screenshot_20261124_101500.jpg`." (AI menyalin, mengganti nama, mengecilkan gambar ke `bukti/`, lalu mengisi sel Hasil) |
| Mencatat cacat | "Buat cacat baru di CACAT.md QA2: SK-F04-06, tombol Dengarkan tidak bereaksi di layar kunci, Mayor." |
| Persiapan uji | "Skenario apa saja Fase 1 milik QA1 yang bisa diuji hari ini tanpa keluar rumah? Urutkan per GPX." |
| Langkah uji | "Tampilkan langkah dan hasil yang diharapkan SK-F06-04, serta GPX yang dipakai." |
| Rekap | "Buat draf `qa/REKAP_QA.md` dari HASIL.md QA1 dan QA2 Fase 1 (tandai Draf AI)." |
| Uji ulang | "APK baru 4f2a1c9 memperbaiki CD-002. Skenario mana di HASIL.md QA2 yang perlu diuji ulang?" |

Agen yang bekerja di branch lain dapat membaca folder ini tanpa pindah branch:

```
git fetch origin qa
git ls-tree -r --name-only origin/qa qa/
git show "origin/qa:qa/QA1 - Jacob/HASIL.md"
```
