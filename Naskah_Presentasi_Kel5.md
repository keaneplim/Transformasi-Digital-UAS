# Naskah Presentasi — Jelajah Taman (Kelompok 5)

Durasi total: ±16–18 menit + tanya jawab. Pembagian pembicara mengikuti peran di tim dan dapat disesuaikan.

| Pembicara | Slide |
|---|---|
| Jacob | 1, 2, 12, 15 |
| Keane | 3, 4, 5 |
| Michael Dimas | 6, 11 |
| Khalfani | 7, 14 |
| Michael Ballard | 8, 9, 10, 13 |

---

## Slide 1 — Pembuka
**Pembicara:** Jacob · **Durasi:** ±45 detik

Selamat pagi, Prof. Kridanto, dan teman-teman. Kami dari Kelompok 5. Saya Jacob, Project Manager, bersama Keane sebagai Business Analyst, Michael Dimas sebagai UX/UI Designer, Michael Ballard sebagai Developer, dan Khalfani sebagai Quality Assurance.

Hari ini kami mempresentasikan Product Requirements Document untuk Jelajah Taman, aplikasi pemandu eksplorasi berbasis lokasi untuk Topik 7, Public Park & Wellness Explorer. Studi kasus kami adalah Taman Hutan Raya Ir. H. Djuanda, khususnya zona Dago Pakar di Bandung.

Dokumen ini masih draft versi 0.9. Tujuan kami hari ini adalah mendapatkan persetujuan agar dokumen ini menjadi baseline versi 1.0 sebelum pengembangan dimulai.

---

## Slide 2 — Ringkasan Eksekutif
**Pembicara:** Jacob · **Durasi:** ±1 menit

Secara ringkas, ada lima hal.

Pertama, konteks: Tahura Djuanda luasnya sekitar 590 hektare, dengan objek sejarah dan alam seperti Gua Jepang, Gua Belanda, dan Monumen Ir. H. Djuanda yang tersebar di jalur hutan.

Kedua, masalahnya: informasi hanya bergantung pada rambu fisik yang sedikit dan minim cerita. Akibatnya, pengunjung baru sering bertanya ke petugas, berisiko salah jalur, dan biasanya hanya mengunjungi satu titik.

Ketiga, solusi kami: aplikasi yang otomatis memberi informasi saat pengunjung mendekati objek, dengan cadangan QR di dalam gua, narasi audio, navigasi offline, rekomendasi yang memperhitungkan jam tutup, dan fitur Wellness Trail.

Keempat, rencananya lima sprint mingguan, dari Week 10 sampai Week 14.

Dan kelima, keputusan yang kami minta hari ini: persetujuan baseline, serta konfirmasi lingkup zona Dago Pakar dan penggunaan QR sebagai pemicu cadangan.

Panel kanan menunjukkan skala produknya: 10 POI, 8 requirement inti yang semuanya Must, dan 13 test case. Selanjutnya, Keane akan menjelaskan masalahnya lebih detail.

---

## Slide 3 — Problem Statement
**Pembicara:** Keane · **Durasi:** ±1 menit

Terima kasih, Jacob. Slide ini kami baca dari kiri ke kanan.

Ada tiga akar masalah: kawasannya luas dan berkontur; rambu fisiknya terbatas, yaitu sedikit, kecil, dan minim informasi sejarah; dan sinyal seluler di dalam hutan hilang-timbul.

Dari situ muncul empat gejala pada pengunjung. Mereka bertanya berulang ke petugas, misalnya "di mana gua?" atau "berapa jauh?"; berisiko salah jalur di persimpangan; tidak bisa memperkirakan waktu dan tenaga; dan akhirnya hanya mengunjungi satu titik.

Dampaknya ada tiga. Keselamatan, karena pengunjung bisa tersesat atau tertahan menjelang jam tutup di kawasan hutan. Kualitas pengalaman, karena nilai edukasinya tidak tersampaikan. Dan pemerataan kunjungan antar-objek.

Karena itu, peluang transformasi digitalnya jelas: rambu statis bisa diubah menjadi pemandu kontekstual yang muncul otomatis saat pengunjung mendekati objek, bisa didengar lewat audio, dan tetap berjalan tanpa sinyal.

