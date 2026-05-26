-- Migration untuk standardisasi payment methods dan fitur catering improvements
-- File: 2026-05-27-payment-methods-catering-improvements.sql

-- 1. Standardize payment method values dalam payment_history
UPDATE payment_history
SET payment_method = 'bank_transfer'
WHERE payment_method IN ('transfer', 'bank', 'Bank Transfer');

UPDATE payment_history
SET payment_method = 'gopay'
WHERE payment_method IN ('GoPay', 'gopay_qris', 'GoPay/QRIS');

UPDATE payment_history
SET payment_method = 'shopeepay'
WHERE payment_method IN ('ShopeePay', 'shopee_pay');

UPDATE payment_history
SET payment_method = 'cod'
WHERE payment_method IN ('cash', 'COD', 'Cash on Delivery', 'cash_on_delivery');

-- 2. Standardize payment method values dalam orders
UPDATE orders
SET payment_method = 'bank_transfer'
WHERE payment_method IN ('transfer', 'bank', 'Bank Transfer', 'Transfer Bank');

UPDATE orders
SET payment_method = 'gopay'
WHERE payment_method IN ('GoPay', 'gopay_qris', 'GoPay/QRIS');

UPDATE orders
SET payment_method = 'shopeepay'
WHERE payment_method IN ('ShopeePay', 'shopee_pay', 'ShopeePay');

UPDATE orders
SET payment_method = 'cod'
WHERE payment_method IN ('cash', 'COD', 'Cash on Delivery', 'Cash on Delivery');

-- 3. Add table untuk catering package categories (paket referensi)
CREATE TABLE IF NOT EXISTS catering_package_categories (
  id VARCHAR(36) PRIMARY KEY COMMENT 'UUID',
  merchant_id VARCHAR(36) NOT NULL COMMENT 'ID merchant',
  category_name VARCHAR(100) NOT NULL COMMENT 'Nama kategori paket (e.g., Paket Hemat, Paket Premium)',
  description TEXT COMMENT 'Deskripsi singkat',
  is_active TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE,
  UNIQUE KEY unique_merchant_category (merchant_id, category_name),
  INDEX idx_merchant_active (merchant_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Add catering_subscribers table untuk tracking subscribers
CREATE TABLE IF NOT EXISTS catering_subscribers (
  id VARCHAR(36) PRIMARY KEY COMMENT 'UUID',
  order_id INT NOT NULL UNIQUE COMMENT 'Link ke orders table',
  merchant_id VARCHAR(36) NOT NULL COMMENT 'ID merchant',
  user_id VARCHAR(36) NOT NULL COMMENT 'ID user penyewa',
  package_type VARCHAR(50) COMMENT 'Jenis paket (20_days, 30_days)',
  start_date DATE COMMENT 'Tanggal mulai langganan',
  end_date DATE COMMENT 'Tanggal akhir langganan',
  subscription_status VARCHAR(30) COMMENT 'active, expired, cancelled_requested',
  cancellation_requested_at DATETIME COMMENT 'Waktu user request pembatalan',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_merchant_active (merchant_id, subscription_status),
  INDEX idx_user_active (user_id, subscription_status),
  INDEX idx_end_date (end_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Add operating_hours untuk merchant (jam operasional real-time)
CREATE TABLE IF NOT EXISTS merchant_operating_hours (
  id VARCHAR(36) PRIMARY KEY COMMENT 'UUID',
  merchant_id VARCHAR(36) NOT NULL,
  day_of_week INT COMMENT '0=Sunday, 1=Monday, ..., 6=Saturday',
  opening_time TIME COMMENT 'Jam buka (HH:MM:SS)',
  closing_time TIME COMMENT 'Jam tutup (HH:MM:SS)',
  is_open TINYINT(1) DEFAULT 1 COMMENT '1=terbuka, 0=tutup',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE,
  UNIQUE KEY unique_merchant_day (merchant_id, day_of_week)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. Add laundry_service_estimates untuk estimasi waktu layanan
CREATE TABLE IF NOT EXISTS laundry_service_estimates (
  id VARCHAR(36) PRIMARY KEY COMMENT 'UUID',
  merchant_id VARCHAR(36) NOT NULL,
  service_name VARCHAR(100) COMMENT 'e.g., Express 1-2 jam, Regular 1-2 hari',
  min_hours INT COMMENT 'Estimasi minimum jam',
  max_hours INT COMMENT 'Estimasi maksimum jam',
  is_active TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE,
  INDEX idx_merchant_active (merchant_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. Modify products table - remove unit dari catering, adjust satuan untuk laundry only
ALTER TABLE products
ADD COLUMN IF NOT EXISTS laundry_estimate_id VARCHAR(36) COMMENT 'Link ke laundry_service_estimates',
ADD COLUMN IF NOT EXISTS catering_package_category_id VARCHAR(36) COMMENT 'Link ke catering_package_categories';

-- 8. Modify orders table untuk pembatalan window
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS cancellation_window_until DATETIME COMMENT 'Waktu deadline pembatalan (5 detik dari created_at)';

-- Update existing orders - set cancellation window to 5 seconds after creation
UPDATE orders
SET cancellation_window_until = DATE_ADD(created_at, INTERVAL 5 SECOND)
WHERE cancellation_window_until IS NULL AND created_at IS NOT NULL;

-- 9. Add table untuk transaction receipts (bukti pembayaran)
CREATE TABLE IF NOT EXISTS transaction_receipts (
  id VARCHAR(36) PRIMARY KEY COMMENT 'UUID',
  order_id INT COMMENT 'Link ke orders',
  billing_id VARCHAR(36) COMMENT 'Link ke payment_history',
  receipt_url VARCHAR(500) COMMENT 'URL receipt PDF atau gambar',
  receipt_type VARCHAR(20) COMMENT 'pdf, image',
  generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  INDEX idx_order (order_id),
  UNIQUE KEY unique_order_receipt (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
