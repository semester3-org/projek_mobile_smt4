# Database Setup Guide - projek_kos

## Daftar File SQL

### 1. **projek_kos_schema.sql**
File ini membuat struktur database lengkap dengan tabel-tabel:
- `users` - Data user (owner, tenant, admin, staff)
- `kos_listings` - Data kos (boarding house)
- `kos_images` - Gambar-gambar kos (relasi one-to-many)
- `facilities` - Master data fasilitas
- `kos_facilities` - Relasi many-to-many antara kos dan fasilitas
- `cafe_places` - Data kafe terdekat
- `laundry_places` - Data laundry terdekat

### 2. **projek_kos_dummy_data.sql**
File ini berisi data sampel/dummy untuk testing dan development:
- 6 user (3 owner, 2 tenant, 1 admin)
- 5 kos listing dengan gambar dan fasilitas
- 6 kafe sekitar
- 5 tempat laundry

### 3. **projek_kos_reset.sql**
File ini untuk menghapus database jika ingin reset total

---

## Cara Setup Database

### Step 1: Buka MySQL
```bash
mysql -u root -p
```

### Step 2: Buat Database dan Schema
Jalankan file schema:
```sql
source path/to/projek_kos_schema.sql;
```
Atau via command line:
```bash
mysql -u root -p projek_kos < projek_kos_schema.sql
```

### Step 3: Insert Dummy Data
Jalankan file dummy data:
```sql
source path/to/projek_kos_dummy_data.sql;
```
Atau via command line:
```bash
mysql -u root -p projek_kos < projek_kos_dummy_data.sql
```

### Step 4: Verifikasi
```sql
USE projek_kos;
SHOW TABLES;
SELECT * FROM users;
SELECT * FROM kos_listings;
```

---

## Struktur Data

### Users Table
| Field | Type | Keterangan |
|-------|------|-----------|
| id | VARCHAR(36) | Primary Key |
| email | VARCHAR(255) | Unique email |
| password | VARCHAR(255) | Password (hashed in production) |
| display_name | VARCHAR(255) | Nama tampilan |
| role | ENUM | owner, tenant, admin, staff |
| created_at | TIMESTAMP | Waktu dibuat |
| updated_at | TIMESTAMP | Waktu update terakhir |

### Kos Listings Table
| Field | Type | Keterangan |
|-------|------|-----------|
| id | VARCHAR(36) | Primary Key |
| owner_id | VARCHAR(36) | FK ke users |
| title | VARCHAR(255) | Nama kos |
| location | VARCHAR(255) | Lokasi kos |
| description | TEXT | Deskripsi |
| price_per_month | INT | Harga per bulan (Rp) |
| rating | DECIMAL(3,2) | Rating 0-5 |
| owner_contact | VARCHAR(20) | Nomor HP owner |

### Facilities Table
| Field | Type | Keterangan |
|-------|------|-----------|
| id | INT | Primary Key (Auto) |
| name | VARCHAR(100) | Nama fasilitas |

### Cafe Places Table
| Field | Type | Keterangan |
|-------|------|-----------|
| id | VARCHAR(36) | Primary Key |
| name | VARCHAR(255) | Nama kafe |
| vibe | VARCHAR(100) | Jenis suasana |
| rating | DECIMAL(3,2) | Rating 0-5 |
| image_url | TEXT | URL gambar |
| distance_km | DECIMAL(5,2) | Jarak dalam km |

### Laundry Places Table
| Field | Type | Keterangan |
|-------|------|-----------|
| id | VARCHAR(36) | Primary Key |
| name | VARCHAR(255) | Nama laundry |
| address | VARCHAR(255) | Alamat |
| rating | DECIMAL(3,2) | Rating 0-5 |
| distance_km | DECIMAL(5,2) | Jarak dalam km |
| image_url | TEXT | URL gambar |
| open_hours | VARCHAR(100) | Jam operasional |

---

## Query Contoh Berguna

### Cari kos berdasarkan owner
```sql
SELECT * FROM kos_listings WHERE owner_id = 'user_owner_1';
```

### Cari kos dengan harga tertentu
```sql
SELECT * FROM kos_listings 
WHERE price_per_month BETWEEN 800000 AND 1500000
ORDER BY rating DESC;
```

### Lihat fasilitas kos tertentu
```sql
SELECT k.title, f.name 
FROM kos_listings k
JOIN kos_facilities kf ON k.id = kf.kos_id
JOIN facilities f ON kf.facility_id = f.id
WHERE k.id = 'k1';
```

### Lihat gambar kos
```sql
SELECT kos_id, image_url FROM kos_images 
WHERE kos_id = 'k1'
ORDER BY display_order;
```

### Top rated kos
```sql
SELECT id, title, price_per_month, rating 
FROM kos_listings 
ORDER BY rating DESC 
LIMIT 10;
```

### Top rated cafe/laundry
```sql
SELECT name, rating, distance_km FROM cafe_places ORDER BY rating DESC;
SELECT name, rating, distance_km FROM laundry_places ORDER BY rating DESC;
```

---

## Reset Database

Jika ingin menghapus semua data dan mulai dari awal:

```bash
mysql -u root -p projek_kos < projek_kos_reset.sql
mysql -u root -p projek_kos < projek_kos_schema.sql
mysql -u root -p projek_kos < projek_kos_dummy_data.sql
```

---

## Notes

1. Gunakan UUID atau custom ID untuk production
2. Password harus di-hash dengan bcrypt/scrypt sebelum disimpan
3. Untuk production, gunakan database connection pooling
4. Tambahkan index sesuai kebutuhan search/filter
5. Backup database secara berkala

---

**Created for:** Semester 4 Project - KosFinder Mobile App  
**Last Updated:** 2026-04-19