---

## Slide 4 — Target User & Stakeholder
**Pembicara:** Keane · **Durasi:** ±1 menit

Siapa penggunanya? Kami memetakan empat segmen pengguna, yaitu pengunjung baru, keluarga dengan anak, mahasiswa atau pelajar, serta hiker atau pengunjung rutin. Ada juga dua stakeholder: pengelola Tahura dan petugas lapangan.

Setiap titik pada matriks ini adalah kebutuhan yang dinyatakan secara eksplisit di PRD. Baris paling bawah menunjukkan temuannya: kebutuhan cari dan navigasi muncul di empat segmen, dan konten sejarah serta alam di tiga segmen. Keduanya menjadi fondasi produk.

Sementara itu, audio eyes-free dan fasilitas terutama dibutuhkan keluarga, yang perhatiannya terbagi untuk mengawasi anak, dan rute sehat dibutuhkan hiker. Fitur-fitur inilah yang menjadi pembeda.

Untuk pengelola, kami sengaja tidak membuat CMS. Kebutuhan memperbarui konten dipenuhi lewat file data POI berformat JSON.

---

## Slide 5 — Proposed Product, Goals & Non-Goals
**Pembicara:** Keane · **Durasi:** ±1 menit

Lalu apa yang kami tawarkan? Tabel ini membandingkan kondisi saat ini, dengan rambu fisik, dan kondisi dengan Jelajah Taman untuk enam kebutuhan.

Untuk menemukan objek, ada peta offline dan pencarian. Untuk informasi di objek, konten muncul otomatis saat masuk radius: foto, teks singkat, dan audio. Untuk menuju objek, ada navigasi di jalur setapak dengan arahan suara. Interaksinya eyes-free, jadi pengunjung tidak perlu terus menatap layar. Untuk merencanakan waktu, ada rekomendasi yang memperhitungkan jam tutup. Dan untuk aktivitas sehat, ada Wellness Trail. Kolom paling kanan menunjukkan requirement terkait.

Panel kanan berisi delapan hal yang sengaja tidak kami kerjakan pada versi awal, misalnya tiket, CMS, akun pengguna, AR, dan fungsi darurat. Lingkup ini sengaja dibuat sempit supaya delapan requirement inti bisa selesai dan teruji dalam lima sprint.

Selanjutnya, Dimas akan menunjukkan bagaimana produk ini dipakai.

---

## Slide 6 — Main Exploration Scenario
**Pembicara:** Michael Dimas · **Durasi:** ±1,5 menit

Terima kasih, Keane. Untuk menguji alur, kami memakai persona Rina, mahasiswi 21 tahun dari Jakarta yang pertama kali ke Tahura bersama dua temannya. Sinyal di dalam kawasan hilang-timbul.

Langkah berwarna hijau tua adalah alur wajib dari spesifikasi tugas. Rina memulai dengan memilih minat Sejarah dan Alam serta rute Santai. Ia menekan Mulai Jelajah, lalu memasukkan ponsel ke saku. Sekitar 50 meter sebelum Gua Jepang, ponselnya bergetar. Saat masuk radius 20 meter, muncul notifikasi dan suara: "Anda tiba di Gua Jepang. Ingin mendengar sejarahnya?" Ia menekan Dengarkan langsung dari layar kunci. Di dalam gua GPS melemah, jadi ia memindai QR.

Langkah berwarna hijau muda adalah nilai tambah kami. Aplikasi merekomendasikan Gua Belanda, 650 meter, sekitar 12 menit. Saat temannya butuh toilet, Rina mencari "toilet" lalu dinavigasi ke sana. Menjelang sore, ada pengingat jam tutup dan pengingat minum.

Hasilnya terlihat di bagian bawah: 6 dari 10 POI, 4.820 langkah, 3,1 kilometer, dan 2 jam 40 menit, ditambah daftar POI yang bisa dikunjungi lain kali.

Selanjutnya, Khalfani akan menjelaskan requirement-nya.

---

