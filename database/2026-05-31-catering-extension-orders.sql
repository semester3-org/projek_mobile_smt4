-- Perpanjangan catering diperlakukan sebagai pengajuan order baru.
-- Durasi langganan utama baru bertambah setelah pengajuan disetujui dan dibayar.

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS extension_parent_order_id BIGINT UNSIGNED DEFAULT NULL AFTER cancellation_requested_at,
  ADD COLUMN IF NOT EXISTS extension_days INT DEFAULT NULL AFTER extension_parent_order_id;

CREATE INDEX IF NOT EXISTS idx_orders_extension_parent
  ON orders (extension_parent_order_id);
