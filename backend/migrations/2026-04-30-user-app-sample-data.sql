-- Sample data for the user-facing Sentra Ruang interface.
-- Safe to run after database/projek_kos (fix).sql has been imported.

INSERT IGNORE INTO catering_places
  (id, name, address, specialty, rating, distance_km, image_url, min_order_portion, merchant_id)
VALUES
  (
    'cat1',
    'Green Garden Catering',
    'Jl. Kemang Raya No. 9, Jakarta Selatan',
    'Masakan Sehat & Diet Kalori',
    4.80,
    1.20,
    'https://images.unsplash.com/photo-1543353071-873f17a7a088?w=900',
    1,
    NULL
  ),
  (
    'cat2',
    'Dapur Nusantara',
    'Jl. Panglima Polim No. 11, Jakarta Selatan',
    'Masakan Tradisional Indonesia',
    4.90,
    2.50,
    'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=900',
    1,
    NULL
  ),
  (
    'cat3',
    'Healthy Bites',
    'Jl. Cendana No. 16, Jakarta Selatan',
    'Salad & Vegan Friendly',
    4.60,
    0.80,
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=900',
    1,
    NULL
  );

INSERT IGNORE INTO room_registrations
  (id, user_id, room_id, kos_id, status, start_date, end_date, notes, reviewed_by, reviewed_at, registered_at, updated_at)
SELECT
  'reg-user-1-204',
  'user_user_1',
  '9455bdec-b0d5-4d0c-9d76-0d197b8db240',
  '254952fa-366a-417f-bbf7-43126254772c',
  'active',
  '2024-01-01',
  NULL,
  'Sample active registration for user app billing',
  NULL,
  NULL,
  NOW(),
  NOW()
WHERE EXISTS (SELECT 1 FROM users WHERE id = 'user_user_1')
  AND EXISTS (SELECT 1 FROM kos_rooms WHERE id = '9455bdec-b0d5-4d0c-9d76-0d197b8db240')
  AND EXISTS (SELECT 1 FROM kos_listings WHERE id = '254952fa-366a-417f-bbf7-43126254772c');

INSERT IGNORE INTO payment_history
  (registration_id, amount, period_month, payment_status, payment_method, proof_url, paid_at, created_at)
SELECT 'reg-user-1-204', 2450000, '2024-06', 'unpaid', NULL, NULL, NULL, NOW()
WHERE EXISTS (SELECT 1 FROM room_registrations WHERE id = 'reg-user-1-204');

INSERT IGNORE INTO payment_history
  (registration_id, amount, period_month, payment_status, payment_method, proof_url, paid_at, created_at)
SELECT 'reg-user-1-204', 2450000, '2024-05', 'paid', 'Transfer Bank', NULL, '2024-05-02 09:00:00', NOW()
WHERE EXISTS (SELECT 1 FROM room_registrations WHERE id = 'reg-user-1-204');

INSERT IGNORE INTO payment_history
  (registration_id, amount, period_month, payment_status, payment_method, proof_url, paid_at, created_at)
SELECT 'reg-user-1-204', 2450000, '2024-04', 'paid', 'Transfer Bank', NULL, '2024-04-03 10:00:00', NOW()
WHERE EXISTS (SELECT 1 FROM room_registrations WHERE id = 'reg-user-1-204');
