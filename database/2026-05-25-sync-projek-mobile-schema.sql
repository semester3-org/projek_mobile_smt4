-- Sinkronisasi schema untuk backend Flutter/PHP di folder projek_mobile.
-- Jalankan pada database `projek_kos` yang sudah ada agar sesuai dengan kode terbaru.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS phone varchar(25) DEFAULT NULL AFTER display_name,
  ADD COLUMN IF NOT EXISTS address text DEFAULT NULL AFTER phone,
  ADD COLUMN IF NOT EXISTS latitude decimal(10,8) DEFAULT NULL AFTER address,
  ADD COLUMN IF NOT EXISTS longitude decimal(11,8) DEFAULT NULL AFTER latitude,
  ADD COLUMN IF NOT EXISTS photo_url longtext DEFAULT NULL AFTER longitude;

ALTER TABLE password_resets
  MODIFY expires_at datetime NOT NULL,
  MODIFY used_at datetime DEFAULT NULL,
  MODIFY created_at datetime DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE users
  MODIFY address text DEFAULT NULL;

CREATE TABLE IF NOT EXISTS sessions (
  id varchar(255) NOT NULL,
  user_id varchar(36) DEFAULT NULL,
  ip_address varchar(45) DEFAULT NULL,
  user_agent text,
  payload longtext NOT NULL,
  last_activity int NOT NULL,
  PRIMARY KEY (id),
  KEY sessions_user_id_index (user_id),
  KEY sessions_last_activity_index (last_activity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
