-- Migration: role relations + room facilities + dynamic merchant types
-- Target DB: projek_kos (MySQL 8+)

START TRANSACTION;

-- 1) Merchant types master (managed by admin, not enum)
CREATE TABLE IF NOT EXISTS merchant_types (
  id INT NOT NULL AUTO_INCREMENT,
  code VARCHAR(50) NOT NULL,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(255) DEFAULT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by VARCHAR(36) DEFAULT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uniq_merchant_type_code (code),
  UNIQUE KEY uniq_merchant_type_name (name),
  KEY idx_merchant_types_created_by (created_by),
  CONSTRAINT fk_merchant_types_created_by
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO merchant_types (code, name, description, is_active)
VALUES
  ('cafe', 'Cafe', 'Merchant kafe', 1),
  ('laundry', 'Laundry', 'Merchant laundry', 1),
  ('mixed', 'Mixed', 'Merchant dengan lebih dari satu layanan', 1)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  description = VALUES(description),
  is_active = VALUES(is_active);

-- 2) Merchant profile table (1 user merchant = 1 profile)
CREATE TABLE IF NOT EXISTS merchants (
  id VARCHAR(36) NOT NULL,
  user_id VARCHAR(36) NOT NULL,
  business_name VARCHAR(255) NOT NULL,
  merchant_type_id INT DEFAULT NULL,
  phone VARCHAR(25) DEFAULT NULL,
  address VARCHAR(255) DEFAULT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uniq_merchants_user_id (user_id),
  KEY idx_merchants_type_id (merchant_type_id),
  CONSTRAINT fk_merchants_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_merchants_type FOREIGN KEY (merchant_type_id) REFERENCES merchant_types(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Compatibility for schema that already has enum merchant_type
ALTER TABLE merchants
  ADD COLUMN IF NOT EXISTS merchant_type_id INT DEFAULT NULL,
  ADD INDEX IF NOT EXISTS idx_merchants_type_id (merchant_type_id);

UPDATE merchants m
JOIN merchant_types mt
  ON mt.code = LOWER(TRIM(m.merchant_type))
SET m.merchant_type_id = mt.id
WHERE m.merchant_type_id IS NULL
  AND m.merchant_type IS NOT NULL;

UPDATE merchants
SET merchant_type_id = (
  SELECT id FROM merchant_types WHERE code = 'mixed' LIMIT 1
)
WHERE merchant_type_id IS NULL;

ALTER TABLE merchants
  ADD CONSTRAINT fk_merchants_type
  FOREIGN KEY (merchant_type_id) REFERENCES merchant_types(id)
  ON DELETE SET NULL;

-- 3) Link cafe_places and laundry_places to merchant
ALTER TABLE cafe_places
  ADD COLUMN IF NOT EXISTS merchant_id VARCHAR(36) DEFAULT NULL,
  ADD INDEX IF NOT EXISTS idx_cafe_merchant_id (merchant_id);

ALTER TABLE laundry_places
  ADD COLUMN IF NOT EXISTS merchant_id VARCHAR(36) DEFAULT NULL,
  ADD INDEX IF NOT EXISTS idx_laundry_merchant_id (merchant_id);

-- Backfill merchant relation for existing rows (optional default mapping)
UPDATE cafe_places
SET merchant_id = (
  SELECT m.id
  FROM merchants m
  JOIN users u ON u.id = m.user_id
  WHERE u.role = 'merchant'
  ORDER BY m.created_at ASC
  LIMIT 1
)
WHERE merchant_id IS NULL;

UPDATE laundry_places
SET merchant_id = (
  SELECT m.id
  FROM merchants m
  JOIN users u ON u.id = m.user_id
  WHERE u.role = 'merchant'
  ORDER BY m.created_at ASC
  LIMIT 1
)
WHERE merchant_id IS NULL;

ALTER TABLE cafe_places
  ADD CONSTRAINT fk_cafe_places_merchant
  FOREIGN KEY (merchant_id) REFERENCES merchants(id)
  ON DELETE SET NULL;

ALTER TABLE laundry_places
  ADD CONSTRAINT fk_laundry_places_merchant
  FOREIGN KEY (merchant_id) REFERENCES merchants(id)
  ON DELETE SET NULL;

-- 4) Password reset should be tied to user
ALTER TABLE password_resets
  ADD COLUMN IF NOT EXISTS user_id VARCHAR(36) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS used_at TIMESTAMP NULL DEFAULT NULL,
  ADD INDEX IF NOT EXISTS idx_password_resets_user_id (user_id);

UPDATE password_resets pr
JOIN users u ON u.email = pr.email
SET pr.user_id = u.id
WHERE pr.user_id IS NULL;

ALTER TABLE password_resets
  ADD CONSTRAINT fk_password_resets_user
  FOREIGN KEY (user_id) REFERENCES users(id)
  ON DELETE CASCADE;

-- 5) Facilities managed by admin user
ALTER TABLE facilities
  ADD COLUMN IF NOT EXISTS created_by VARCHAR(36) DEFAULT NULL,
  ADD INDEX IF NOT EXISTS idx_facilities_created_by (created_by);

ALTER TABLE facilities
  ADD CONSTRAINT fk_facilities_created_by
  FOREIGN KEY (created_by) REFERENCES users(id)
  ON DELETE SET NULL;

-- 6) Room-level facilities relation
CREATE TABLE IF NOT EXISTS room_facilities (
  room_id VARCHAR(36) NOT NULL,
  facility_id INT NOT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (room_id, facility_id),
  KEY idx_room_facility_id (facility_id),
  CONSTRAINT fk_room_facilities_room
    FOREIGN KEY (room_id) REFERENCES kos_rooms(id) ON DELETE CASCADE,
  CONSTRAINT fk_room_facilities_facility
    FOREIGN KEY (facility_id) REFERENCES facilities(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

COMMIT;