## Slide 7 — Product Requirements – Baseline (F01–F08)
**Pembicara:** Khalfani · **Durasi:** ±1,5 menit

Terima kasih, Dimas. Ini delapan requirement inti kami, F01 sampai F08, dan semuanya berprioritas Must.

Dari sisi QA, yang ingin kami tekankan adalah kolom acceptance criteria. Setiap kriteria punya angka yang bisa diukur. Contohnya F01: posisi pengguna harus tampil dalam 10 detik, dengan deviasi maksimal 15 meter pada 80 persen pengukuran. F02: notifikasi yang benar harus muncul dalam 10 detik pada minimal 8 dari 10 POI, dan tidak boleh memicu ulang. F06: selisih ETA dengan waktu tempuh aktual tidak boleh lebih dari 25 persen.

Setiap kriteria terhubung ke test case di kolom paling kanan, dari TC-01 sampai TC-12. Jadi, saat pengujian akhir di Week 14, compliance matrix bisa diisi secara objektif: lulus atau tidak lulus.

F08, Wellness Trail, adalah fitur inovasi khas domain kami. Di bagian bawah ada requirement tambahan: offline dan QR berprioritas Must, sisanya Should dan Could.

Berikutnya, Ballard akan menjelaskan mekanisme pemicunya.

---

## Slide 8 — Location-Trigger Logic
**Pembicara:** Michael Ballard · **Durasi:** ±1,5 menit

Terima kasih, Khalfani. Ini inti teknis produk kami, yaitu bagaimana aplikasi tahu bahwa pengguna sudah tiba di sebuah POI.

Setiap POI punya lima state. Awalnya Outside. Saat jaraknya kurang dari radius ditambah 30 meter, statusnya menjadi Approaching dan ponsel bergetar sekali. Status baru menjadi Triggered jika dua pembacaan GPS berturut-turut berada di dalam radius. Ini mencegah pemicu palsu akibat posisi GPS yang melompat. Setelah itu Visited, lalu Cooldown. POI baru bisa terpicu lagi setelah pengguna keluar sejauh radius ditambah 15 meter dan sudah lewat 10 menit. Pemindaian QR bisa langsung membawa POI ke Triggered.

Tabel di bawah berisi parameter awalnya. Semua angka ini akan dikalibrasi di lapangan, karena kanopi pohon dan lembah menurunkan akurasi GPS.

Di kanan ada tiga lapis pemicu: GPS sebagai yang utama, QR di gua atau saat GPS lemah, dan pilih manual sebagai cadangan terakhir. Jadi pengguna tidak pernah buntu. Geofence ini kami hitung sendiri di aplikasi, bukan memakai API sistem, supaya bisa dikendalikan dan diuji.

---

## Slide 9 — POI Definition – Zona Dago Pakar
**Pembicara:** Michael Ballard · **Durasi:** ±1 menit

Pemicu ini dipasang pada 10 POI inti: empat bertema sejarah; tiga bertema alam, flora, dan fauna; dua bertema wellness; dan satu titik masuk.

Ukuran lingkaran di setiap kartu sebanding dengan radius pemicunya, dan ini keputusan desain yang disengaja. Mulut gua memakai radius terkecil, 20 meter, ditambah QR karena GPS hilang di dalam gua. Area luas seperti hutan pinus dan area piknik memakai 40 meter supaya tidak terlewat.

Curug Omas bersifat opsional dan hanya muncul di rute Trekking. Selain itu ada lima titik fasilitas, yaitu toilet, musala, warung, pos petugas, dan tempat istirahat, yang bisa dicari dan dinavigasi, tetapi sengaja tidak memicu notifikasi agar tidak mengganggu.

Koordinat finalnya masih menunggu hasil survei lapangan.

---

## Slide 10 — Contextual Recommendation & Wellness Trail
**Pembicara:** Michael Ballard · **Durasi:** ±1,5 menit

Dua fitur berikut membuat kunjungan lebih luas dan lebih aman.

