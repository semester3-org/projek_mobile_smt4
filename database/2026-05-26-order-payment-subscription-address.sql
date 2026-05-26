-- Menyelaraskan flow order user/merchant untuk alamat map, Midtrans, dan langganan catering.

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS delivery_latitude DECIMAL(10,8) DEFAULT NULL AFTER delivery_address,
  ADD COLUMN IF NOT EXISTS delivery_longitude DECIMAL(11,8) DEFAULT NULL AFTER delivery_latitude,
  ADD COLUMN IF NOT EXISTS midtrans_order_id VARCHAR(50) DEFAULT NULL AFTER payment_status,
  ADD COLUMN IF NOT EXISTS paid_at DATETIME DEFAULT NULL AFTER midtrans_order_id,
  ADD COLUMN IF NOT EXISTS subscription_days INT DEFAULT NULL AFTER notes,
  ADD COLUMN IF NOT EXISTS subscription_start_date DATE DEFAULT NULL AFTER subscription_days,
  ADD COLUMN IF NOT EXISTS subscription_end_date DATE DEFAULT NULL AFTER subscription_start_date,
  ADD COLUMN IF NOT EXISTS subscription_status VARCHAR(30) DEFAULT NULL AFTER subscription_end_date,
  ADD COLUMN IF NOT EXISTS cancellation_requested_at DATETIME DEFAULT NULL AFTER subscription_status;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS latitude DECIMAL(10,8) DEFAULT NULL AFTER address,
  ADD COLUMN IF NOT EXISTS longitude DECIMAL(11,8) DEFAULT NULL AFTER latitude;
