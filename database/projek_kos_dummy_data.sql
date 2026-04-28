-- ============================================================
-- DATA DUMMY: projek_kos
-- ============================================================
-- Note: Run projek_kos_schema.sql FIRST before running this file

USE projek_kos;

-- ============================================================
-- INSERT: users
-- ============================================================
-- Password disimpan sebagai hash menggunakan SHA2(256) untuk dummy database.
INSERT INTO users (id, email, password, display_name, role) VALUES
('user_owner_1', 'owner1@gmail.com', SHA2('password123', 256), 'Budi Santoso', 'owner'),
('user_owner_2', 'owner2@gmail.com', SHA2('password123', 256), 'Siti Nurhaliza', 'owner'),
('user_owner_3', 'owner3@gmail.com', SHA2('password123', 256), 'Rini Wijaya', 'owner'),
('user_merchant_1', 'merchant1@gmail.com', SHA2('password123', 256), 'Dian Permata', 'merchant'),
('user_user_1', 'user1@gmail.com', SHA2('password123', 256), 'Andi Prasetyo', 'user'),
('user_admin', 'admin@gmail.com', SHA2('admin123', 256), 'Admin KosFinder', 'admin');

-- ============================================================
-- INSERT: facilities (Master data)
-- ============================================================
INSERT INTO facilities (name) VALUES
('WiFi'),
('AC'),
('Kamar mandi dalam'),
('Dapur bersama'),
('Parkir motor'),
('Laundry'),
('Keamanan 24 jam'),
('Kulkas bersama'),
('Teras rokok'),
('Gazebo');

-- ============================================================
-- INSERT: kos_listings
-- ============================================================
INSERT INTO kos_listings (id, owner_id, title, location, description, price_per_month, rating, owner_contact) VALUES
('k1', 'user_owner_1', 'Kos Hijau Asri', 'Jl. Melati No. 12, Sleman', 'Kos nyaman dengan taman kecil di depan. Cocok untuk mahasiswa dan pekerja. Lingkungan tenang.', 1200000, 4.80, '0812-3456-7890'),
('k2', 'user_owner_2', 'Kost Minimalis Putih', 'Jl. Kenanga 5, Depok', 'Desain minimalis, bersih, dekat kampus dan angkot.', 950000, 4.50, '0813-9999-0001'),
('k3', 'user_owner_3', 'Green House Residence', 'Jl. Merpati 88, Condongcatur', 'Fasilitas lengkap, akses kartu, area joging dekat kos.', 1500000, 4.90, '0821-1111-2222'),
('k4', 'user_owner_1', 'Kos Nyaman Dian', 'Jl. Cendana 45, Yogyakarta', 'Kos yang sangat nyaman dengan lokasi strategis dekat dengan berbagai tempat umum.', 850000, 4.60, '0812-3456-7890'),
('k5', 'user_owner_2', 'Rumah Kost Makmur', 'Jl. Sudirman 23, Jakarta', 'Rumah kost dengan fasilitas modern dan lokasi premium.', 2000000, 4.70, '0813-9999-0001');

-- ============================================================
-- INSERT: kos_images
-- ============================================================
INSERT INTO kos_images (kos_id, image_url, display_order) VALUES
('k1', 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800', 1),
('k1', 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800', 2),
('k1', 'https://images.unsplash.com/photo-1584622650111-993a426fbf80?w=800', 3),
('k2', 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800', 1),
('k2', 'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800', 2),
('k3', 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800', 1),
('k3', 'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=800', 2),
('k4', 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800', 1),
('k4', 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800', 2),
('k5', 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800', 1),
('k5', 'https://images.unsplash.com/photo-1584622650111-993a426fbf80?w=800', 2);

-- ============================================================
-- INSERT: kos_facilities (Map facilities to kos)
-- ============================================================
INSERT INTO kos_facilities (kos_id, facility_id) VALUES
-- Kos Hijau Asri (k1) - WiFi, AC, Kamar mandi dalam, Parkir motor
('k1', 1), ('k1', 2), ('k1', 3), ('k1', 5),
-- Kost Minimalis Putih (k2) - WiFi, Kamar mandi dalam, Dapur bersama
('k2', 1), ('k2', 3), ('k2', 4),
-- Green House Residence (k3) - WiFi, AC, Kamar mandi dalam, Keamanan 24 jam, Laundry
('k3', 1), ('k3', 2), ('k3', 3), ('k3', 7), ('k3', 6),
-- Kos Nyaman Dian (k4) - WiFi, AC, Kamar mandi dalam, Parkir motor, Laundry
('k4', 1), ('k4', 2), ('k4', 3), ('k4', 5), ('k4', 6),
-- Rumah Kost Makmur (k5) - WiFi, AC, Kamar mandi dalam, Keamanan 24 jam, Laundry, Kulkas bersama
('k5', 1), ('k5', 2), ('k5', 3), ('k5', 7), ('k5', 6), ('k5', 8);

-- ============================================================
-- INSERT: cafe_places
-- ============================================================
INSERT INTO cafe_places (id, name, vibe, rating, image_url, distance_km) VALUES
('c1', 'Kopi Kenangan', 'Modern Casual', 4.8, 'https://images.unsplash.com/photo-15210174322fbe91904029cad6cbee1ab2409b1d?w=800', 0.3),
('c2', 'Warung Kopi Lesehan', 'Traditional', 4.5, 'https://images.unsplash.com/photo-1570968915860-54d8d3532ca0?w=800', 0.8),
('c3', 'Kedai Kopi Artisan', 'Minimalist', 4.9, 'https://images.unsplash.com/photo-1511537190424-3c373c0fbead?w=800', 0.5),
('c4', 'Café Bintang 5', 'Luxury', 4.7, 'https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=800', 1.2),
('c5', 'Teras Kopi Rumahan', 'Cozy', 4.6, 'https://images.unsplash.com/photo-1442512595331-e89e73853f31?w=800', 0.6),
('c6', 'Espresso House', 'Contemporary', 4.8, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800', 0.9);

-- ============================================================
-- INSERT: laundry_places
-- ============================================================
INSERT INTO laundry_places (id, name, address, rating, distance_km, image_url, open_hours) VALUES
('l1', 'Laundry Fresh Express', 'Jl. Kaliurang Km 5', 4.7, 0.4, 'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?w=800', '08:00 – 20:00'),
('l2', 'Cuci Kilat Jaya', 'Jl. Gejayan No. 22', 4.4, 0.9, 'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=800', '07:00 – 21:00'),
('l3', 'Bersih Laundry', 'Jl. Magelang 101', 4.6, 1.2, 'https://images.unsplash.com/photo-1626806819282-2c1dc01a5e0c?w=800', '07:00 – 22:00'),
('l4', 'Laundry Cepat Saja', 'Jl. Affandi No. 55', 4.5, 0.7, 'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?w=800', '08:00 – 20:30'),
('l5', 'Express Wash Laundry', 'Jl. Diponegoro 12', 4.8, 1.0, 'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=800', '06:00 – 21:00');

-- ============================================================
-- End of Dummy Data Insert
-- ============================================================
