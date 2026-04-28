-- ============================================================
-- QUERY EXAMPLES: projek_kos
-- ============================================================
-- File ini berisi contoh-contoh query yang berguna

USE projek_kos;

-- ============================================================
-- 1. QUERY: USER / AUTH
-- ============================================================

-- Login user
SELECT id, email, display_name, role FROM users 
WHERE email = 'tenant1@gmail.com' AND password = 'password123';

-- Get user by ID
SELECT * FROM users WHERE id = 'user_owner_1';

-- Get all owners
SELECT id, email, display_name FROM users WHERE role = 'owner';

-- Get all tenants
SELECT id, email, display_name FROM users WHERE role = 'tenant';

-- ============================================================
-- 1a. QUERY: PASSWORD RESET
-- ============================================================

-- Create password reset token
INSERT INTO password_resets (email, token, expires_at)
VALUES ('user@example.com', 'abc123token', DATE_ADD(NOW(), INTERVAL 1 HOUR));

-- Check if token is valid and not expired
SELECT * FROM password_resets 
WHERE email = 'user@example.com' 
AND token = 'abc123token' 
AND used_at IS NULL 
AND expires_at > NOW();

-- Mark token as used
UPDATE password_resets 
SET used_at = NOW() 
WHERE email = 'user@example.com' AND token = 'abc123token';

-- Update user password
UPDATE users 
SET password = 'newhashedpassword' 
WHERE email = 'user@example.com';

-- Clean up expired tokens (can be run periodically)
DELETE FROM password_resets WHERE expires_at < NOW();

-- ============================================================
-- 2. QUERY: KOS LISTINGS
-- ============================================================

-- Get all kos with rating
SELECT id, title, location, price_per_month, rating 
FROM kos_listings 
ORDER BY rating DESC;

-- Get kos by specific owner
SELECT * FROM kos_listings 
WHERE owner_id = 'user_owner_1'
ORDER BY created_at DESC;

-- Get kos by price range
SELECT id, title, location, price_per_month, rating 
FROM kos_listings 
WHERE price_per_month BETWEEN 800000 AND 1500000
ORDER BY rating DESC;

-- Get kos by location (search)
SELECT id, title, location, price_per_month, rating 
FROM kos_listings 
WHERE location LIKE '%Yogyakarta%' OR location LIKE '%Sleman%'
ORDER BY rating DESC;

-- Get top 5 rated kos
SELECT id, title, location, price_per_month, rating 
FROM kos_listings 
ORDER BY rating DESC 
LIMIT 5;

-- Get kos with count of facilities
SELECT k.id, k.title, k.location, k.price_per_month, k.rating,
       COUNT(kf.facility_id) as facility_count
FROM kos_listings k
LEFT JOIN kos_facilities kf ON k.id = kf.kos_id
GROUP BY k.id
ORDER BY k.rating DESC;

-- ============================================================
-- 3. QUERY: KOS IMAGES
-- ============================================================

-- Get all images for specific kos
SELECT id, kos_id, image_url, display_order 
FROM kos_images 
WHERE kos_id = 'k1'
ORDER BY display_order;

-- Get first image of each kos
SELECT DISTINCT ON (kos_id) kos_id, image_url
FROM kos_images
ORDER BY kos_id, display_order;

-- Get kos with their first image
SELECT k.id, k.title, k.price_per_month, k.rating,
       MAX(CASE WHEN ki.display_order = 1 THEN ki.image_url END) as featured_image
FROM kos_listings k
LEFT JOIN kos_images ki ON k.id = ki.kos_id
GROUP BY k.id
ORDER BY k.rating DESC;

-- ============================================================
-- 4. QUERY: FACILITIES
-- ============================================================

-- Get all facilities
SELECT id, name FROM facilities ORDER BY name;

-- Get facilities for specific kos
SELECT f.id, f.name 
FROM facilities f
JOIN kos_facilities kf ON f.id = kf.facility_id
WHERE kf.kos_id = 'k1'
ORDER BY f.name;

-- Get kos that have specific facility
SELECT DISTINCT k.id, k.title, k.location, k.price_per_month
FROM kos_listings k
JOIN kos_facilities kf ON k.id = kf.kos_id
JOIN facilities f ON kf.facility_id = f.id
WHERE f.name = 'WiFi'
ORDER BY k.rating DESC;

-- Get kos with all their facilities
SELECT k.id, k.title, k.price_per_month, k.rating,
       GROUP_CONCAT(f.name SEPARATOR ', ') as facilities
FROM kos_listings k
LEFT JOIN kos_facilities kf ON k.id = kf.kos_id
LEFT JOIN facilities f ON kf.facility_id = f.id
GROUP BY k.id
ORDER BY k.rating DESC;

-- ============================================================
-- 5. QUERY: CAFE PLACES
-- ============================================================

-- Get all cafes
SELECT id, name, vibe, rating, distance_km 
FROM cafe_places 
ORDER BY rating DESC;

-- Get cafes by vibe
SELECT id, name, rating, distance_km 
FROM cafe_places 
WHERE vibe = 'Modern Casual'
ORDER BY rating DESC;

