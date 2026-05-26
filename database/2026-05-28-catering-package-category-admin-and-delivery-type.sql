-- Menyiapkan kategori paket catering global untuk dikelola admin nantinya
-- dan pilihan jenis pengiriman paket catering.

ALTER TABLE catering_package_categories
  MODIFY merchant_id VARCHAR(36) NULL,
  ADD COLUMN IF NOT EXISTS created_by VARCHAR(36) NULL,
  ADD COLUMN IF NOT EXISTS scope ENUM('global','merchant') DEFAULT 'merchant';

INSERT IGNORE INTO catering_package_categories
  (id, merchant_id, created_by, scope, category_name, description, is_active, created_at, updated_at)
VALUES
  ('catpkg-hemat', NULL, NULL, 'global', 'Paket Hemat', 'Kategori paket standar dengan menu harian terjangkau.', 1, NOW(), NOW()),
  ('catpkg-premium', NULL, NULL, 'global', 'Paket Premium', 'Kategori paket dengan variasi lauk lebih lengkap.', 1, NOW(), NOW()),
  ('catpkg-diet', NULL, NULL, 'global', 'Paket Diet Sehat', 'Kategori paket rendah kalori dan tinggi protein.', 1, NOW(), NOW());

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS package_delivery_type ENUM('full_day','weekday') DEFAULT NULL;

ALTER TABLE catering_package_categories
  ADD CONSTRAINT fk_catering_package_categories_merchant
  FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE SET NULL;

ALTER TABLE catering_package_categories
  ADD CONSTRAINT fk_catering_package_categories_created_by
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;
