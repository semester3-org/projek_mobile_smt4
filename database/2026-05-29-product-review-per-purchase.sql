-- Membatasi ulasan user per produk merchant dan mendukung edit/delete ulasan.

CREATE TABLE IF NOT EXISTS merchant_reviews (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  merchant_id VARCHAR(36) NOT NULL,
  user_id VARCHAR(36) NOT NULL,
  product_id BIGINT UNSIGNED DEFAULT NULL,
  rating TINYINT UNSIGNED NOT NULL,
  comment TEXT DEFAULT NULL,
  deleted_at TIMESTAMP NULL DEFAULT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE merchant_reviews
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP NULL DEFAULT NULL;

CREATE INDEX idx_merchant_reviews_product ON merchant_reviews (product_id);
CREATE INDEX idx_merchant_reviews_deleted ON merchant_reviews (deleted_at);