-- Get closest cafes
SELECT id, name, vibe, rating, distance_km 
FROM cafe_places 
ORDER BY distance_km ASC 
LIMIT 5;

-- Get top rated cafes
SELECT id, name, vibe, rating, distance_km 
FROM cafe_places 
ORDER BY rating DESC 
LIMIT 5;

-- ============================================================
-- 6. QUERY: LAUNDRY PLACES
-- ============================================================

-- Get all laundries
SELECT id, name, address, rating, distance_km, open_hours 
FROM laundry_places 
ORDER BY rating DESC;

-- Get laundries sorted by distance
SELECT id, name, address, rating, distance_km 
FROM laundry_places 
ORDER BY distance_km ASC;

-- Get laundries sorted by rating
SELECT id, name, address, rating, open_hours 
FROM laundry_places 
ORDER BY rating DESC;

-- Get laundries open now (example: 10:00)
-- Catatan: Perlu logika lebih kompleks untuk parsing jam operasional
SELECT * FROM laundry_places WHERE open_hours LIKE '06:00%';

-- ============================================================
-- 7. QUERY: DASHBOARD OWNER
-- ============================================================

-- Get owner's kos listing count
SELECT COUNT(*) as total_listings
FROM kos_listings 
WHERE owner_id = 'user_owner_1';

-- Get owner's kos with average rating
SELECT owner_id, 
       COUNT(*) as total_listings,
       AVG(price_per_month) as avg_price,
       AVG(rating) as avg_rating,
       MIN(created_at) as first_listing_date
FROM kos_listings 
GROUP BY owner_id;

-- Get specific owner's kos with full info
SELECT k.id, k.title, k.location, k.price_per_month, k.rating,
       COUNT(DISTINCT ki.id) as image_count,
       COUNT(DISTINCT kf.facility_id) as facility_count
FROM kos_listings k
LEFT JOIN kos_images ki ON k.id = ki.kos_id
LEFT JOIN kos_facilities kf ON k.id = kf.kos_id
WHERE k.owner_id = 'user_owner_1'
GROUP BY k.id
ORDER BY k.created_at DESC;

-- ============================================================
-- 8. QUERY: STATISTICS
-- ============================================================

-- Total kos, coffee, laundry count
SELECT 
  'Kos Listings' as type, COUNT(*) as total FROM kos_listings
UNION ALL
SELECT 'Cafe Places', COUNT(*) FROM cafe_places
UNION ALL
SELECT 'Laundry Places', COUNT(*) FROM laundry_places;

-- Average price per month
SELECT AVG(price_per_month) as avg_price,
       MIN(price_per_month) as min_price,
       MAX(price_per_month) as max_price
FROM kos_listings;

-- Average rating
SELECT 'Kos' as type, AVG(rating) as avg_rating FROM kos_listings
UNION ALL
SELECT 'Cafe', AVG(rating) FROM cafe_places
UNION ALL
SELECT 'Laundry', AVG(rating) FROM laundry_places;

-- Most listed facilities
SELECT f.name, COUNT(kf.facility_id) as count
FROM facilities f
LEFT JOIN kos_facilities kf ON f.id = kf.facility_id
GROUP BY f.id
ORDER BY count DESC;

-- ============================================================
-- 9. QUERY: SEARCH / FILTER
-- ============================================================

-- Search kos by title or location (full-text search)
SELECT id, title, location, price_per_month, rating 
FROM kos_listings 
WHERE MATCH(title, description) AGAINST('minimalis' IN BOOLEAN MODE)
   OR MATCH(location) AGAINST('jakarta' IN BOOLEAN MODE)
ORDER BY rating DESC;

-- Search with multiple filters
SELECT k.id, k.title, k.location, k.price_per_month, k.rating
FROM kos_listings k
WHERE k.price_per_month <= 1500000
  AND TYPE = 'Parkir motor' IN (
    SELECT f.name FROM kos_facilities kf
    JOIN facilities f ON kf.facility_id = f.id
    WHERE kf.kos_id = k.id
  )
ORDER BY k.rating DESC;

-- ============================================================
-- 10. QUERY: DATA MAINTENANCE
-- ============================================================

-- Count records by table
SELECT 'users' as table_name, COUNT(*) as count FROM users
UNION ALL
SELECT 'kos_listings', COUNT(*) FROM kos_listings
UNION ALL
SELECT 'kos_images', COUNT(*) FROM kos_images
UNION ALL
SELECT 'facilities', COUNT(*) FROM facilities
UNION ALL
SELECT 'cafe_places', COUNT(*) FROM cafe_places
UNION ALL
SELECT 'laundry_places', COUNT(*) FROM laundry_places;

-- Check data integrity
SELECT * FROM kos_listings WHERE owner_id NOT IN (SELECT id FROM users WHERE role = 'owner');

-- Check orphaned images
SELECT * FROM kos_images WHERE kos_id NOT IN (SELECT id FROM kos_listings);

-- Check orphaned facilities
SELECT * FROM kos_facilities WHERE 
  kos_id NOT IN (SELECT id FROM kos_listings) OR
  facility_id NOT IN (SELECT id FROM facilities);

-- ============================================================
-- End of Query Examples
-- ============================================================