Di kiri, rekomendasi kontekstual bekerja dalam tiga langkah. Pertama, aplikasi menyaring POI yang belum dikunjungi dan masih sempat didatangi: waktu jalan ke POI, ditambah lama kunjungan, ditambah waktu jalan ke gerbang, harus kurang dari sisa waktu sampai jam tutup dikurangi 15 menit. Kedua, kandidat diurutkan dengan skor, dan kedekatan jarak punya bobot tertinggi. Ketiga, aplikasi menampilkan satu rekomendasi utama dan dua alternatif beserta alasannya. Kalau waktunya tidak cukup, aplikasi menyarankan kembali ke gerbang. Ini kami uji dengan simulasi waktu pukul 14.45 dan 15.30.

Di kanan, Wellness Trail menawarkan tiga rute: Santai, Sedang, dan Trekking. Selama sesi, aplikasi mencatat langkah, jarak, durasi, dan perkiraan kalori, serta mengingatkan minum setiap 45 menit. Semua data aktivitas hanya tersimpan di ponsel. Angka rute ini masih akan diverifikasi dengan rekaman GPS saat survei.

---

## Slide 11 — Low-Fidelity Prototype
**Pembicara:** Michael Dimas · **Durasi:** ±1 menit

Terima kasih, Ballard. Ini prototipe low-fidelity kami. Keenam layar ini mengikuti urutan kondisi yang diminta spesifikasi.

Satu, pengguna masih di luar area POI dan melihat peta serta statistik sesi. Dua, saat mendekat, muncul banner jarak dan getaran. Tiga, saat masuk radius, muncul notifikasi dengan pilihan Dengarkan, Lihat, atau Nanti; notifikasi ini juga tampil di layar kunci. Empat, halaman detail POI berisi foto, audio, fakta kunci, dan tips keselamatan. Lima, rekomendasi POI berikutnya. Dan enam, navigasi di jalur setapak dengan arahan suara.

Secara total kami merancang 15 layar, termasuk mode layar kunci, pemindai QR untuk gua, pengingat, dan ringkasan sesi. Versi high-fidelity-nya akan kami buat di Figma.

---

## Slide 12 — Product Backlog & Sprint Plan
**Pembicara:** Jacob · **Durasi:** ±1 menit

Terima kasih, Dimas. Untuk rencana kerja, kami membagi pengembangan menjadi lima sprint mingguan. Setiap sprint punya hasil dan bukti yang bisa diperiksa.

Sprint 1 membangun fondasi: peta offline dan posisi pengguna. Sprint 2 membangun logika pemicu dan halaman POI. Sprint 3, yang berwarna oranye, adalah titik kritis: seluruh alur inti dari Start sampai Navigation harus bisa didemokan end-to-end pada Major Progress Review di Week 12. Sprint 4 menyelesaikan rekomendasi dan Wellness Trail, lalu fitur dibekukan di akhir Week 13. Sprint 5 sepenuhnya untuk uji lapangan, usability testing dengan target skor SUS minimal 68, dan perbaikan.

Deliverable final dikumpulkan di Week 15: APK, testing report, compliance matrix, video maksimal 3 menit, dan AI disclosure.

---

## Slide 13 — Technical & AI-Assisted Development Plan
**Pembicara:** Michael Ballard · **Durasi:** ±1 menit

Terima kasih, Jacob. Dari sisi teknologi, kami mengusulkan Flutter dengan target Android, dalam arsitektur empat lapis.

Lapisan berwarna hijau, yaitu geofence, routing Dijkstra, dan mesin rekomendasi, kami bangun sendiri karena itulah inti produk yang harus bisa diuji dan kami jelaskan. Semua data disimpan di perangkat, jadi aplikasi berjalan sepenuhnya offline. Alasan kami tidak memakai Google Maps sederhana: Google Maps tidak memetakan jalan setapak Tahura dan tidak mendukung routing offline.

Di kanan adalah rencana penggunaan AI. Kami memakai AI di enam aktivitas, dari perencanaan sampai testing, dan setiap aktivitas punya cara verifikasinya. Contohnya, fakta sejarah tidak boleh hanya bersumber dari AI, dan kode yang dibantu AI harus lolos code review serta unit test. Prinsipnya, tim tetap bertanggung jawab memahami, menguji, dan mendemokan setiap fitur. Semua penggunaan AI dicatat oleh QA.

