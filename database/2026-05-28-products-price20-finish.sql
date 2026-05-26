-- Tambahan kolom harga paket 20 hari (catering) jika belum ada dari migrasi sebelumnya

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS price_20_days DECIMAL(14,2) DEFAULT NULL AFTER harga;

-- Sinkronisasi catering_subscribers dari orders catering yang sudah aktif
INSERT INTO catering_subscribers (id, order_id, merchant_id, user_id, package_type, start_date, end_date, subscription_status, cancellation_requested_at, created_at, updated_at)
SELECT
  UUID(),
  o.id,
  o.merchant_id,
  o.user_id,
  CONCAT(COALESCE(o.subscription_days, 30), '_days'),
  o.subscription_start_date,
  o.subscription_end_date,
  COALESCE(o.subscription_status, 'active'),
  o.cancellation_requested_at,
  NOW(),
  NOW()
FROM orders o
WHERE o.service_type = 'catering'
  AND o.subscription_days IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM catering_subscribers cs WHERE cs.order_id = o.id
  );
