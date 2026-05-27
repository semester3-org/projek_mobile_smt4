-- Jadwal pengantaran paket catering dan milestone pengantaran harian.

ALTER TABLE products
  ADD COLUMN meal_delivery_count TINYINT UNSIGNED NOT NULL DEFAULT 1,
  ADD COLUMN delivery_time_1 VARCHAR(5) DEFAULT '07:00',
  ADD COLUMN delivery_time_2 VARCHAR(5) DEFAULT NULL;

CREATE TABLE IF NOT EXISTS catering_delivery_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id BIGINT UNSIGNED NOT NULL,
  merchant_id VARCHAR(36) NOT NULL,
  user_id VARCHAR(36) NOT NULL,
  delivery_date DATE NOT NULL,
  slot_number TINYINT UNSIGNED NOT NULL,
  scheduled_time VARCHAR(5) NOT NULL,
  status ENUM('pending','delivered') NOT NULL DEFAULT 'pending',
  delivered_at DATETIME DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uniq_catering_delivery_slot (order_id, delivery_date, slot_number),
  KEY idx_catering_delivery_merchant_date (merchant_id, delivery_date),
  KEY idx_catering_delivery_order_date (order_id, delivery_date),
  KEY idx_catering_delivery_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
