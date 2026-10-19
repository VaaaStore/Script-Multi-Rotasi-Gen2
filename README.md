# VaaaStore Multi Rotation Farm Bot (V5.2)

Script Lua untuk Growlauncher (Growtopia) yang menjalankan siklus farm pepper otomatis di beberapa world secara bergantian.

## Alur

Per world dikerjakan sampai tuntas, lalu pindah ke world berikutnya:

1. **Warp:** masuk world, menunggu world termuat, dan mengulang sampai 3 kali kalau gagal.
2. **Harvest:** memanen semua pohon matang dari kanan paling bawah (zigzag antar baris), dipindai ulang sampai bersih.
3. **PNB:** bot berdiri di `pnb_pos` dan memecah baris di atasnya. Block di lantai diambil lagi. Tahap selesai hanya jika block di tas dan di lantai sama-sama 0.
4. **Plant:** menanam tile kosong yang punya pijakan. Kalau seed di tas habis, bot mengambil seed dari lantai.

Setelah semua world farm selesai, bot ke world storage untuk menyetor seed dan World Lock, lalu mengulang dari world pertama. Seed sisa di world farm dibiarkan.

## Fitur Pendukung

- **Smart delay:** jeda acak 150-1000 ms. Saat aksi gagal diverifikasi (lag), delay otomatis ditambah lalu turun lagi saat lancar.
- **Verifikasi aksi:** harvest, place, break, dan plant dicek ulang lewat `getTile`.
- **Pengaman macet:** PNB berhenti dan world dilewati jika tidak ada kemajuan selama `pnb_max_idle` putaran.
- **Drop per tile:** item memenuhi satu tile sampai `tile_cap` (4.000), baru geser ke kanan (`x + 1`).
- **Auto buy WL:** thread terpisah, aktif saat gems mencapai `gem_threshold`.
- Error di satu world hanya dicatat di log dan bot lanjut ke world berikutnya.

## Instalasi

1. Salin file `.lua` ke folder `ScriptLua` Growlauncher:
   - GL v7.0.1+: `storage/emulated/0/Android/media/launcher.powerkuy.growlauncher/ScriptLua/`
   - Versi lama: lihat [dokumentasi Growlauncher](https://github.com/IniEyyy/Growlauncher-Documentation).
2. Jalankan script dari menu script di Growlauncher.

## Konfigurasi

Semua pengaturan ada di tabel `C` di bagian atas script.

| Pengaturan | Fungsi |
| --- | --- |
| `worlds_farm` | Daftar world farm |
| `world_storage`, `door_id` | World penyimpanan dan ID pintu |
| `block_id`, `seed_id`, `wl_id` | ID item block, seed, dan World Lock |
| `gem_threshold` | Batas gems untuk auto buy WL |
| `max_plant_seeds` | Batas tanam per world |
| `min_seed_keep`, `max_carry` | Seed yang disisakan di tas dan maksimal didrop per trip |
| `stack_cap` | Maksimal satu jenis item di tas (200) |
| `storage_seed`, `storage_wl` | Koordinat `{x, y}` drop di storage |
| `pnb_pos`, `pnb_offsets` | Posisi bot saat PNB dan tile yang dipecah (`x + offset, y - 1`) |
| `pnb_max_idle`, `max_hits` | Batas putaran PNB tanpa kemajuan dan pukulan per block |
| `plant_area` | Opsional: batasi area tanam `{x1, x2, y1, y2}` |
| `delay_min`, `delay_max`, `check_delay` | Rentang delay acak dan interval cek gems (ms) |
| `tile_cap`, `max_shift` | Batas item per tile dan jumlah geser ke kanan |

## Status Pengujian

- **Sudah terbukti di game:** warp dengan `NAMA|DOOR`, auto buy WL, collect (packet type 11), dan harvest.
- **Belum dites di game:** tahap PNB (`max_hits`, place di baris y=0), plant, verifikasi lag lewat `getTile`, satuan `obj.pos` (diasumsikan piksel), posisi jatuh item saat drop, dan alur lengkap antar tahap. Alur sudah diuji di simulasi saja.

## Saran Pemakaian

- Tes dulu di akun cadangan dengan satu world kecil, lalu cek log tiap tahap.
- Isi `plant_area` agar bot tidak menanam di area yang tidak diinginkan.
- Naikkan `gem_threshold` jika tidak ingin auto buy aktif saat tes.
- Gunakan dengan risiko sendiri. Penggunaan script dapat melanggar aturan game dan berisiko ban.
