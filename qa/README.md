# QA Jelajah Taman — branch `qa`

Status dokumen: Aktif
Tujuan: ruang kerja QA (rencana, log hasil per penguji per putaran, panduan mock location). Folder ini **hanya ada di branch `qa`**. Yang dibawa ke `main` hanya rekapnya: `docs/qa/REKAP_QA.md`, ditulis Jacob setelah setiap putaran.

| Peran | Orang | Cakupan |
|---|---|---|
| QA-1 + penulis rekap | Jacob (PM) | Lokasi, pemicu, QR, pencarian, fasilitas, navigasi, offline, baterai, pemasangan, alur utama, ketahanan |
| QA-2 | Michael Dimas | Konten, eyes-free, rekomendasi, pengingat, wellness, data, aksesibilitas, onboarding/Beranda/Setelan, non-goals, teks antarmuka, usability |

## 1. Isi folder

```
qa/
├── README.md                ← dokumen ini: aturan kerja + cara AI membantu
├── RENCANA_QA.md            ← cakupan, label luar/Tahura, putaran, kriteria approve, hari Tahura
├── mock-location/
│   ├── PANDUAN.md           ← cara memutar GPX sebagai GPS palsu + daftar trek
│   ├── gpx/                 ← trek GPX per skenario (dibangkitkan dari data aplikasi)
│   └── make_gpx.py          ← pembangkit trek (jalankan ulang bila data jalur/POI berubah)
├── jacob/putaran-01/        ← HASIL.md (log per skenario per HP) · CACAT.md
└── dimas/putaran-01/        ← HASIL.md · CACAT.md
```

Skenario lengkap (prasyarat, langkah, hasil yang diharapkan) tetap di `docs/qa/scenario/` (dokumen tim, ikut `main`). Log hasil di sini hanya merujuk ID-nya (`SK-…`).

## 2. Aturan branch

- **Arah merge hanya `main` → `qa`.** Sebelum memulai putaran baru (dan setiap kali ada perubahan penting di `main`): GitHub Desktop → pilih branch `qa` → *Branch* → *Update from main*. Folder `qa/` tidak disentuh oleh `main`, jadi tidak akan konflik.
- **Jangan pernah merge `qa` ke `main`.** Rekap dibawa ke `main` sebagai commit terpisah oleh Jacob (`docs/qa/REKAP_QA.md`).
- Setiap penguji hanya meng-commit foldernya sendiri (`qa/jacob/` atau `qa/dimas/`). File bersama (`README.md`, `RENCANA_QA.md`, `mock-location/`) diubah oleh Jacob.
- Pesan commit: `qa(jacob): putaran 01, F02 SK-F02-01..09` atau `qa(dimas): putaran 01 cacat CD-003`.

## 3. Putaran uji dan arsip

- **Putaran** = satu kali menjalankan sekumpulan skenario pada **satu versi APK**. APK baru → putaran baru (`putaran-02/`, dst.).
- Putaran ditutup bila kedua penguji selesai mengisi `HASIL.md`. Setelah ditutup, folder putaran **tidak diubah lagi** (arsip). Uji ulang dicatat di putaran berikutnya.
- Putaran berikutnya: salin `HASIL.md` putaran sebelumnya, kosongkan kolom hasil, isi build baru. Yang wajib diuji: skenario `Gagal`/`Sebagian`/`Terblokir`, skenario fitur yang kodenya berubah, dan daftar asap (`docs/qa/scenario/README.md`, bagian *Uji ulang*).

## 4. Cara mengisi `HASIL.md`

1. Isi kepala: build (hash commit di halaman Release `apk-latest`), HP Anda (merek, model, versi Android), tanggal.
2. Jalankan skenario sesuai kolom **Cara uji di luar Tahura** (label di `RENCANA_QA.md` §3).
3. Isi kolom **Hasil**: `Lulus` · `Sebagian` · `Gagal` · `Terblokir`. Jangan lupa bagian *Uji lintas perangkat* di akhir berkas. Angka terukur ditulis apa adanya di *Catatan* (mis. "trigger 6 dtk", "deviasi 9 m").
4. **Bukti:** rekam layar / foto, simpan di Drive tim `QA/putaran-01/<penguji>/`, nama `<ID>_<penguji>_<tanggal>.<ext>`, contoh `SK-F02-02_jacob_2026-11-24.mp4`. Tulis nama berkasnya di kolom Bukti. Jangan masukkan video ke git.
5. Cacat → baris baru di `CACAT.md` (`CJ-nnn` Jacob, `CD-nnn` Dimas), lalu tulis ID-nya di kolom *Catatan / Cacat*.
6. Hasil dari mock location atau mode demo ditulis dengan keterangan "(mock GPX 01)" atau "(mode demo)" agar tidak tertukar dengan uji GPS asli.

## 5. Rekap ke `main` (Jacob)

Setelah putaran ditutup: hitung per fitur (lihat kolom *Fitur* di `docs/qa/REKAP_QA.md`), tentukan status QA (`Lulus` hanya bila semua skenario wajib lulus dan skenario lintas perangkatnya lulus di **HP Jacob dan HP Dimas**), salin cacat terbuka, lalu commit di `main`: `docs: QA rekap putaran 01`. Perbarui juga baris "Last closed round" di `.agents/PROGRESS.md` §Status QA.

## 6. Bantuan AI (Claude Code / agen lain)

Agen boleh membantu dokumentasi QA dengan batasan `.agents/rules.md` §9.1: **tidak pernah mengarang hasil**, hanya menulis apa yang dilaporkan penguji atau terlihat dari bukti. Penggunaan AI dicatat di `docs/qa/AI_DISCLOSURE_LOG.md`.

Perintah yang bisa langsung dipakai:

| Kebutuhan | Contoh permintaan ke agen |
|---|---|
| Mencatat hasil | "Catat di `qa/jacob/putaran-01/HASIL.md`: SK-F02-01 Lulus, getar 1x di 48 m, bukti SK-F02-01_jacob_2026-11-24.mp4." |
| Mencatat cacat | "Buat cacat baru di CACAT.md Dimas: SK-F04-06, tombol Dengarkan tidak bereaksi di layar kunci, Mayor." |
| Persiapan uji | "Skenario apa saja milik Jacob yang bisa diuji hari ini tanpa keluar rumah? Urutkan per GPX." |
| Langkah uji | "Tampilkan langkah dan hasil yang diharapkan SK-F06-04, serta GPX yang dipakai." |
| Rekap | "Buat draf `docs/qa/REKAP_QA.md` dari HASIL.md Jacob dan Dimas putaran 01 (tandai Draf AI)." |
| Putaran baru | "Siapkan putaran-02 untuk Jacob: salin dari putaran-01, hanya skenario yang belum Lulus + daftar asap." |

Agen yang bekerja di branch lain dapat membaca folder ini tanpa pindah branch:

```
git fetch origin qa
git ls-tree -r --name-only origin/qa qa/
git show origin/qa:qa/jacob/putaran-01/HASIL.md
```
