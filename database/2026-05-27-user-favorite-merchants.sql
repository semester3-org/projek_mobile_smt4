-- Menambahkan tabel favorite merchant user untuk laundry dan catering.

CREATE TABLE IF NOT EXISTS `user_favorite_merchants` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `merchant_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `merchant_type` enum('laundry','catering') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_user_favorite_merchant` (`user_id`,`merchant_id`,`merchant_type`),
  KEY `idx_user_favorite_merchants_user` (`user_id`),
  KEY `idx_user_favorite_merchants_merchant` (`merchant_id`),
  KEY `idx_user_favorite_merchants_type` (`merchant_type`),
  CONSTRAINT `fk_user_favorite_merchants_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_user_favorite_merchants_merchant`
    FOREIGN KEY (`merchant_id`) REFERENCES `merchants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