---

## Slide 14 — Risiko & Item Verifikasi
**Pembicara:** Khalfani · **Durasi:** ±1 menit

Terima kasih, Ballard. Kami sudah mengidentifikasi enam risiko utama, masing-masing dengan mitigasi dan penanggung jawab.

Risiko terbesar adalah akurasi GPS di bawah kanopi, di lembah, dan di dalam gua. Mitigasinya sudah dibahas tadi: konfirmasi dua pembacaan, kalibrasi radius di lapangan, serta QR dan pilihan manual. Risiko kedua adalah izin pemasangan QR dari pengelola; jika izin permanen belum ada, QR hanya dipasang sementara saat pengujian. Risiko lainnya adalah perbedaan data antar-sumber, lingkup yang terlalu luas, hak cipta foto dan narasi, serta konsumsi baterai.

Panel kanan berisi sembilan hal yang masih harus diverifikasi sebelum baseline dikunci, misalnya batas zona, koordinat POI, jam operasional, dan izin dari Dinas Kehutanan.

Untuk penutup, saya kembalikan ke Jacob.

---

## Slide 15 — Langkah Berikutnya
**Pembicara:** Jacob · **Durasi:** ±1 menit

Terima kasih, Khalfani. Sebagai penutup, ada tiga hal.

Pertama, keputusan yang kami minta hari ini: persetujuan baseline PRD versi 1.0, konfirmasi bahwa Tahura zona Dago Pakar diterima sebagai studi kasus Topik 7, dan konfirmasi bahwa QR boleh dipakai sebagai pemicu cadangan serta diuji tanpa pemasangan permanen.

Kedua, di sisa Week 9 kami akan mengonfirmasi data ke pengelola dan mengajukan izin survei.

Ketiga, Sprint 1 dimulai 26 Oktober dengan survei lapangan dan fondasi aplikasi.

Demikian presentasi dari Kelompok 5. Terima kasih, dan kami persilakan jika ada pertanyaan.

---

## Antisipasi Pertanyaan

**T: Mengapa geofence dihitung sendiri, bukan memakai geofencing API bawaan Android?** *(dijawab: Michael Ballard)*

Supaya radius, histeresis, dan konfirmasi dua pembacaan bisa kami atur, uji dengan unit test, dan kalibrasi di lapangan. Dengan API bawaan, perilaku itu tidak sepenuhnya bisa dikendalikan.

**T: Bagaimana jika GPS tidak akurat di dalam hutan?** *(dijawab: Michael Ballard)*

Pembacaan dengan akurasi lebih buruk dari 30 meter tidak dipakai untuk pemicu. Pemicu butuh dua pembacaan berturut-turut, radius dikalibrasi lewat uji lapangan, dan masih ada QR serta pilihan manual sebagai cadangan.

**T: Kenapa tidak memakai Google Maps?** *(dijawab: Michael Ballard)*

Google Maps tidak memetakan jalan setapak Tahura dan tidak mendukung routing offline. Karena itu graf jalur kami buat dari rekaman GPX survei dan rutenya dihitung dengan Dijkstra.

**T: Bagaimana pengelola memperbarui konten tanpa CMS?** *(dijawab: Keane)*

Semua data POI, rute, dan jam operasional ada di file JSON (requirement A05), sehingga mengubah konten tidak perlu mengubah kode. CMS sengaja kami keluarkan dari lingkup (NG04).

**T: Bagaimana memastikan konten sejarah akurat?** *(dijawab: Keane)*

Setiap fakta dirujuk ke pengelola, papan informasi, atau hasil survei, dan sumbernya dicatat. Tidak ada fakta yang hanya bersumber dari AI.

**T: Bagaimana requirement ini diuji?** *(dijawab: Khalfani)*

Setiap acceptance criteria terhubung ke test case TC-01 sampai TC-13. Pengujian lapangan dilakukan di Sprint 5, usability testing melibatkan minimal 5 responden dengan target SUS ≥68, dan hasilnya dicatat di compliance matrix.
