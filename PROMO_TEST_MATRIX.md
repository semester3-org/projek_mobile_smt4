# Promo Test Matrix (MVP)

## Scope
- Merchant promo form validation
- Promo visibility di user product card / merchant detail
- Checkout auto apply promo terbaik
- Backend recalculation, quota, expiry, dan user usage

## Functional Cases
- Buat promo persentase valid (`20%`, `maks 25000`, `min 50000`) -> sukses.
- Buat promo nominal valid (`10000`) -> field maksimal diskon tidak wajib.
- Persentase > 100 -> ditolak.
- Tanggal akhir <= tanggal mulai -> ditolak.
- Kuota promo <= 0 -> ditolak.
- Promo untuk produk tidak valid -> ditolak.

## Merchant Flow Cases
- Promo baru aktif langsung -> notifikasi terkirim 1x.
- Edit promo aktif tanpa mengubah status aktif -> tidak broadcast ulang.
- Edit promo dari scheduled/paused menjadi active -> broadcast terkirim.
- Delete promo id tidak ditemukan -> respons 404.

## User Visibility Cases
- Product card dengan promo: tampil badge, harga coret, harga promo, hemat.
- Product card tanpa promo: tampil harga normal.
- Detail merchant: section `Promo Aktif` muncul jika ada promo valid.
- Promo kuota habis: promo tidak tampil di payload user.

## Checkout Business Cases
- 1 transaksi, banyak promo overlap -> auto pilih diskon terbesar valid.
- Jika diskon sama -> pilih promo yang berakhir lebih cepat.
- Promo dihitung dari subtotal setelah harga item final.
- Diskon tidak boleh melebihi subtotal (total minimum 0).
- Jika tidak ada promo eligible -> total = subtotal.

## Edge Cases
- Promo expired di tengah checkout -> backend recalculation, promo tidak dipakai.
- Kuota habis bersamaan (race) -> lock row, salah satu transaksi gagal apply promo.
- User sudah pakai promo sebelumnya -> promo tidak eligible untuk user itu.
- Promo active tapi minimum transaksi tidak terpenuhi -> promo tidak dipakai.
- Produk checkout tidak termasuk target promo -> promo tidak dipakai.

## Data Integrity Cases
- Order tersimpan dengan `subtotal_amount`, `promo_discount_amount`, `promo_id`, `promo_name`.
- Tabel `promo_usages` bertambah 1 row saat promo sukses dipakai.
- `merchant_promos.used_count` bertambah sinkron dengan usage.
- Saat promo gagal apply karena kuota habis saat lock, order tetap sukses tanpa promo.

## Regression Smoke
- Create order laundry (tanpa promo) tetap normal.
- Create order catering (dengan/ tanpa promo) normal.
- List order user dan merchant tetap dapat dibuka.
- Notification list tetap dapat dibuka.
