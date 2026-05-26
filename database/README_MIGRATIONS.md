# Menjalankan Migrasi Database

Pastikan MySQL/MariaDB berjalan dan database `projek_kos` sudah dibuat (lihat `README_DATABASE.md`).

## Otomatis (disarankan)

Dari root project:

```bash
php database/run_migrations.php
```

Script akan menjalankan berurutan:

1. `2026-05-25-sync-projek-mobile-schema.sql`
2. `2026-05-26-order-payment-subscription-address.sql`
3. `2026-05-27-payment-methods-catering-improvements.sql`
4. `2026-05-28-products-price20-finish.sql`

Lalu memanggil `merchantEnsureSchema()` untuk kolom dinamis di PHP.

## Manual

Import file SQL di atas ke phpMyAdmin atau:

```bash
mysql -u root projek_kos < database/2026-05-25-sync-projek-mobile-schema.sql
mysql -u root projek_kos < database/2026-05-26-order-payment-subscription-address.sql
mysql -u root projek_kos < database/2026-05-27-payment-methods-catering-improvements.sql
mysql -u root projek_kos < database/2026-05-28-products-price20-finish.sql
```

Sesuaikan kredensial di `backend/config/db.php` jika berbeda.
