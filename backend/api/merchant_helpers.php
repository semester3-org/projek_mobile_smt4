<?php

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';

function merchantSendJson(bool $success, $data = null, string $message = '', int $code = 200): void {
    http_response_code($code);
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data' => $data,
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

function merchantBody(): array {
    $body = json_decode(file_get_contents('php://input'), true);
    return is_array($body) ? $body : [];
}

function merchantTableExists(mysqli $conn, string $table): bool {
    $stmt = $conn->prepare(
        'SELECT COUNT(*) AS total FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?'
    );
    if (!$stmt) return false;
    $stmt->bind_param('s', $table);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return (int)($row['total'] ?? 0) > 0;
}

function merchantColumnExists(mysqli $conn, string $table, string $column): bool {
    $stmt = $conn->prepare(
        'SELECT COUNT(*) AS total FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?'
    );
    if (!$stmt) return false;
    $stmt->bind_param('ss', $table, $column);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return (int)($row['total'] ?? 0) > 0;
}

function merchantConstraintExists(mysqli $conn, string $table, string $constraint): bool {
    $stmt = $conn->prepare(
        'SELECT COUNT(*) AS total FROM information_schema.table_constraints WHERE table_schema = DATABASE() AND table_name = ? AND constraint_name = ?'
    );
    if (!$stmt) return false;
    $stmt->bind_param('ss', $table, $constraint);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return (int)($row['total'] ?? 0) > 0;
}

function merchantIndexExists(mysqli $conn, string $table, string $index): bool {
    $stmt = $conn->prepare(
        'SELECT COUNT(*) AS total FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = ? AND index_name = ?'
    );
    if (!$stmt) return false;
    $stmt->bind_param('ss', $table, $index);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return (int)($row['total'] ?? 0) > 0;
}

function merchantAddForeignKey(mysqli $conn, string $table, string $constraint, string $definition): void {
    if (!merchantTableExists($conn, $table) || merchantConstraintExists($conn, $table, $constraint)) {
        return;
    }

    try {
        @$conn->query("ALTER TABLE `$table` ADD CONSTRAINT `$constraint` $definition");
    } catch (Throwable $e) {
        // Existing installs may contain older data; schema setup should keep the app usable.
    }
}

function merchantAddIndex(mysqli $conn, string $table, string $index, string $definition): void {
    if (!merchantTableExists($conn, $table) || merchantIndexExists($conn, $table, $index)) {
        return;
    }

    try {
        @$conn->query("ALTER TABLE `$table` ADD INDEX `$index` ($definition)");
    } catch (Throwable $e) {
        // Index setup must not block app usage on older MySQL installs.
    }
}

function merchantUuid(): string {
    return sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}

function merchantRequireAuth(): array {
    $payload = JWT::getPayloadFromRequest();
    if (!$payload) {
        merchantSendJson(false, null, 'Unauthorized', 401);
    }
    return $payload;
}

function merchantRequireMerchant(): array {
    $payload = merchantRequireAuth();
    if (($payload['role'] ?? '') !== 'merchant') {
        merchantSendJson(false, null, 'Akses khusus merchant', 403);
    }
    return $payload;
}

function merchantQueryValue(mysqli $conn, string $sql, string $types = '', array $values = []) {
    $stmt = $conn->prepare($sql);
    if (!$stmt) return null;
    if ($types !== '') {
        $stmt->bind_param($types, ...$values);
    }
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) return null;
    return array_values($row)[0] ?? null;
}

function merchantAddColumn(mysqli $conn, string $table, string $column, string $definition): void {
    if (merchantTableExists($conn, $table) && !merchantColumnExists($conn, $table, $column)) {
        if (!$conn->query("ALTER TABLE `$table` ADD COLUMN $definition")) {
            throw new Exception("Gagal menyiapkan kolom $table.$column: " . $conn->error);
        }
    }
}

function merchantEnsurePerformanceIndexes(mysqli $conn): void {
    merchantAddIndex($conn, 'merchants', 'idx_merchants_type_status_updated', '`merchant_type`, `status`, `updated_at`');
    merchantAddIndex($conn, 'laundry_places', 'idx_laundry_places_merchant', '`merchant_id`');
    merchantAddIndex($conn, 'catering_places', 'idx_catering_places_merchant', '`merchant_id`');
    merchantAddIndex($conn, 'products', 'idx_products_merchant_active_updated', '`merchant_id`, `is_active`, `updated_at`, `id`');
    merchantAddIndex($conn, 'orders', 'idx_orders_merchant_status_payment', '`merchant_id`, `status`, `payment_status`, `created_at`');
    merchantAddIndex($conn, 'orders', 'idx_orders_merchant_updated', '`merchant_id`, `updated_at`, `id`');
    merchantAddIndex($conn, 'orders', 'idx_orders_merchant_service_subs', '`merchant_id`, `service_type`, `subscription_start_date`, `subscription_end_date`');
    merchantAddIndex($conn, 'orders', 'idx_orders_user_service_status_payment', '`user_id`, `service_type`, `status`, `payment_status`');
    merchantAddIndex($conn, 'orders', 'idx_orders_user_updated', '`user_id`, `updated_at`, `id`');
    merchantAddIndex($conn, 'orders', 'idx_orders_extension_status', '`extension_parent_order_id`, `status`');
    merchantAddIndex($conn, 'orders', 'idx_orders_midtrans', '`midtrans_order_id`');
    merchantAddIndex($conn, 'order_items', 'idx_order_items_order_product', '`order_id`, `product_id`');
    merchantAddIndex($conn, 'catering_subscribers', 'idx_subscribers_user_status_dates', '`user_id`, `subscription_status`, `start_date`, `end_date`');
    merchantAddIndex($conn, 'catering_subscribers', 'idx_subscribers_merchant_status_dates', '`merchant_id`, `subscription_status`, `start_date`, `end_date`');
    merchantAddIndex($conn, 'merchant_reviews', 'idx_reviews_merchant_deleted_rating', '`merchant_id`, `deleted_at`, `rating`');
    merchantAddIndex($conn, 'merchant_reviews', 'idx_reviews_product_deleted_rating', '`product_id`, `deleted_at`, `rating`');
    merchantAddIndex($conn, 'merchant_promos', 'idx_promos_merchant_active_window', '`merchant_id`, `is_active`, `start_at`, `end_at`');
    merchantAddIndex($conn, 'catering_delivery_logs', 'idx_delivery_merchant_date_status', '`merchant_id`, `delivery_date`, `status`');
    merchantAddIndex($conn, 'catering_delivery_logs', 'idx_delivery_order_date_status', '`order_id`, `delivery_date`, `status`');
    merchantAddIndex($conn, 'app_notifications', 'idx_notifications_user_created', '`user_id`, `created_at`');
    merchantAddIndex($conn, 'user_notification_devices', 'idx_notification_devices_user_active', '`user_id`, `is_active`, `last_seen_at`');
}

function merchantEnsureSchema(mysqli $conn): void {
    if (!merchantTableExists($conn, 'merchants')) {
        $conn->query("
            CREATE TABLE merchants (
                id VARCHAR(36) NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                business_name VARCHAR(255) NOT NULL,
                merchant_type ENUM('catering','laundry') DEFAULT 'laundry',
                phone VARCHAR(25) DEFAULT NULL,
                address VARCHAR(255) DEFAULT NULL,
                created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uniq_merchants_user_id (user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    merchantAddColumn($conn, 'merchants', 'merchant_code', "`merchant_code` VARCHAR(32) DEFAULT NULL");
    merchantAddColumn($conn, 'merchants', 'description', "`description` TEXT DEFAULT NULL");
    merchantAddColumn($conn, 'merchants', 'photo_url', "`photo_url` LONGTEXT DEFAULT NULL");
    merchantAddColumn($conn, 'merchants', 'latitude', "`latitude` DECIMAL(10,8) DEFAULT NULL");
    merchantAddColumn($conn, 'merchants', 'longitude', "`longitude` DECIMAL(11,8) DEFAULT NULL");
    merchantAddColumn($conn, 'merchants', 'open_time', "`open_time` VARCHAR(5) DEFAULT '08:00'");
    merchantAddColumn($conn, 'merchants', 'close_time', "`close_time` VARCHAR(5) DEFAULT '21:00'");
    merchantAddColumn($conn, 'merchants', 'status', "`status` ENUM('active','inactive') DEFAULT 'active'");

    if (merchantTableExists($conn, 'products')) {
        merchantAddColumn($conn, 'products', 'category', "`category` VARCHAR(100) DEFAULT NULL");
        merchantAddColumn($conn, 'products', 'unit', "`unit` VARCHAR(30) DEFAULT NULL");
        merchantAddColumn($conn, 'products', 'image_url', "`image_url` LONGTEXT DEFAULT NULL");
        merchantAddColumn($conn, 'products', 'is_active', "`is_active` TINYINT(1) NOT NULL DEFAULT 1");
        merchantAddColumn($conn, 'products', 'service_type', "`service_type` VARCHAR(30) DEFAULT NULL");
        merchantAddColumn($conn, 'products', 'pricing_type', "`pricing_type` VARCHAR(20) NOT NULL DEFAULT 'per_kg'");
        merchantAddColumn($conn, 'products', 'duration_value', "`duration_value` INT DEFAULT NULL");
        merchantAddColumn($conn, 'products', 'duration_unit', "`duration_unit` VARCHAR(10) DEFAULT 'day'");
    } else {
        $conn->query("
            CREATE TABLE products (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                merchant_id VARCHAR(36) NOT NULL,
                nama_produk VARCHAR(255) NOT NULL,
                harga DECIMAL(14,2) NOT NULL DEFAULT 0,
                deskripsi TEXT DEFAULT NULL,
                category VARCHAR(100) DEFAULT NULL,
                unit VARCHAR(30) DEFAULT NULL,
                image_url LONGTEXT DEFAULT NULL,
                is_active TINYINT(1) NOT NULL DEFAULT 1,
                service_type VARCHAR(30) DEFAULT NULL,
                pricing_type VARCHAR(20) NOT NULL DEFAULT 'per_kg',
                duration_value INT DEFAULT NULL,
                duration_unit VARCHAR(10) DEFAULT 'day',
                created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY products_merchant_id_foreign (merchant_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (merchantTableExists($conn, 'products')) {
        merchantAddColumn($conn, 'products', 'price_20_days', "`price_20_days` DECIMAL(14,2) DEFAULT NULL");
        merchantAddColumn($conn, 'products', 'package_delivery_type', "`package_delivery_type` ENUM('full_day','weekday') DEFAULT NULL");
        merchantAddColumn($conn, 'products', 'meal_delivery_count', "`meal_delivery_count` TINYINT UNSIGNED NOT NULL DEFAULT 1");
        merchantAddColumn($conn, 'products', 'delivery_time_1', "`delivery_time_1` VARCHAR(5) DEFAULT '07:00'");
        merchantAddColumn($conn, 'products', 'delivery_time_2', "`delivery_time_2` VARCHAR(5) DEFAULT NULL");
    }

    if (merchantTableExists($conn, 'orders')) {
        merchantAddColumn($conn, 'orders', 'cancellation_window_until', "`cancellation_window_until` DATETIME DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'order_code', "`order_code` VARCHAR(40) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'service_type', "`service_type` VARCHAR(30) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'delivery_address', "`delivery_address` TEXT DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'estimated_time', "`estimated_time` VARCHAR(100) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'payment_method', "`payment_method` VARCHAR(40) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'payment_status', "`payment_status` VARCHAR(40) DEFAULT 'waiting_payment'");
        merchantAddColumn($conn, 'orders', 'customer_name', "`customer_name` VARCHAR(120) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'customer_phone', "`customer_phone` VARCHAR(25) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'notes', "`notes` TEXT DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'delivery_latitude', "`delivery_latitude` DECIMAL(10,8) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'delivery_longitude', "`delivery_longitude` DECIMAL(11,8) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'midtrans_order_id', "`midtrans_order_id` VARCHAR(50) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'paid_at', "`paid_at` DATETIME DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'subscription_days', "`subscription_days` INT DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'subscription_start_date', "`subscription_start_date` DATE DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'subscription_end_date', "`subscription_end_date` DATE DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'subscription_status', "`subscription_status` VARCHAR(30) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'cancellation_requested_at', "`cancellation_requested_at` DATETIME DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'extension_parent_order_id', "`extension_parent_order_id` BIGINT UNSIGNED DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'extension_days', "`extension_days` INT DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'promo_id', "`promo_id` BIGINT UNSIGNED DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'promo_name', "`promo_name` VARCHAR(255) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'promo_discount_amount', "`promo_discount_amount` DECIMAL(14,2) NOT NULL DEFAULT 0");
        merchantAddColumn($conn, 'orders', 'subtotal_amount', "`subtotal_amount` DECIMAL(14,2) NOT NULL DEFAULT 0");
        merchantAddColumn($conn, 'orders', 'laundry_weight_kg', "`laundry_weight_kg` DECIMAL(10,2) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'estimated_finish_at', "`estimated_finish_at` DATETIME DEFAULT NULL");
    } else {
        $conn->query("
            CREATE TABLE orders (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                user_id VARCHAR(36) NOT NULL,
                merchant_id VARCHAR(36) NOT NULL,
                total_harga DECIMAL(14,2) NOT NULL DEFAULT 0,
                status ENUM('pending','accepted','processing','delivered','done') NOT NULL DEFAULT 'pending',
                order_code VARCHAR(40) DEFAULT NULL,
                service_type VARCHAR(30) DEFAULT NULL,
                delivery_address TEXT DEFAULT NULL,
                estimated_time VARCHAR(100) DEFAULT NULL,
                payment_method VARCHAR(40) DEFAULT NULL,
                payment_status VARCHAR(40) DEFAULT 'waiting_payment',
                customer_name VARCHAR(120) DEFAULT NULL,
                customer_phone VARCHAR(25) DEFAULT NULL,
                notes TEXT DEFAULT NULL,
                delivery_latitude DECIMAL(10,8) DEFAULT NULL,
                delivery_longitude DECIMAL(11,8) DEFAULT NULL,
                midtrans_order_id VARCHAR(50) DEFAULT NULL,
                paid_at DATETIME DEFAULT NULL,
                subscription_days INT DEFAULT NULL,
                subscription_start_date DATE DEFAULT NULL,
                subscription_end_date DATE DEFAULT NULL,
                subscription_status VARCHAR(30) DEFAULT NULL,
                cancellation_requested_at DATETIME DEFAULT NULL,
                extension_parent_order_id BIGINT UNSIGNED DEFAULT NULL,
                extension_days INT DEFAULT NULL,
                promo_id BIGINT UNSIGNED DEFAULT NULL,
                promo_name VARCHAR(255) DEFAULT NULL,
                promo_discount_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
                subtotal_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
                laundry_weight_kg DECIMAL(10,2) DEFAULT NULL,
                estimated_finish_at DATETIME DEFAULT NULL,
                created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY orders_user_id_foreign (user_id),
                KEY orders_merchant_id_foreign (merchant_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (!merchantTableExists($conn, 'order_items')) {
        $conn->query("
            CREATE TABLE order_items (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                order_id BIGINT UNSIGNED NOT NULL,
                product_id BIGINT UNSIGNED NOT NULL,
                qty INT UNSIGNED NOT NULL DEFAULT 1,
                harga DECIMAL(14,2) NOT NULL DEFAULT 0,
                created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY order_items_order_id_foreign (order_id),
                KEY order_items_product_id_foreign (product_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (!merchantTableExists($conn, 'merchant_promos')) {
        $conn->query("
            CREATE TABLE merchant_promos (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                merchant_id VARCHAR(36) NOT NULL,
                product_id BIGINT UNSIGNED DEFAULT NULL,
                name VARCHAR(255) NOT NULL,
                description TEXT DEFAULT NULL,
                discount_type ENUM('percentage','fixed') NOT NULL DEFAULT 'percentage',
                discount_value DECIMAL(14,2) NOT NULL DEFAULT 0,
                min_order_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
                max_discount_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
                start_at DATETIME DEFAULT NULL,
                end_at DATETIME DEFAULT NULL,
                is_active TINYINT(1) NOT NULL DEFAULT 1,
                usage_limit INT DEFAULT NULL,
                used_count INT NOT NULL DEFAULT 0,
                created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_merchant_promos_merchant (merchant_id),
                KEY idx_merchant_promos_product (product_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    merchantAddColumn($conn, 'merchant_promos', 'per_user_usage_limit', "`per_user_usage_limit` INT DEFAULT 1");
    merchantAddColumn($conn, 'merchant_promos', 'status', "`status` VARCHAR(20) NOT NULL DEFAULT 'draft'");
    merchantAddColumn($conn, 'merchant_promos', 'first_broadcast_at', "`first_broadcast_at` DATETIME DEFAULT NULL");
    if (merchantColumnExists($conn, 'merchant_promos', 'first_broadcast_at')) {
        $conn->query("
            UPDATE merchant_promos
            SET first_broadcast_at = COALESCE(created_at, NOW())
            WHERE first_broadcast_at IS NULL
              AND status <> 'draft'
        ");
    }

    if (!merchantTableExists($conn, 'merchant_promo_products')) {
        $conn->query("
            CREATE TABLE merchant_promo_products (
                promo_id BIGINT UNSIGNED NOT NULL,
                product_id BIGINT UNSIGNED NOT NULL,
                created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (promo_id, product_id),
                KEY idx_mpp_product (product_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (!merchantTableExists($conn, 'promo_usages')) {
        $conn->query("
            CREATE TABLE promo_usages (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                promo_id BIGINT UNSIGNED NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                order_id BIGINT UNSIGNED NOT NULL,
                created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uniq_promo_user_order (promo_id, user_id, order_id),
                KEY idx_promo_usages_promo_user (promo_id, user_id),
                KEY idx_promo_usages_order (order_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (!merchantTableExists($conn, 'merchant_reviews')) {
        $conn->query("
            CREATE TABLE merchant_reviews (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                merchant_id VARCHAR(36) NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                product_id BIGINT UNSIGNED DEFAULT NULL,
                rating TINYINT UNSIGNED NOT NULL,
                comment TEXT DEFAULT NULL,
                edit_count INT NOT NULL DEFAULT 0,
                deleted_at TIMESTAMP NULL DEFAULT NULL,
                created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_merchant_reviews_merchant (merchant_id),
                KEY idx_merchant_reviews_user (user_id),
                KEY idx_merchant_reviews_product (product_id),
                KEY idx_merchant_reviews_deleted (deleted_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }
    merchantAddColumn($conn, 'merchant_reviews', 'deleted_at', "`deleted_at` TIMESTAMP NULL DEFAULT NULL");
    merchantAddColumn($conn, 'merchant_reviews', 'edit_count', "`edit_count` INT NOT NULL DEFAULT 0");
    merchantAddForeignKey(
        $conn,
        'merchant_reviews',
        'fk_merchant_reviews_merchant',
        'FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE'
    );
    merchantAddForeignKey(
        $conn,
        'merchant_reviews',
        'fk_merchant_reviews_user',
        'FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE'
    );
    merchantAddForeignKey(
        $conn,
        'merchant_reviews',
        'fk_merchant_reviews_product',
        'FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL'
    );

    if (!merchantTableExists($conn, 'app_notifications')) {
        $conn->query("
            CREATE TABLE app_notifications (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(64) NOT NULL,
                title VARCHAR(160) NOT NULL,
                message TEXT NOT NULL,
                type VARCHAR(30) DEFAULT NULL,
                status VARCHAR(30) DEFAULT 'baru',
                action_text VARCHAR(80) DEFAULT NULL,
                action_url VARCHAR(160) DEFAULT NULL,
                importance VARCHAR(20) DEFAULT 'normal',
                read_at TIMESTAMP NULL DEFAULT NULL,
                seen_in_app_at TIMESTAMP NULL DEFAULT NULL,
                delivered_push_at TIMESTAMP NULL DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                KEY idx_notifications_user_created (user_id, created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (merchantTableExists($conn, 'app_notifications')) {
        merchantAddColumn($conn, 'app_notifications', 'type', "`type` VARCHAR(30) DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'status', "`status` VARCHAR(30) DEFAULT 'baru'");
        merchantAddColumn($conn, 'app_notifications', 'action_text', "`action_text` VARCHAR(80) DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'action_url', "`action_url` VARCHAR(160) DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'importance', "`importance` VARCHAR(20) DEFAULT 'normal'");
        merchantAddColumn($conn, 'app_notifications', 'read_at', "`read_at` TIMESTAMP NULL DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'seen_in_app_at', "`seen_in_app_at` TIMESTAMP NULL DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'delivered_push_at', "`delivered_push_at` TIMESTAMP NULL DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'created_at', "`created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP");
        merchantAddColumn($conn, 'app_notifications', 'updated_at', "`updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP");
    }

    if (!merchantTableExists($conn, 'user_app_presence')) {
        $conn->query("
            CREATE TABLE user_app_presence (
                user_id VARCHAR(64) PRIMARY KEY,
                is_active TINYINT(1) NOT NULL DEFAULT 0,
                last_seen_at TIMESTAMP NULL DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (!merchantTableExists($conn, 'user_notification_devices')) {
        $conn->query("
            CREATE TABLE user_notification_devices (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(64) NOT NULL,
                fcm_token VARCHAR(512) NOT NULL,
                platform VARCHAR(30) DEFAULT 'flutter',
                is_active TINYINT(1) NOT NULL DEFAULT 1,
                last_seen_at TIMESTAMP NULL DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY unique_notification_token (fcm_token),
                KEY idx_notification_devices_user_active (user_id, is_active, last_seen_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }
    if (merchantTableExists($conn, 'user_notification_devices') &&
        merchantColumnExists($conn, 'user_notification_devices', 'fcm_token')) {
        try {
            @$conn->query("ALTER TABLE user_notification_devices MODIFY fcm_token VARCHAR(512) NOT NULL");
        } catch (Throwable $e) {
            // Existing installs should keep working even if the index length cannot be changed.
        }
    }

    if (merchantTableExists($conn, 'users')) {
        merchantAddColumn($conn, 'users', 'phone', "`phone` VARCHAR(25) DEFAULT NULL");
        merchantAddColumn($conn, 'users', 'address', "`address` TEXT DEFAULT NULL");
        merchantAddColumn($conn, 'users', 'latitude', "`latitude` DECIMAL(10,8) DEFAULT NULL");
        merchantAddColumn($conn, 'users', 'longitude', "`longitude` DECIMAL(11,8) DEFAULT NULL");
        merchantAddColumn($conn, 'users', 'photo_url', "`photo_url` LONGTEXT DEFAULT NULL");
    }

    if (!merchantTableExists($conn, 'catering_package_categories')) {
        $conn->query("
            CREATE TABLE catering_package_categories (
                id VARCHAR(36) PRIMARY KEY,
                merchant_id VARCHAR(36) DEFAULT NULL,
                created_by VARCHAR(36) DEFAULT NULL,
                scope ENUM('global','merchant') DEFAULT 'merchant',
                category_name VARCHAR(100) NOT NULL,
                description TEXT,
                is_active TINYINT(1) DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY unique_scope_category (scope, merchant_id, category_name),
                KEY idx_catering_package_categories_merchant (merchant_id),
                KEY idx_catering_package_categories_created_by (created_by),
                KEY idx_catering_package_categories_scope (scope),
                CONSTRAINT fk_catering_package_categories_merchant FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE SET NULL,
                CONSTRAINT fk_catering_package_categories_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }
    merchantAddColumn($conn, 'catering_package_categories', 'created_by', "`created_by` VARCHAR(36) DEFAULT NULL");
    merchantAddColumn($conn, 'catering_package_categories', 'scope', "`scope` ENUM('global','merchant') DEFAULT 'merchant'");

    if (merchantTableExists($conn, 'catering_package_categories')) {
        $conn->query("ALTER TABLE catering_package_categories MODIFY merchant_id VARCHAR(36) DEFAULT NULL");
        merchantAddForeignKey(
            $conn,
            'catering_package_categories',
            'fk_catering_package_categories_merchant',
            'FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE SET NULL'
        );
        merchantAddForeignKey(
            $conn,
            'catering_package_categories',
            'fk_catering_package_categories_created_by',
            'FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL'
        );
        $conn->query("
            INSERT IGNORE INTO catering_package_categories
                (id, merchant_id, created_by, scope, category_name, description, is_active, created_at, updated_at)
            VALUES
                ('catpkg-hemat', NULL, NULL, 'global', 'Paket Hemat', 'Kategori paket standar dengan menu harian terjangkau.', 1, NOW(), NOW()),
                ('catpkg-premium', NULL, NULL, 'global', 'Paket Premium', 'Kategori paket dengan variasi lauk lebih lengkap.', 1, NOW(), NOW()),
                ('catpkg-diet', NULL, NULL, 'global', 'Paket Diet Sehat', 'Kategori paket rendah kalori dan tinggi protein.', 1, NOW(), NOW())
        ");
    }

    if (!merchantTableExists($conn, 'catering_subscribers')) {
        $conn->query("
            CREATE TABLE catering_subscribers (
                id VARCHAR(36) PRIMARY KEY,
                order_id BIGINT UNSIGNED NOT NULL,
                merchant_id VARCHAR(36) NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                package_type VARCHAR(50),
                start_date DATE,
                end_date DATE,
                subscription_status VARCHAR(30),
                cancellation_requested_at DATETIME,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY uniq_order (order_id),
                KEY idx_merchant_active (merchant_id, subscription_status),
                KEY idx_user_active (user_id, subscription_status)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (!merchantTableExists($conn, 'merchant_operating_hours')) {
        $conn->query("
            CREATE TABLE merchant_operating_hours (
                id VARCHAR(36) PRIMARY KEY,
                merchant_id VARCHAR(36) NOT NULL,
                day_of_week INT,
                opening_time TIME,
                closing_time TIME,
                is_open TINYINT(1) DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY unique_merchant_day (merchant_id, day_of_week)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (!merchantTableExists($conn, 'catering_delivery_logs')) {
        $conn->query("
            CREATE TABLE catering_delivery_logs (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                order_id BIGINT UNSIGNED NOT NULL,
                merchant_id VARCHAR(36) NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                delivery_date DATE NOT NULL,
                slot_number TINYINT UNSIGNED NOT NULL,
                scheduled_time VARCHAR(5) NOT NULL,
                status ENUM('pending','delivered') NOT NULL DEFAULT 'pending',
                delivered_at DATETIME DEFAULT NULL,
                delivery_note TEXT DEFAULT NULL,
                delivery_photo_url LONGTEXT DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uniq_catering_delivery_slot (order_id, delivery_date, slot_number),
                KEY idx_catering_delivery_merchant_date (merchant_id, delivery_date),
                KEY idx_catering_delivery_order_date (order_id, delivery_date),
                KEY idx_catering_delivery_status (status)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }
    if (merchantTableExists($conn, 'catering_delivery_logs')) {
        merchantAddColumn($conn, 'catering_delivery_logs', 'delivery_note', "`delivery_note` TEXT DEFAULT NULL");
        merchantAddColumn($conn, 'catering_delivery_logs', 'delivery_photo_url', "`delivery_photo_url` LONGTEXT DEFAULT NULL");
    }
    merchantRepairCateringDeliveryLogDates($conn);

    if (!merchantTableExists($conn, 'user_favorite_merchants')) {
        $conn->query("
            CREATE TABLE user_favorite_merchants (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                user_id VARCHAR(36) NOT NULL,
                merchant_id VARCHAR(36) NOT NULL,
                merchant_type ENUM('laundry','catering') NOT NULL,
                created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY unique_user_favorite_merchant (user_id, merchant_id, merchant_type),
                KEY idx_user_favorite_merchants_user (user_id),
                KEY idx_user_favorite_merchants_merchant (merchant_id),
                KEY idx_user_favorite_merchants_type (merchant_type)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (!merchantTableExists($conn, 'laundry_service_estimates')) {
        $conn->query("
            CREATE TABLE laundry_service_estimates (
                id VARCHAR(36) PRIMARY KEY,
                merchant_id VARCHAR(36) NOT NULL,
                service_name VARCHAR(100),
                min_hours INT,
                max_hours INT,
                is_active TINYINT(1) DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                KEY idx_merchant_active (merchant_id, is_active)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (!merchantTableExists($conn, 'laundry_service_addons')) {
        $conn->query("
            CREATE TABLE laundry_service_addons (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                merchant_id VARCHAR(36) NOT NULL,
                product_id BIGINT UNSIGNED NOT NULL,
                name VARCHAR(120) NOT NULL,
                price DECIMAL(14,2) NOT NULL DEFAULT 0,
                pricing_type VARCHAR(20) NOT NULL DEFAULT 'flat',
                is_active TINYINT(1) NOT NULL DEFAULT 1,
                created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_laundry_addons_product (product_id, is_active),
                KEY idx_laundry_addons_merchant (merchant_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (!merchantTableExists($conn, 'laundry_order_addons')) {
        $conn->query("
            CREATE TABLE laundry_order_addons (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                order_id BIGINT UNSIGNED NOT NULL,
                addon_id BIGINT UNSIGNED DEFAULT NULL,
                name VARCHAR(120) NOT NULL,
                price DECIMAL(14,2) NOT NULL DEFAULT 0,
                pricing_type VARCHAR(20) NOT NULL DEFAULT 'flat',
                qty DECIMAL(10,2) NOT NULL DEFAULT 1,
                subtotal DECIMAL(14,2) NOT NULL DEFAULT 0,
                created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_laundry_order_addons_order (order_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (!merchantTableExists($conn, 'transaction_receipts')) {
        $conn->query("
            CREATE TABLE transaction_receipts (
                id VARCHAR(36) PRIMARY KEY,
                order_id BIGINT UNSIGNED,
                billing_id VARCHAR(36),
                receipt_url VARCHAR(500),
                receipt_type VARCHAR(20),
                generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_order_receipt (order_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (merchantTableExists($conn, 'products')) {
        merchantAddColumn($conn, 'products', 'laundry_estimate_id', "`laundry_estimate_id` VARCHAR(36) DEFAULT NULL");
        merchantAddColumn($conn, 'products', 'catering_package_category_id', "`catering_package_category_id` VARCHAR(36) DEFAULT NULL");
        merchantAddColumn($conn, 'products', 'meal_delivery_count', "`meal_delivery_count` TINYINT UNSIGNED NOT NULL DEFAULT 1");
        merchantAddColumn($conn, 'products', 'delivery_time_1', "`delivery_time_1` VARCHAR(5) DEFAULT '07:00'");
        merchantAddColumn($conn, 'products', 'delivery_time_2', "`delivery_time_2` VARCHAR(5) DEFAULT NULL");
    }

    $conn->query("
        UPDATE merchants
        SET merchant_code = CONCAT('M-', UPPER(SUBSTRING(REPLACE(id, '-', ''), 1, 8)))
        WHERE merchant_code IS NULL OR merchant_code = ''
    ");
    $conn->query("
        UPDATE orders
        SET order_code = CONCAT('SR-', UPPER(COALESCE(service_type, 'ORDER')), '-', LPAD(id, 6, '0'))
        WHERE order_code IS NULL OR order_code = ''
    ");

    merchantEnsurePerformanceIndexes($conn);
}

function merchantExpireFinishedCateringSubscriptions(mysqli $conn): void {
    if (!merchantTableExists($conn, 'orders') ||
        !merchantColumnExists($conn, 'orders', 'subscription_end_date')) {
        return;
    }

    $conn->query("
        UPDATE orders
        SET subscription_status = 'ended',
            status = 'done',
            updated_at = NOW()
        WHERE service_type = 'catering'
          AND subscription_end_date IS NOT NULL
          AND subscription_end_date < CURDATE()
          AND COALESCE(subscription_status, 'active') IN ('active', 'cancel_requested')
          AND status <> 'done'
    ");

    if (merchantTableExists($conn, 'catering_subscribers')) {
        $conn->query("
            UPDATE catering_subscribers cs
            INNER JOIN orders o ON o.id = cs.order_id
            SET cs.subscription_status = 'expired', cs.updated_at = NOW()
            WHERE o.subscription_end_date IS NOT NULL
              AND o.subscription_end_date < CURDATE()
              AND cs.subscription_status IN ('active', 'cancel_requested')
        ");
    }
}

function merchantSyncCateringSubscriber(mysqli $conn, int $orderId): void {
    if (!merchantTableExists($conn, 'catering_subscribers')) {
        return;
    }

    $stmt = $conn->prepare("
        SELECT o.id, o.merchant_id, o.user_id, o.subscription_days,
               o.subscription_start_date, o.subscription_end_date,
               o.subscription_status, o.cancellation_requested_at,
               o.estimated_time, o.notes
        FROM orders o
        WHERE o.id = ? AND o.service_type = 'catering'
        LIMIT 1
    ");
    if (!$stmt) {
        return;
    }
    $stmt->bind_param('i', $orderId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) {
        return;
    }

    $isWeekdayPackage = str_contains(strtolower((string)($row['estimated_time'] ?? '') . ' ' . (string)($row['notes'] ?? '')), 'weekday');
    $packageType = $isWeekdayPackage
        ? 'weekday_30_days'
        : ((int)($row['subscription_days'] ?? 30)) . '_days';
    $status = strtolower((string)($row['subscription_status'] ?? 'active'));
    if ($status === 'pending_payment') {
        $status = 'pending';
    }

    $existing = merchantQueryValue(
        $conn,
        'SELECT id FROM catering_subscribers WHERE order_id = ? LIMIT 1',
        'i',
        [$orderId]
    );

    if ($existing) {
        $stmt = $conn->prepare("
            UPDATE catering_subscribers
            SET package_type = ?,
                start_date = ?,
                end_date = ?,
                subscription_status = ?,
                cancellation_requested_at = ?,
                updated_at = NOW()
            WHERE order_id = ?
        ");
        if (!$stmt) {
            return;
        }
        $stmt->bind_param(
            'sssssi',
            $packageType,
            $row['subscription_start_date'],
            $row['subscription_end_date'],
            $status,
            $row['cancellation_requested_at'],
            $orderId
        );
        $stmt->execute();
        $stmt->close();
        return;
    }

    $id = merchantUuid();
    $stmt = $conn->prepare("
        INSERT INTO catering_subscribers
            (id, order_id, merchant_id, user_id, package_type, start_date, end_date,
             subscription_status, cancellation_requested_at, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ");
    if (!$stmt) {
        return;
    }
    $stmt->bind_param(
        'sisssssss',
        $id,
        $orderId,
        $row['merchant_id'],
        $row['user_id'],
        $packageType,
        $row['subscription_start_date'],
        $row['subscription_end_date'],
        $status,
        $row['cancellation_requested_at']
    );
    $stmt->execute();
    $stmt->close();
}

function merchantActivateCateringSubscription(mysqli $conn, int $orderId): void {
    $stmt = $conn->prepare("
        SELECT id, subscription_days, subscription_status, status, payment_status,
               extension_parent_order_id, extension_days
        FROM orders
        WHERE id = ?
          AND service_type = 'catering'
          AND subscription_days IS NOT NULL
        LIMIT 1
    ");
    if (!$stmt) {
        return;
    }
    $stmt->bind_param('i', $orderId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) {
        return;
    }
    if (strtolower((string)($row['status'] ?? '')) !== 'accepted' ||
        !in_array(strtolower((string)($row['payment_status'] ?? '')), ['paid', 'payment_submitted'], true)) {
        return;
    }

    $extensionParentId = (int)($row['extension_parent_order_id'] ?? 0);
    if ($extensionParentId > 0) {
        $extraDays = (int)($row['extension_days'] ?? $row['subscription_days'] ?? 30);
        if (!in_array($extraDays, [20, 30], true)) {
            $extraDays = 30;
        }

        $parentStmt = $conn->prepare("
            SELECT subscription_end_date
            FROM orders
            WHERE id = ?
              AND service_type = 'catering'
            LIMIT 1
        ");
        if (!$parentStmt) {
            return;
        }
        $parentStmt->bind_param('i', $extensionParentId);
        $parentStmt->execute();
        $parent = $parentStmt->get_result()->fetch_assoc();
        $parentStmt->close();
        if (!$parent) {
            return;
        }

        $base = new DateTime('today');
        if (!empty($parent['subscription_end_date'])) {
            $currentEnd = new DateTime((string)$parent['subscription_end_date']);
            if ($currentEnd > $base) {
                $base = $currentEnd;
            }
        }
        $extensionStart = clone $base;
        $extensionStart->modify('+1 day');
        $newEnd = clone $base;
        $newEnd->modify('+' . $extraDays . ' day');

        $startDate = $extensionStart->format('Y-m-d');
        $endDate = $newEnd->format('Y-m-d');
        $stmt = $conn->prepare("
            UPDATE orders
            SET subscription_days = COALESCE(subscription_days, 0) + ?,
                subscription_end_date = ?,
                subscription_status = 'active',
                updated_at = NOW()
            WHERE id = ?
              AND service_type = 'catering'
        ");
        if ($stmt) {
            $stmt->bind_param('isi', $extraDays, $endDate, $extensionParentId);
            $stmt->execute();
            $stmt->close();
        }

        $stmt = $conn->prepare("
            UPDATE orders
            SET status = 'done',
                subscription_status = 'ended',
                subscription_start_date = ?,
                subscription_end_date = ?,
                updated_at = NOW()
            WHERE id = ?
              AND service_type = 'catering'
        ");
        if ($stmt) {
            $stmt->bind_param('ssi', $startDate, $endDate, $orderId);
            $stmt->execute();
            $stmt->close();
        }

        merchantSyncCateringSubscriber($conn, $extensionParentId);
        merchantEnsureCateringDeliveryLogs($conn, $extensionParentId);
        return;
    }

    $days = (int)($row['subscription_days'] ?? 30);
    if (!in_array($days, [20, 30], true)) {
        $days = 30;
    }
    $start = new DateTime('today');
    $end = clone $start;
    $end->modify('+' . max(0, $days - 1) . ' day');

    $stmt = $conn->prepare("
        UPDATE orders
        SET subscription_status = 'active',
            subscription_start_date = ?,
            subscription_end_date = ?,
            updated_at = NOW()
        WHERE id = ?
          AND service_type = 'catering'
    ");
    if ($stmt) {
        $startDate = $start->format('Y-m-d');
        $endDate = $end->format('Y-m-d');
        $stmt->bind_param('ssi', $startDate, $endDate, $orderId);
        $stmt->execute();
        $stmt->close();
    }
    merchantSyncCateringSubscriber($conn, $orderId);
    merchantEnsureCateringDeliveryLogs($conn, $orderId);
}

function merchantCateringDeliverySlots(mysqli $conn, int $orderId): array {
    $stmt = $conn->prepare("
        SELECT p.meal_delivery_count, p.delivery_time_1, p.delivery_time_2
        FROM order_items oi
        INNER JOIN products p ON p.id = oi.product_id
        WHERE oi.order_id = ?
        ORDER BY oi.id ASC
        LIMIT 1
    ");
    if (!$stmt) {
        return [['slot' => 1, 'time' => '07:00']];
    }
    $stmt->bind_param('i', $orderId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    $count = max(1, min(2, (int)($row['meal_delivery_count'] ?? 1)));
    $time1 = trim((string)($row['delivery_time_1'] ?? '07:00'));
    $time2 = trim((string)($row['delivery_time_2'] ?? '15:00'));
    if (!preg_match('/^\d{2}:\d{2}$/', $time1)) $time1 = '07:00';
    if (!preg_match('/^\d{2}:\d{2}$/', $time2)) $time2 = '15:00';
    $slots = [['slot' => 1, 'time' => $time1]];
    if ($count >= 2) {
        $slots[] = ['slot' => 2, 'time' => $time2];
    }
    return $slots;
}

function merchantCateringDeliveryDateAllowed(array $order, DateTime $date): bool {
    $days = (int)($order['subscription_days'] ?? 30);
    $packageText = strtolower((string)($order['estimated_time'] ?? '') . ' ' . (string)($order['notes'] ?? ''));
    if ($days === 20 || str_contains($packageText, 'weekday')) {
        $weekday = (int)$date->format('N');
        return $weekday <= 5;
    }
    return true;
}

function merchantEnsureCateringDeliveryLogs(mysqli $conn, int $orderId, ?string $date = null): void {
    if (!merchantTableExists($conn, 'catering_delivery_logs')) return;

    $stmt = $conn->prepare("
        SELECT id, merchant_id, user_id, service_type, status, payment_status,
               subscription_days, subscription_start_date, subscription_end_date,
               estimated_time, notes
        FROM orders
        WHERE id = ? AND service_type = 'catering'
        LIMIT 1
    ");
    if (!$stmt) return;
    $stmt->bind_param('i', $orderId);
    $stmt->execute();
    $order = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$order) return;

    $payment = strtolower((string)($order['payment_status'] ?? ''));
    if (($order['status'] ?? '') !== 'accepted' ||
        !in_array($payment, ['paid', 'payment_submitted'], true) ||
        empty($order['subscription_start_date']) ||
        empty($order['subscription_end_date'])) {
        return;
    }

    $target = new DateTime($date ?: date('Y-m-d'));
    $start = new DateTime((string)$order['subscription_start_date']);
    $end = new DateTime((string)$order['subscription_end_date']);
    if ($target < $start || $target > $end || !merchantCateringDeliveryDateAllowed($order, $target)) {
        return;
    }

    $ins = $conn->prepare("
        INSERT IGNORE INTO catering_delivery_logs
            (order_id, merchant_id, user_id, delivery_date, slot_number, scheduled_time, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, 'pending', NOW(), NOW())
    ");
    if (!$ins) return;
    $deliveryDate = $target->format('Y-m-d');
    foreach (merchantCateringDeliverySlots($conn, $orderId) as $slot) {
        $slotNumber = (int)$slot['slot'];
        $scheduledTime = (string)$slot['time'];
        $ins->bind_param(
            'isssis',
            $orderId,
            $order['merchant_id'],
            $order['user_id'],
            $deliveryDate,
            $slotNumber,
            $scheduledTime
        );
        $ins->execute();
    }
    $ins->close();
}

function merchantCateringDeliveryMilestones(mysqli $conn, int $orderId, ?string $date = null): array {
    merchantEnsureCateringDeliveryLogs($conn, $orderId, $date);
    if (!merchantTableExists($conn, 'catering_delivery_logs')) return [];
    $deliveryDate = $date ?: date('Y-m-d');
    $stmt = $conn->prepare("
        SELECT id, delivery_date, slot_number, scheduled_time, status, delivered_at,
               delivery_note, delivery_photo_url
        FROM catering_delivery_logs
        WHERE order_id = ? AND delivery_date = ?
        ORDER BY slot_number ASC
    ");
    if (!$stmt) return [];
    $stmt->bind_param('is', $orderId, $deliveryDate);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return array_map(fn($row) => [
        'id' => (string)($row['id'] ?? ''),
        'date' => $row['delivery_date'] ?? $deliveryDate,
        'slotNumber' => (int)($row['slot_number'] ?? 1),
        'scheduledTime' => $row['scheduled_time'] ?? '',
        'status' => $row['status'] ?? 'pending',
        'deliveredAt' => !empty($row['delivered_at']) ? date(DATE_ATOM, strtotime($row['delivered_at'])) : null,
        'deliveryNote' => $row['delivery_note'] ?? '',
        'deliveryPhotoUrl' => $row['delivery_photo_url'] ?? '',
    ], $rows);
}

function merchantMilestonesCompleted(array $milestones): bool {
    if (empty($milestones)) return false;
    foreach ($milestones as $milestone) {
        if (($milestone['status'] ?? '') !== 'delivered') {
            return false;
        }
    }
    return true;
}

function merchantRepairCateringDeliveryLogDates(mysqli $conn): void {
    if (!merchantTableExists($conn, 'catering_delivery_logs')) return;

    $conn->query("
        UPDATE catering_delivery_logs today_log
        INNER JOIN catering_delivery_logs shifted_log
            ON shifted_log.order_id = today_log.order_id
           AND shifted_log.slot_number = today_log.slot_number
           AND shifted_log.delivery_date = DATE_SUB(CURDATE(), INTERVAL 1 DAY)
           AND DATE(COALESCE(shifted_log.delivered_at, shifted_log.created_at)) = CURDATE()
           AND shifted_log.status = 'delivered'
        SET today_log.status = 'delivered',
            today_log.delivered_at = COALESCE(shifted_log.delivered_at, today_log.delivered_at, NOW()),
            today_log.updated_at = NOW()
        WHERE today_log.delivery_date = CURDATE()
          AND today_log.status <> 'delivered'
    ");

    $conn->query("
        INSERT IGNORE INTO catering_delivery_logs
            (order_id, merchant_id, user_id, delivery_date, slot_number, scheduled_time, status, delivered_at, created_at, updated_at)
        SELECT shifted_log.order_id, shifted_log.merchant_id, shifted_log.user_id, CURDATE(),
               shifted_log.slot_number, shifted_log.scheduled_time, shifted_log.status,
               shifted_log.delivered_at, shifted_log.created_at, NOW()
        FROM catering_delivery_logs shifted_log
        WHERE shifted_log.delivery_date = DATE_SUB(CURDATE(), INTERVAL 1 DAY)
          AND DATE(COALESCE(shifted_log.delivered_at, shifted_log.created_at)) = CURDATE()
          AND shifted_log.status = 'delivered'
    ");
}

function userSyncCateringSubscribersForUser(mysqli $conn, string $userId): void {
    if (!merchantTableExists($conn, 'orders')) {
        return;
    }
    $stmt = $conn->prepare("
        SELECT id
        FROM orders
        WHERE user_id = ?
          AND service_type = 'catering'
          AND subscription_days IS NOT NULL
        ORDER BY created_at DESC
    ");
    if (!$stmt) {
        return;
    }
    $stmt->bind_param('s', $userId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    foreach ($rows as $row) {
        merchantSyncCateringSubscriber($conn, (int)($row['id'] ?? 0));
    }
}

function merchantCurrent(mysqli $conn, array $payload): array {
    merchantEnsureSchema($conn);

    $userId = (string)($payload['sub'] ?? '');
    if ($userId === '') {
        merchantSendJson(false, null, 'User tidak valid', 401);
    }

    $stmt = $conn->prepare("
        SELECT m.*, u.email, u.display_name
        FROM merchants m
        INNER JOIN users u ON u.id = m.user_id
        WHERE m.user_id = ?
        LIMIT 1
    ");
    if ($stmt) {
        $stmt->bind_param('s', $userId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if ($row) return $row;
    }

    $merchantId = merchantUuid();
    $businessName = trim((string)($payload['displayName'] ?? 'Merchant'));
    $type = strtolower((string)($payload['merchantType'] ?? 'laundry'));
    if (!in_array($type, ['laundry', 'catering'], true)) {
        $type = 'laundry';
    }

    $ins = $conn->prepare("
        INSERT INTO merchants (id, user_id, business_name, merchant_type, merchant_code, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, NOW(), NOW())
    ");
    if (!$ins) {
        merchantSendJson(false, null, 'Gagal membuat profil merchant', 500);
    }
    $code = 'M-' . strtoupper(substr(str_replace('-', '', $merchantId), 0, 8));
    $ins->bind_param('sssss', $merchantId, $userId, $businessName, $type, $code);
    $ins->execute();
    $ins->close();

    return merchantCurrent($conn, $payload);
}

function merchantTypeFromRow(array $merchant): string {
    $type = strtolower((string)($merchant['merchant_type'] ?? $merchant['merchantType'] ?? 'laundry'));
    return in_array($type, ['laundry', 'catering'], true) ? $type : 'laundry';
}

function merchantStatusGroup(string $status): string {
    return match ($status) {
        'pending' => 'pending',
        'done' => 'done',
        default => 'processing',
    };
}

function merchantOrderGroup(array $row): string {
    $serviceType = strtolower((string)($row['service_type'] ?? $row['merchant_type'] ?? ''));
    $status = strtolower((string)($row['status'] ?? 'pending'));
    $payment = strtolower((string)($row['payment_status'] ?? ''));
    if ($payment === 'cancelled') return 'cancelled';
    if ($status === 'done') return 'done';
    if ($serviceType !== 'catering') return merchantStatusGroup($status);
    if ($status === 'pending') return 'pending';
    if ($status === 'accepted' && !in_array($payment, ['paid', 'payment_submitted'], true)) {
        return 'waiting_payment';
    }
    return 'today_delivery';
}

function merchantStatusLabel(string $status): string {
    return match ($status) {
        'pending' => 'Pending',
        'accepted' => 'Diterima',
        'processing' => 'Diproses',
        'delivered' => 'Pengiriman',
        'done' => 'Selesai',
        default => ucfirst($status),
    };
}

function merchantOrderDisplayStatusLabel(array $row): string {
    return match (merchantOrderGroup($row)) {
        'cancelled' => 'Dibatalkan',
        'waiting_payment' => 'Menunggu bayar',
        'today_delivery' => 'Pengantaran hari ini',
        default => merchantStatusLabel((string)($row['status'] ?? 'pending')),
    };
}

function merchantPaymentMethodLabel(?string $method): string {
    $key = strtolower(trim((string)$method));
    return match ($key) {
        'bca' => 'Transfer Bank BCA',
        'mandiri' => 'Transfer Bank Mandiri',
        'bni' => 'Transfer Bank BNI',
        'cimb' => 'Transfer Bank CIMB Niaga',
        'gopay' => 'GoPay',
        'ovo' => 'QRIS (OVO)',
        'dana' => 'QRIS (DANA)',
        'shopeepay' => 'ShopeePay',
        'linkaja' => 'QRIS (LinkAja)',
        'qris' => 'QRIS',
        'cod', 'cash' => 'Bayar di Tempat (COD)',
        default => $method !== '' ? ucwords(str_replace('_', ' ', $key)) : 'Belum dipilih',
    };
}

function merchantPaymentStatusLabel(?string $status, ?string $method = null, ?float $totalAmount = null, ?string $serviceType = null): string {
    $normalized = strtolower(trim((string)$status));
    $methodNormalized = strtolower(trim((string)$method));
    $isCod = str_contains($methodNormalized, 'cod') || str_contains($methodNormalized, 'cash');
    if ($isCod && !in_array($normalized, ['paid', 'cancelled'], true)) {
        return 'Belum dibayar';
    }
    if (($serviceType ?? '') === 'laundry' &&
        in_array($normalized, ['waiting_payment', 'unpaid'], true) &&
        $totalAmount !== null &&
        $totalAmount > 0) {
        return 'Siap dibayar user';
    }
    return match ($normalized) {
        'paid', 'payment_submitted' => 'Pembayaran masuk',
        'awaiting_weighing' => 'Menunggu penimbangan',
        'waiting_payment', 'unpaid' => 'Menunggu pembayaran',
        'cancelled' => 'Pembayaran batal',
        default => 'Menunggu pembayaran',
    };
}

function merchantNormalizePricingType(?string $raw): string {
    $value = strtolower(trim((string)$raw));
    $value = str_replace(['-', ' '], '_', $value);
    return match ($value) {
        'per_item', 'item' => 'per_item',
        'flat', 'flat_price', 'fixed' => 'flat',
        default => 'per_kg',
    };
}

function merchantPricingUnit(string $pricingType): string {
    return match (merchantNormalizePricingType($pricingType)) {
        'per_item' => '/item',
        'flat' => 'fixed',
        default => '/kg',
    };
}

function merchantPricingTypeLabel(string $pricingType): string {
    return match (merchantNormalizePricingType($pricingType)) {
        'per_item' => 'Per Item',
        'flat' => 'Flat Price',
        default => 'Per Kg',
    };
}

function merchantNormalizeDurationUnit(?string $raw): string {
    $value = strtolower(trim((string)$raw));
    return in_array($value, ['hour', 'hours', 'jam'], true) ? 'hour' : 'day';
}

function merchantDurationHours(?int $value, ?string $unit): int {
    $duration = max(0, (int)($value ?? 0));
    if ($duration <= 0) return 0;
    return merchantNormalizeDurationUnit($unit) === 'hour' ? $duration : $duration * 24;
}

function merchantDurationLabel(?int $value, ?string $unit): string {
    $duration = max(0, (int)($value ?? 0));
    if ($duration <= 0) return '';
    return $duration . ' ' . (merchantNormalizeDurationUnit($unit) === 'hour' ? 'Jam' : 'Hari');
}

function merchantEstimatedFinishAt(?string $createdAt, ?int $durationValue, ?string $durationUnit): ?string {
    $hours = merchantDurationHours($durationValue, $durationUnit);
    if ($hours <= 0) return null;
    $base = $createdAt && trim($createdAt) !== '' ? strtotime($createdAt) : time();
    if (!$base) $base = time();
    return date('Y-m-d H:i:s', $base + ($hours * 3600));
}

function merchantLaundryAddonPayload(array $row): array {
    $pricingType = merchantNormalizePricingType($row['pricing_type'] ?? 'flat');
    return [
        'id' => (string)($row['id'] ?? ''),
        'name' => (string)($row['name'] ?? ''),
        'price' => (float)($row['price'] ?? 0),
        'pricingType' => $pricingType,
        'pricingTypeLabel' => merchantPricingTypeLabel($pricingType),
        'unit' => merchantPricingUnit($pricingType),
        'isActive' => (int)($row['is_active'] ?? 1) === 1,
    ];
}

function merchantProductAddons(mysqli $conn, int $productId, bool $activeOnly = true): array {
    if ($productId <= 0 || !merchantTableExists($conn, 'laundry_service_addons')) {
        return [];
    }
    $where = 'product_id = ?';
    if ($activeOnly) {
        $where .= ' AND is_active = 1';
    }
    $stmt = $conn->prepare("
        SELECT *
        FROM laundry_service_addons
        WHERE $where
        ORDER BY is_active DESC, id ASC
    ");
    if (!$stmt) return [];
    $stmt->bind_param('i', $productId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return array_map('merchantLaundryAddonPayload', $rows);
}

function merchantSyncProductAddons(mysqli $conn, string $merchantId, int $productId, array $addons): void {
    if ($productId <= 0 || !merchantTableExists($conn, 'laundry_service_addons')) {
        return;
    }

    $incomingIds = [];
    foreach ($addons as $addon) {
        if (!is_array($addon)) continue;
        $id = (int)($addon['id'] ?? 0);
        $name = trim((string)($addon['name'] ?? ''));
        $price = (float)($addon['price'] ?? 0);
        $pricingType = merchantNormalizePricingType($addon['pricingType'] ?? $addon['pricing_type'] ?? 'flat');
        if ($name === '' || $price <= 0) continue;

        if ($id > 0) {
            $stmt = $conn->prepare("
                UPDATE laundry_service_addons
                SET name = ?, price = ?, pricing_type = ?, is_active = 1, updated_at = NOW()
                WHERE id = ? AND product_id = ? AND merchant_id = ?
            ");
            if ($stmt) {
                $stmt->bind_param('sdsiis', $name, $price, $pricingType, $id, $productId, $merchantId);
                $stmt->execute();
                $stmt->close();
                $incomingIds[] = $id;
            }
            continue;
        }

        $stmt = $conn->prepare("
            INSERT INTO laundry_service_addons
                (merchant_id, product_id, name, price, pricing_type, is_active, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, 1, NOW(), NOW())
        ");
        if ($stmt) {
            $stmt->bind_param('sisds', $merchantId, $productId, $name, $price, $pricingType);
            $stmt->execute();
            $incomingIds[] = (int)$conn->insert_id;
            $stmt->close();
        }
    }

    if (empty($incomingIds)) {
        $stmt = $conn->prepare("
            UPDATE laundry_service_addons
            SET is_active = 0, updated_at = NOW()
            WHERE product_id = ? AND merchant_id = ?
        ");
        if ($stmt) {
            $stmt->bind_param('is', $productId, $merchantId);
            $stmt->execute();
            $stmt->close();
        }
        return;
    }

    $ids = implode(',', array_map('intval', array_unique($incomingIds)));
    $conn->query("
        UPDATE laundry_service_addons
        SET is_active = 0, updated_at = NOW()
        WHERE product_id = " . (int)$productId . "
          AND merchant_id = '" . $conn->real_escape_string($merchantId) . "'
          AND id NOT IN ($ids)
    ");
}

function merchantLaundryOrderAddons(mysqli $conn, int $orderId): array {
    if ($orderId <= 0 || !merchantTableExists($conn, 'laundry_order_addons')) {
        return [];
    }
    $stmt = $conn->prepare("
        SELECT *
        FROM laundry_order_addons
        WHERE order_id = ?
        ORDER BY id ASC
    ");
    if (!$stmt) return [];
    $stmt->bind_param('i', $orderId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    return array_map(function ($row) {
        $pricingType = merchantNormalizePricingType($row['pricing_type'] ?? 'flat');
        return [
            'id' => (string)($row['addon_id'] ?? $row['id'] ?? ''),
            'name' => (string)($row['name'] ?? ''),
            'price' => (float)($row['price'] ?? 0),
            'pricingType' => $pricingType,
            'pricingTypeLabel' => merchantPricingTypeLabel($pricingType),
            'unit' => merchantPricingUnit($pricingType),
            'quantity' => (float)($row['qty'] ?? 1),
            'subtotal' => (float)($row['subtotal'] ?? 0),
            'isActive' => true,
        ];
    }, $rows);
}

function merchantLaundryStatusLabel(array $row): string {
    $status = strtolower((string)($row['status'] ?? 'pending'));
    $payment = strtolower((string)($row['payment_status'] ?? ''));
    $total = (float)($row['total_harga'] ?? 0);

    if ($payment === 'cancelled') return 'Dibatalkan';
    if ($status === 'pending') return 'Menunggu Konfirmasi';
    if ($status === 'done') return 'Selesai';
    if ($status === 'delivered') return 'Siap Diantar';
    if ($status === 'processing') return 'Diproses';
    if ($status === 'accepted' && ($payment === 'awaiting_weighing' || $total <= 0)) {
        return 'Menunggu Penimbangan';
    }
    if ($status === 'accepted' && in_array($payment, ['waiting_payment', 'unpaid'], true)) {
        return 'Menunggu Pembayaran';
    }
    if ($status === 'accepted') return 'Diterima';
    return merchantStatusLabel($status);
}

function merchantFinalizeLaundryOrder(
    mysqli $conn,
    int $orderId,
    string $merchantId,
    float $weightKg,
    float $manualTotalAmount = 0.0,
    array $addonIds = []
): void {
    if ($weightKg <= 0) {
        merchantSendJson(false, null, 'Berat aktual wajib diisi', 400);
    }

    $stmt = $conn->prepare("
        SELECT id, service_type, payment_status, user_id, payment_method, total_harga
        FROM orders
        WHERE id = ? AND merchant_id = ?
        LIMIT 1
    ");
    if (!$stmt) {
        merchantSendJson(false, null, 'Database error', 500);
    }
    $stmt->bind_param('is', $orderId, $merchantId);
    $stmt->execute();
    $order = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$order || ($order['service_type'] ?? '') !== 'laundry') {
        merchantSendJson(false, null, 'Pesanan laundry tidak ditemukan', 404);
    }

    $paymentStatus = strtolower((string)($order['payment_status'] ?? ''));
    if ($paymentStatus !== 'awaiting_weighing' && (float)($order['total_harga'] ?? 0) > 0) {
        merchantSendJson(false, null, 'Total pembayaran sudah ditentukan', 400);
    }

    $conn->begin_transaction();
    try {
        $itemStmt = $conn->prepare("
            SELECT oi.id, oi.product_id, oi.harga,
                   p.harga AS product_price, p.pricing_type, p.nama_produk
            FROM order_items oi
            LEFT JOIN products p ON p.id = oi.product_id
            WHERE oi.order_id = ?
            ORDER BY oi.id ASC
            LIMIT 1
        ");
        if (!$itemStmt) {
            throw new Exception($conn->error);
        }
        $itemStmt->bind_param('i', $orderId);
        $itemStmt->execute();
        $item = $itemStmt->get_result()->fetch_assoc();
        $itemStmt->close();

        if (!$item) {
            throw new Exception('Item layanan laundry tidak ditemukan');
        }

        $itemId = (int)$item['id'];
        $productId = (int)($item['product_id'] ?? 0);
        $servicePrice = (float)($item['product_price'] ?? $item['harga'] ?? 0);
        $servicePricingType = merchantNormalizePricingType($item['pricing_type'] ?? 'per_kg');
        $serviceQty = $servicePricingType === 'per_kg' ? $weightKg : 1.0;
        $serviceSubtotal = round($servicePrice * $serviceQty, 2);

        if ($manualTotalAmount > 0 && $serviceSubtotal <= 0) {
            $serviceSubtotal = $manualTotalAmount;
        }
        if ($serviceSubtotal <= 0) {
            throw new Exception('Subtotal layanan laundry tidak valid');
        }

        $displayQty = 1;
        $updateItem = $conn->prepare("
            UPDATE order_items SET qty = ?, harga = ?, updated_at = NOW() WHERE id = ?
        ");
        if (!$updateItem) {
            throw new Exception($conn->error);
        }
        $updateItem->bind_param('idi', $displayQty, $serviceSubtotal, $itemId);
        $updateItem->execute();
        $updateItem->close();

        $subtotal = $serviceSubtotal;
        $selectedAddonIds = array_values(array_filter(array_unique(array_map('intval', $addonIds)), fn($id) => $id > 0));
        if (merchantTableExists($conn, 'laundry_order_addons')) {
            $conn->query('DELETE FROM laundry_order_addons WHERE order_id = ' . (int)$orderId);
        }
        if (!empty($selectedAddonIds) && merchantTableExists($conn, 'laundry_service_addons')) {
            $idsSql = implode(',', $selectedAddonIds);
            $addonsResult = $conn->query("
                SELECT *
                FROM laundry_service_addons
                WHERE merchant_id = '" . $conn->real_escape_string($merchantId) . "'
                  AND product_id = " . (int)$productId . "
                  AND is_active = 1
                  AND id IN ($idsSql)
                ORDER BY id ASC
            ");
            if ($addonsResult) {
                $insertAddon = $conn->prepare("
                    INSERT INTO laundry_order_addons
                        (order_id, addon_id, name, price, pricing_type, qty, subtotal, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
                ");
                if (!$insertAddon) {
                    throw new Exception($conn->error);
                }
                while ($addon = $addonsResult->fetch_assoc()) {
                    $addonId = (int)($addon['id'] ?? 0);
                    $name = (string)($addon['name'] ?? '');
                    $price = (float)($addon['price'] ?? 0);
                    $pricingType = merchantNormalizePricingType($addon['pricing_type'] ?? 'flat');
                    $qty = $pricingType === 'per_kg' ? $weightKg : 1.0;
                    $lineSubtotal = round($price * $qty, 2);
                    if ($lineSubtotal <= 0) continue;
                    $insertAddon->bind_param(
                        'iisdsdd',
                        $orderId,
                        $addonId,
                        $name,
                        $price,
                        $pricingType,
                        $qty,
                        $lineSubtotal
                    );
                    $insertAddon->execute();
                    $subtotal += $lineSubtotal;
                }
                $insertAddon->close();
            }
        }

        // Setelah subtotal final diketahui, promo baru dihitung.
        $userId = (string)($order['user_id'] ?? '');
        $promoId = null;
        $promoName = null;
        $promoDiscountAmount = 0.0;
        $finalTotal = $subtotal;

        $items = $productId > 0 ? [['productId' => $productId]] : [];

        if (!empty($items) && $subtotal > 0) {
            $bestPromo = merchantBestPromoForCheckout($conn, $merchantId, $userId, $subtotal, $items);
            if ($bestPromo !== null) {
                $promoId = (int)($bestPromo['promo']['id'] ?? 0);
                $promoName = (string)($bestPromo['promo']['name'] ?? '');
                $promoDiscountAmount = (float)($bestPromo['discount'] ?? 0);
                $finalTotal = max(0, (float)($bestPromo['total'] ?? $subtotal));
            }
        }

        // Lock promo row and revalidate quota + per-user usage to avoid race.
        if ($promoId !== null && $promoId > 0) {
            $lock = $conn->prepare('SELECT * FROM merchant_promos WHERE id = ? AND merchant_id = ? FOR UPDATE');
            if (!$lock) throw new Exception($conn->error);
            $lock->bind_param('is', $promoId, $merchantId);
            $lock->execute();
            $lockedPromo = $lock->get_result()->fetch_assoc();
            $lock->close();

            $now = time();
            $lockedIsActive = (int)($lockedPromo['is_active'] ?? 0) === 1;
            $lockedStartAt = $lockedPromo['start_at'] ?? null;
            $lockedEndAt = $lockedPromo['end_at'] ?? null;
            $lockedIsLive = $lockedIsActive &&
                (!$lockedStartAt || strtotime((string)$lockedStartAt) <= $now) &&
                (!$lockedEndAt || strtotime((string)$lockedEndAt) >= $now);

            $lockedUsageLimit = isset($lockedPromo['usage_limit']) ? (int)$lockedPromo['usage_limit'] : null;
            $lockedUsedCount = (int)($lockedPromo['used_count'] ?? 0);
            $lockedGlobalOk = $lockedUsageLimit === null || $lockedUsageLimit <= 0 || $lockedUsedCount < $lockedUsageLimit;

            $lockedPerUserLimit = max(1, (int)($lockedPromo['per_user_usage_limit'] ?? 1));
            $lockedUserUsageCount = 0;
            if ($userId !== '') {
                $lockedUserUsageCount = (int)merchantQueryValue(
                    $conn,
                    'SELECT COUNT(*) FROM promo_usages WHERE promo_id = ? AND user_id = ?',
                    'is',
                    [(int)($lockedPromo['id'] ?? 0), $userId]
                );
            }
            $lockedUserOk = $userId === '' || $lockedUserUsageCount < $lockedPerUserLimit;

            $productIds = array_values(array_filter(array_map(
                fn($it) => (int)($it['productId'] ?? 0),
                $items
            ), fn($id) => $id > 0));
            $lockedMatchOk = !empty($productIds) && merchantPromoMatchesProducts($conn, $lockedPromo, $productIds);

            if (!$lockedPromo || !$lockedIsLive || !$lockedGlobalOk || !$lockedUserOk || !$lockedMatchOk) {
                $promoId = null;
                $promoName = null;
                $promoDiscountAmount = 0.0;
                $finalTotal = $subtotal;
            } else {
                $applied = merchantPromoApply($subtotal, $lockedPromo);
                $promoDiscountAmount = (float)($applied['discount'] ?? 0);
                if ($promoDiscountAmount <= 0) {
                    $promoId = null;
                    $promoName = null;
                    $promoDiscountAmount = 0.0;
                    $finalTotal = $subtotal;
                } else {
                    $promoName = (string)($lockedPromo['name'] ?? '');
                    $finalTotal = max(0, (float)($applied['total'] ?? $subtotal));
                }
            }
        }

        $method = merchantQueryValue(
            $conn,
            'SELECT payment_method FROM orders WHERE id = ?',
            'i',
            [$orderId]
        );
        $methodText = strtolower((string)$method);
        $nextPayment = (str_contains($methodText, 'cod') || str_contains($methodText, 'cash'))
            ? 'cod'
            : 'waiting_payment';

        $updateOrder = $conn->prepare("
            UPDATE orders
            SET total_harga = ?,
                subtotal_amount = ?,
                promo_id = ?,
                promo_name = ?,
                promo_discount_amount = ?,
                payment_status = ?,
                laundry_weight_kg = ?,
                status = CASE WHEN status = 'pending' THEN 'accepted' ELSE status END,
                updated_at = NOW()
            WHERE id = ? AND merchant_id = ?
        ");
        if (!$updateOrder) {
            throw new Exception($conn->error);
        }
        $promoIdDb = $promoId !== null ? (int)$promoId : null;
        $updateOrder->bind_param(
            'ddisdsdis',
            $finalTotal,
            $subtotal,
            $promoIdDb,
            $promoName,
            $promoDiscountAmount,
            $nextPayment,
            $weightKg,
            $orderId,
            $merchantId
        );
        $updateOrder->execute();
        $updateOrder->close();

        $orderCode = (string)merchantQueryValue(
            $conn,
            'SELECT order_code FROM orders WHERE id = ?',
            'i',
            [$orderId]
        );
        if ($promoIdDb !== null) {
            $usage = $conn->prepare("
                INSERT INTO promo_usages (promo_id, user_id, order_id, created_at)
                VALUES (?, ?, ?, NOW())
            ");
            if (!$usage) throw new Exception($conn->error);
            $usage->bind_param('isi', $promoIdDb, $userId, $orderId);
            $usage->execute();
            $usage->close();

            $inc = $conn->prepare("UPDATE merchant_promos SET used_count = used_count + 1, updated_at = NOW() WHERE id = ?");
            if (!$inc) throw new Exception($conn->error);
            $inc->bind_param('i', $promoIdDb);
            $inc->execute();
            $inc->close();
        }

        if ($userId !== '') {
            $amountText = number_format($finalTotal, 0, ',', '.');
            merchantCreateNotification(
                $conn,
                $userId,
                'Total pembayaran telah ditentukan',
                'Pesanan ' . ($orderCode !== '' ? $orderCode : ('#' . $orderId)) .
                    ' sebesar Rp ' . $amountText . ' siap untuk dibayar. Silakan buka detail pesanan.',
                'payment',
                'Bayar sekarang',
                'order:' . $orderId
            );
        }

        $conn->commit();
    } catch (Throwable $e) {
        $conn->rollback();
        merchantSendJson(false, null, 'Gagal menyimpan total laundry. Silakan coba lagi.', 500);
    }
}

function merchantOrderCanApprove(array $row): bool {
    $status = strtolower(trim((string)($row['status'] ?? 'pending')));
    $paymentStatus = strtolower(trim((string)($row['payment_status'] ?? 'waiting_payment')));
    if ($paymentStatus === 'cancelled') return false;
    if ($status !== 'pending') return true;

    $serviceType = strtolower(trim((string)($row['service_type'] ?? $row['merchant_type'] ?? '')));
    if ($serviceType === 'catering') {
        return true;
    }

    $method = strtolower(trim((string)($row['payment_method'] ?? '')));
    if ($paymentStatus === 'awaiting_weighing') {
        return true;
    }
    if (str_contains($method, 'cod') || str_contains($method, 'cash')) {
        return true;
    }
    return in_array($paymentStatus, ['paid', 'payment_submitted'], true);
}

function merchantNextStatus(string $status, bool $catering = false): string {
    if ($catering) {
        return match ($status) {
            'pending' => 'accepted',
            default => $status,
        };
    }
    return match ($status) {
        'pending' => 'accepted',
        'accepted' => 'processing',
        'processing' => 'delivered',
        'delivered' => 'done',
        default => 'done',
    };
}

function merchantProductActivePromoSummary(mysqli $conn, string $merchantId, int $productId, float $price): array {
    if ($merchantId === '' || $productId <= 0 || $price <= 0 || !merchantTableExists($conn, 'merchant_promos')) {
        return ['hasActivePromo' => false, 'activePromoName' => ''];
    }
    $best = merchantBestPromoForCheckout($conn, $merchantId, '', $price, [['productId' => $productId]]);
    if ($best === null || (float)($best['discount'] ?? 0) <= 0) {
        return ['hasActivePromo' => false, 'activePromoName' => ''];
    }
    return [
        'hasActivePromo' => true,
        'activePromoName' => (string)($best['promo']['name'] ?? 'Promo aktif'),
    ];
}

function merchantProductPayload(array $row, ?mysqli $conn = null): array {
    $pricingType = merchantNormalizePricingType($row['pricing_type'] ?? 'per_kg');
    $durationValue = isset($row['duration_value']) ? (int)$row['duration_value'] : null;
    $durationUnit = merchantNormalizeDurationUnit($row['duration_unit'] ?? 'day');
    $productId = (int)($row['id'] ?? 0);
    $merchantId = (string)($row['merchant_id'] ?? '');
    $price = (float)($row['harga'] ?? $row['price'] ?? 0);
    $promo = $conn === null
        ? ['hasActivePromo' => false, 'activePromoName' => '']
        : merchantProductActivePromoSummary($conn, $merchantId, $productId, $price);
    $payload = [
        'id' => (string)($row['id'] ?? ''),
        'merchantId' => $merchantId,
        'name' => $row['nama_produk'] ?? $row['name'] ?? '',
        'description' => $row['deskripsi'] ?? $row['description'] ?? '',
        'price' => $price,
        'price20Days' => isset($row['price_20_days']) ? (float)$row['price_20_days'] : null,
        'category' => $row['category'] ?? '',
        'unit' => merchantPricingUnit($pricingType),
        'pricingType' => $pricingType,
        'pricingTypeLabel' => merchantPricingTypeLabel($pricingType),
        'durationValue' => $durationValue,
        'durationUnit' => $durationUnit,
        'durationLabel' => merchantDurationLabel($durationValue, $durationUnit),
        'imageUrl' => $row['image_url'] ?? $row['imageUrl'] ?? '',
        'isActive' => (int)($row['is_active'] ?? 1) === 1,
        'serviceType' => $row['service_type'] ?? '',
        'packageDeliveryType' => $row['package_delivery_type'] ?? null,
        'mealDeliveryCount' => max(1, min(2, (int)($row['meal_delivery_count'] ?? 1))),
        'deliveryTime1' => $row['delivery_time_1'] ?? '07:00',
        'deliveryTime2' => $row['delivery_time_2'] ?? null,
        'rating' => isset($row['rating']) ? round((float)$row['rating'], 1) : 0.0,
        'reviewCount' => (int)($row['review_count'] ?? 0),
        'addons' => $conn === null ? [] : merchantProductAddons($conn, $productId),
        'hasActivePromo' => (bool)$promo['hasActivePromo'],
        'activePromoName' => (string)$promo['activePromoName'],
    ];
    return $payload;
}

function merchantOrderItems(mysqli $conn, int $orderId): array {
    if (!merchantTableExists($conn, 'order_items')) return [];
    $stmt = $conn->prepare("
        SELECT oi.id, oi.product_id, oi.qty, oi.harga,
               p.nama_produk, p.deskripsi, p.image_url, p.harga AS product_price,
               p.pricing_type, p.unit,
               o.service_type, o.laundry_weight_kg
        FROM order_items oi
        LEFT JOIN orders o ON o.id = oi.order_id
        LEFT JOIN products p ON p.id = oi.product_id
        WHERE oi.order_id = ?
        ORDER BY oi.id ASC
    ");
    if (!$stmt) return [];
    $stmt->bind_param('i', $orderId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $items = array_map(function ($row) {
        $qty = (int)($row['qty'] ?? 0);
        $storedPrice = (float)($row['harga'] ?? 0);
        $productPrice = (float)($row['product_price'] ?? 0);
        $pricingType = merchantNormalizePricingType($row['pricing_type'] ?? 'per_kg');
        $isLaundry = strtolower((string)($row['service_type'] ?? '')) === 'laundry';
        $weight = isset($row['laundry_weight_kg']) ? (float)$row['laundry_weight_kg'] : null;
        $price = $isLaundry && $productPrice > 0 ? $productPrice : $storedPrice;
        $quantityValue = $isLaundry && $weight !== null && $weight > 0
            ? ($pricingType === 'per_kg' ? $weight : 1.0)
            : (float)$qty;
        $subtotal = $isLaundry
            ? ($weight !== null && $weight > 0 ? $storedPrice : 0.0)
            : ($qty * $price);
        return [
            'id' => (string)($row['id'] ?? ''),
            'productId' => (string)($row['product_id'] ?? ''),
            'name' => $row['nama_produk'] ?? 'Item Pesanan',
            'description' => $row['deskripsi'] ?? '',
            'quantity' => $qty,
            'quantityValue' => $quantityValue,
            'price' => $price,
            'subtotal' => $subtotal,
            'imageUrl' => $row['image_url'] ?? '',
            'pricingType' => $pricingType,
            'unit' => merchantPricingUnit($pricingType),
            'isAddon' => false,
        ];
    }, $rows);

    foreach (merchantLaundryOrderAddons($conn, $orderId) as $addon) {
        $quantityValue = (float)($addon['quantity'] ?? 1);
        $items[] = [
            'id' => 'addon-' . (string)($addon['id'] ?? ''),
            'productId' => 'addon:' . (string)($addon['id'] ?? ''),
            'name' => (string)($addon['name'] ?? 'Tambahan Layanan'),
            'description' => 'Tambahan layanan laundry',
            'quantity' => max(1, (int)ceil($quantityValue)),
            'quantityValue' => $quantityValue,
            'price' => (float)($addon['price'] ?? 0),
            'subtotal' => (float)($addon['subtotal'] ?? 0),
            'imageUrl' => '',
            'pricingType' => (string)($addon['pricingType'] ?? 'flat'),
            'unit' => (string)($addon['unit'] ?? 'fixed'),
            'isAddon' => true,
        ];
    }

    return $items;
}

function merchantOrderPayload(mysqli $conn, array $row, bool $withItems = true): array {
    $orderId = (int)($row['id'] ?? 0);
    $items = $withItems ? merchantOrderItems($conn, $orderId) : [];
    $createdAt = $row['created_at'] ?? date(DATE_ATOM);
    $code = $row['order_code'] ?? ('SR-ORDER-' . str_pad((string)$orderId, 6, '0', STR_PAD_LEFT));
    $status = $row['status'] ?? 'pending';
    $serviceType = $row['service_type'] ?? $row['merchant_type'] ?? 'laundry';
    $firstItem = $items[0]['name'] ??
        ($row['first_product_name'] ?? ($serviceType === 'laundry' ? 'Layanan Laundry' : 'Paket Catering'));
    $deliveryMilestones = $serviceType === 'catering'
        ? merchantCateringDeliveryMilestones($conn, $orderId)
        : [];
    $statusGroup = merchantOrderGroup($row);
    $statusLabel = merchantOrderDisplayStatusLabel($row);
    if ($statusGroup === 'today_delivery' && merchantMilestonesCompleted($deliveryMilestones)) {
        $statusGroup = 'done';
        $statusLabel = 'Selesai';
    }
    $firstProductId = isset($items[0]['productId']) && ctype_digit((string)$items[0]['productId'])
        ? (int)$items[0]['productId']
        : 0;
    $estimatedFinishAt = $row['estimated_finish_at'] ?? null;
    $selectedLaundryAddons = $serviceType === 'laundry'
        ? merchantLaundryOrderAddons($conn, $orderId)
        : [];

    return [
        'id' => (string)$orderId,
        'code' => $code,
        'customerUserId' => (string)($row['user_id'] ?? ''),
        'customerName' => $row['customer_name'] ?? 'Pelanggan',
        'customerPhone' => $row['customer_phone'] ?? '',
        'customerEmail' => $row['customer_email'] ?? '',
        'serviceType' => $serviceType,
        'serviceName' => $firstItem,
        'createdAt' => date(DATE_ATOM, strtotime($createdAt)),
        'estimatedTime' => $row['estimated_time'] ?? '',
        'estimatedFinishAt' => !empty($estimatedFinishAt) ? date(DATE_ATOM, strtotime($estimatedFinishAt)) : null,
        'status' => $status,
        'statusLabel' => $statusLabel,
        'statusGroup' => $statusGroup,
        'deliveryAddress' => $row['delivery_address'] ?? '',
        'deliveryLatitude' => isset($row['delivery_latitude']) ? (float)$row['delivery_latitude'] : null,
        'deliveryLongitude' => isset($row['delivery_longitude']) ? (float)$row['delivery_longitude'] : null,
        'totalAmount' => (float)($row['total_harga'] ?? 0),
        'subtotalAmount' => (float)($row['subtotal_amount'] ?? 0),
        'promoName' => $row['promo_name'] ?? '',
        'promoDiscountAmount' => (float)($row['promo_discount_amount'] ?? 0),
        'actualWeight' => isset($row['laundry_weight_kg']) ? (float)$row['laundry_weight_kg'] : null,
        'paymentMethod' => $row['payment_method'] ?? '',
        'paymentStatus' => $row['payment_status'] ?? '',
        'paymentMethodLabel' => merchantPaymentMethodLabel($row['payment_method'] ?? null),
        'paymentStatusLabel' => merchantPaymentStatusLabel(
            $row['payment_status'] ?? null,
            $row['payment_method'] ?? null,
            (float)($row['total_harga'] ?? 0),
            $serviceType
        ),
        'paidAt' => !empty($row['paid_at']) ? date(DATE_ATOM, strtotime((string)$row['paid_at'])) : null,
        'serviceEstimateLabel' => $serviceType === 'laundry'
            ? (string)($row['estimated_time'] ?? '')
            : '',
        'midtransOrderId' => $row['midtrans_order_id'] ?? null,
        'subscriptionDays' => isset($row['subscription_days']) ? (int)$row['subscription_days'] : null,
        'subscriptionStartDate' => !empty($row['subscription_start_date']) ? date(DATE_ATOM, strtotime($row['subscription_start_date'])) : null,
        'subscriptionEndDate' => !empty($row['subscription_end_date']) ? date(DATE_ATOM, strtotime($row['subscription_end_date'])) : null,
        'subscriptionStatus' => $row['subscription_status'] ?? null,
        'cancellationRequestedAt' => !empty($row['cancellation_requested_at']) ? date(DATE_ATOM, strtotime($row['cancellation_requested_at'])) : null,
        'canApprove' => merchantOrderCanApprove($row),
        'notes' => $row['notes'] ?? '',
        'availableAddons' => $serviceType === 'laundry' && $firstProductId > 0
            ? merchantProductAddons($conn, $firstProductId)
            : [],
        'selectedAddons' => $selectedLaundryAddons,
        'items' => $items,
        'deliveryMilestones' => $deliveryMilestones,
    ];
}

function merchantOrderQuery(mysqli $conn, string $merchantId, ?string $id = null, ?string $statusGroup = null, ?string $search = null, int $limit = 0): array {
    $hasUserPhone = merchantColumnExists($conn, 'users', 'phone');
    $where = ['o.merchant_id = ?'];
    $types = 's';
    $params = [$merchantId];

    if ($id !== null && $id !== '') {
        $where[] = '(CAST(o.id AS CHAR) = ? OR o.order_code = ?)';
        $types .= 'ss';
        $params[] = $id;
        $params[] = $id;
    } else {
        $where[] = "(COALESCE(o.extension_parent_order_id, 0) = 0 OR o.status <> 'done')";
    }

    if ($statusGroup === 'pending') {
        $where[] = "o.status = 'pending' AND COALESCE(o.payment_status, '') <> 'cancelled'";
    } elseif ($statusGroup === 'waiting_payment') {
        $where[] = "o.service_type = 'catering' AND o.status = 'accepted' AND COALESCE(o.payment_status, '') NOT IN ('paid','payment_submitted','cancelled')";
    } elseif ($statusGroup === 'today_delivery') {
        $where[] = "
            o.service_type = 'catering'
            AND o.status = 'accepted'
            AND COALESCE(o.payment_status, '') IN ('paid','payment_submitted')
            AND o.subscription_start_date <= CURDATE()
            AND o.subscription_end_date >= CURDATE()
            AND NOT (
                (o.subscription_days = 20 OR LOWER(CONCAT(COALESCE(o.estimated_time, ''), ' ', COALESCE(o.notes, ''))) LIKE '%weekday%')
                AND DAYOFWEEK(CURDATE()) IN (1, 7)
            )
            AND NOT (
                EXISTS (
                    SELECT 1 FROM catering_delivery_logs cdl
                    WHERE cdl.order_id = o.id
                      AND cdl.delivery_date = CURDATE()
                )
                AND NOT EXISTS (
                    SELECT 1 FROM catering_delivery_logs cdl
                    WHERE cdl.order_id = o.id
                      AND cdl.delivery_date = CURDATE()
                      AND cdl.status <> 'delivered'
                )
            )
        ";
    } elseif ($statusGroup === 'processing') {
        $where[] = "o.status IN ('accepted','processing','delivered')";
    } elseif ($statusGroup === 'done') {
        $where[] = "
            (
                o.status = 'done'
                OR (
                    o.service_type = 'catering'
                    AND o.status = 'accepted'
                    AND COALESCE(o.payment_status, '') IN ('paid','payment_submitted')
                    AND o.subscription_start_date <= CURDATE()
                    AND o.subscription_end_date >= CURDATE()
                    AND NOT (
                        (o.subscription_days = 20 OR LOWER(CONCAT(COALESCE(o.estimated_time, ''), ' ', COALESCE(o.notes, ''))) LIKE '%weekday%')
                        AND DAYOFWEEK(CURDATE()) IN (1, 7)
                    )
                    AND EXISTS (
                        SELECT 1 FROM catering_delivery_logs cdl
                        WHERE cdl.order_id = o.id
                          AND cdl.delivery_date = CURDATE()
                    )
                    AND NOT EXISTS (
                        SELECT 1 FROM catering_delivery_logs cdl
                        WHERE cdl.order_id = o.id
                          AND cdl.delivery_date = CURDATE()
                          AND cdl.status <> 'delivered'
                    )
                )
            )
        ";
    }

    if ($search !== null && trim($search) !== '') {
        $needle = '%' . trim($search) . '%';
        $where[] = '(o.order_code LIKE ? OR u.display_name LIKE ?)';
        $types .= 'ss';
        $params[] = $needle;
        $params[] = $needle;
    }

    $sql = "
        SELECT o.*, COALESCE(NULLIF(o.customer_name, ''), u.display_name) AS customer_name, u.email AS customer_email,
               COALESCE(NULLIF(o.customer_phone, ''), " . ($hasUserPhone ? "u.phone" : "NULL") . ") AS customer_phone,
               m.merchant_type,
               (
                   SELECT p.nama_produk
                   FROM order_items oi
                   LEFT JOIN products p ON p.id = oi.product_id
                   WHERE oi.order_id = o.id
                   ORDER BY oi.id ASC
                   LIMIT 1
               ) AS first_product_name
        FROM orders o
        INNER JOIN users u ON u.id = o.user_id
        INNER JOIN merchants m ON m.id = o.merchant_id
        WHERE " . implode(' AND ', $where) . "
        ORDER BY o.created_at DESC, o.id DESC
    ";
    if ($limit > 0) {
        $sql .= " LIMIT " . (int)$limit;
    }

    $stmt = $conn->prepare($sql);
    if (!$stmt) return [];
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $withItems = $id !== null && $id !== '';
    return array_map(fn($row) => merchantOrderPayload($conn, $row, $withItems), $rows);
}

function merchantPromoPayload(array $row): array {
    $now = time();
    $startAt = $row['start_at'] ?? null;
    $endAt = $row['end_at'] ?? null;
    $isActive = (int)($row['is_active'] ?? 1) === 1;
    $rawStatus = strtolower(trim((string)($row['status'] ?? '')));
    $hasStarted = $startAt && strtotime($startAt) <= $now;
    $hasEnded = $endAt && strtotime($endAt) < $now;
    $isLive = $isActive && !$hasEnded && (!$startAt || $hasStarted);

    $usageLimit = isset($row['usage_limit']) ? (int)$row['usage_limit'] : null;
    $usedCount = (int)($row['used_count'] ?? 0);
    $isFull = $usageLimit !== null && $usageLimit > 0 && $usedCount >= $usageLimit;

    if ($rawStatus === 'expired' || $hasEnded || $isFull) {
        $status = 'expired';
        $isActive = false;
    } elseif (!$isActive && in_array($rawStatus, ['inactive', 'paused'], true)) {
        $status = 'inactive';
    } elseif (!$isActive) {
        $status = 'draft';
    } elseif ($isLive) {
        $status = 'active';
    } else {
        $status = 'draft';
    }

    return [
        'id' => (string)($row['id'] ?? ''),
        'merchantId' => (string)($row['merchant_id'] ?? ''),
        'productId' => isset($row['product_id']) ? (string)$row['product_id'] : '',
        'productName' => $row['nama_produk'] ?? $row['productName'] ?? 'Semua produk',
        'name' => $row['name'] ?? '',
        'description' => $row['description'] ?? '',
        'discountType' => $row['discount_type'] ?? 'percentage',
        'discountValue' => (float)($row['discount_value'] ?? 0),
        'minOrderAmount' => (float)($row['min_order_amount'] ?? 0),
        'maxDiscountAmount' => (float)($row['max_discount_amount'] ?? 0),
        'startAt' => $startAt ? date(DATE_ATOM, strtotime($startAt)) : null,
        'endAt' => $endAt ? date(DATE_ATOM, strtotime($endAt)) : null,
        'isActive' => $isActive,
        'status' => $status,
        'usageLimit' => isset($row['usage_limit']) ? (int)$row['usage_limit'] : null,
        'usedCount' => (int)($row['used_count'] ?? 0),
        'perUserUsageLimit' => max(1, (int)($row['per_user_usage_limit'] ?? 1)),
    ];
}


function merchantExpirePromos(mysqli $conn, ?string $merchantId = null): void {
    if (!merchantTableExists($conn, 'merchant_promos') ||
        !merchantColumnExists($conn, 'merchant_promos', 'status')) {
        return;
    }

    if ($merchantId !== null && $merchantId !== '') {
        $stmt = $conn->prepare("
            UPDATE merchant_promos
            SET status = 'expired',
                is_active = 0,
                updated_at = NOW()
            WHERE merchant_id = ?
              AND end_at IS NOT NULL
              AND end_at < NOW()
              AND status <> 'expired'
        ");
        if ($stmt) {
            $stmt->bind_param('s', $merchantId);
            $stmt->execute();
            $stmt->close();
        }
        
        $stmt = $conn->prepare("
            UPDATE merchant_promos
            SET status = 'active',
                is_active = 1,
                updated_at = NOW()
            WHERE merchant_id = ?
              AND status = 'draft'
              AND start_at IS NOT NULL
              AND start_at <= NOW()
              AND (end_at IS NULL OR end_at > NOW())
              AND discount_value > 0
              AND name != '' AND name != 'Draft Promo'
        ");
        if ($stmt) {
            $stmt->bind_param('s', $merchantId);
            $stmt->execute();
            $stmt->close();
        }
        
        return;
    }

    $conn->query("
        UPDATE merchant_promos
        SET status = 'expired',
            is_active = 0,
            updated_at = NOW()
        WHERE end_at IS NOT NULL
          AND end_at < NOW()
          AND status <> 'expired'
    ");
    
    $toLaunch = $conn->query("
        SELECT id, merchant_id, name, description, first_broadcast_at
        FROM merchant_promos
        WHERE status = 'draft'
          AND start_at IS NOT NULL
          AND start_at <= NOW()
          AND (end_at IS NULL OR end_at > NOW())
          AND discount_value > 0
          AND name != '' AND name != 'Draft Promo'
    ");
    if (!$toLaunch) return;

    while ($promo = $toLaunch->fetch_assoc()) {
        $promoId = (int)($promo['id'] ?? 0);
        $merchantIdValue = (string)($promo['merchant_id'] ?? '');
        $conn->query("
            UPDATE merchant_promos
            SET status = 'active',
                is_active = 1,
                updated_at = NOW()
            WHERE id = {$promoId}
        ");

        if ($promoId <= 0 || !empty($promo['first_broadcast_at'])) {
            continue;
        }

        $users = $conn->query("SELECT id FROM users WHERE role = 'user'");
        $promoTitle = trim((string)($promo['name'] ?? 'Promo baru'));
        $promoMessage = trim((string)($promo['description'] ?? ''));
        if ($promoMessage === '') {
            $promoMessage = 'Promo baru tersedia untuk Anda.';
        }
        if ($users) {
            while ($user = $users->fetch_assoc()) {
                merchantCreateNotification(
                    $conn,
                    (string)$user['id'],
                    $promoTitle,
                    $promoMessage,
                    'promo',
                    'Lihat Promo',
                    'promo:' . $merchantIdValue,
                    'high'
                );
            }
        }
        $conn->query("
            UPDATE merchant_promos
            SET first_broadcast_at = COALESCE(first_broadcast_at, NOW())
            WHERE id = {$promoId}
        ");
    }
}


function merchantPromoProductIds(mysqli $conn, int $promoId): array {
    if ($promoId <= 0 || !merchantTableExists($conn, 'merchant_promo_products')) {
        return [];
    }
    $stmt = $conn->prepare('SELECT product_id FROM merchant_promo_products WHERE promo_id = ?');
    if (!$stmt) return [];
    $stmt->bind_param('i', $promoId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return array_values(array_map(fn($row) => (string)($row['product_id'] ?? ''), $rows));
}

function merchantPromoSyncProducts(mysqli $conn, int $promoId, array $productIds): void {
    if ($promoId <= 0 || !merchantTableExists($conn, 'merchant_promo_products')) {
        return;
    }
    $conn->query('DELETE FROM merchant_promo_products WHERE promo_id = ' . (int)$promoId);
    $stmt = $conn->prepare('INSERT INTO merchant_promo_products (promo_id, product_id, created_at) VALUES (?, ?, NOW())');
    if (!$stmt) return;
    foreach ($productIds as $productId) {
        $pid = (int)$productId;
        if ($pid <= 0) continue;
        $stmt->bind_param('ii', $promoId, $pid);
        $stmt->execute();
    }
    $stmt->close();
}

function merchantPromoMatchesProducts(mysqli $conn, array $promo, array $productIds): bool {
    $productIds = array_values(array_filter(array_map('intval', $productIds), fn($id) => $id > 0));
    if (empty($productIds)) return false;

    $mainProductId = isset($promo['product_id']) ? (int)$promo['product_id'] : 0;
    if ($mainProductId > 0) {
        return in_array($mainProductId, $productIds, true);
    }

    $promoId = (int)($promo['id'] ?? 0);
    $junctionIds = merchantPromoProductIds($conn, $promoId);
    if (empty($junctionIds)) {
        return true;
    }
    foreach ($junctionIds as $pid) {
        if (in_array((int)$pid, $productIds, true)) {
            return true;
        }
    }
    return false;
}

function merchantPromoApply(float $subtotal, array $promo): array {
    $discountType = (string)($promo['discount_type'] ?? 'percentage');
    $discountValue = (float)($promo['discount_value'] ?? 0);
    $maxDiscount = max(0, (float)($promo['max_discount_amount'] ?? 0));

    if ($subtotal <= 0 || $discountValue <= 0) {
        return ['discount' => 0.0, 'total' => max(0, $subtotal)];
    }

    $discount = 0.0;
    if ($discountType === 'fixed') {
        $discount = $discountValue;
    } else {
        $discount = ($subtotal * $discountValue) / 100;
    }

    if ($maxDiscount > 0) {
        $discount = min($discount, $maxDiscount);
    }
    $discount = max(0, min($discount, $subtotal));
    return [
        'discount' => round($discount, 2),
        'total' => round(max(0, $subtotal - $discount), 2),
    ];
}

function merchantActivePromosForCheckout(mysqli $conn, string $merchantId, array $productIds): array {
    if (empty($productIds)) {
        return [];
    }
    $stmt = $conn->prepare("
        SELECT *
        FROM merchant_promos
        WHERE merchant_id = ?
          AND is_active = 1
          AND (start_at IS NULL OR start_at <= NOW())
          AND (end_at IS NULL OR end_at >= NOW())
        ORDER BY end_at ASC, id DESC
    ");
    if (!$stmt) return [];
    $stmt->bind_param('s', $merchantId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    return array_values(array_filter(
        $rows,
        fn($promo) => merchantPromoMatchesProducts($conn, $promo, $productIds)
    ));
}

function merchantBestPromoForCheckout(
    mysqli $conn,
    string $merchantId,
    string $userId,
    float $subtotal,
    array $items
): ?array {
    if ($subtotal <= 0 || empty($items)) {
        return null;
    }
    $productIds = [];
    foreach ($items as $item) {
        $productIds[] = (int)($item['productId'] ?? 0);
    }
    $productIds = array_values(array_filter(array_unique($productIds), fn($id) => $id > 0));
    if (empty($productIds)) return null;

    $promos = merchantActivePromosForCheckout($conn, $merchantId, $productIds);
    if (empty($promos)) return null;

    $best = null;
    foreach ($promos as $promo) {
        $minOrder = max(0, (float)($promo['min_order_amount'] ?? 0));
        if ($subtotal < $minOrder) {
            continue;
        }
        $usageLimit = isset($promo['usage_limit']) ? (int)$promo['usage_limit'] : null;
        $usedCount = (int)($promo['used_count'] ?? 0);
        if ($usageLimit !== null && $usageLimit > 0 && $usedCount >= $usageLimit) {
            continue;
        }
        $userUsageLimit = max(1, (int)($promo['per_user_usage_limit'] ?? 1));
        if ($userId !== '') {
            $userUsageCount = (int)merchantQueryValue(
                $conn,
                'SELECT COUNT(*) FROM promo_usages WHERE promo_id = ? AND user_id = ?',
                'is',
                [(int)$promo['id'], $userId]
            );
            if ($userUsageCount >= $userUsageLimit) {
                continue;
            }
        }

        $applied = merchantPromoApply($subtotal, $promo);
        $discount = (float)$applied['discount'];
        if ($discount <= 0) continue;

        if ($best === null ||
            $discount > (float)$best['discount'] ||
            (
                abs($discount - (float)$best['discount']) < 0.0001 &&
                strtotime((string)($promo['end_at'] ?? '2999-12-31')) < strtotime((string)($best['promo']['end_at'] ?? '2999-12-31'))
            )
        ) {
            $best = [
                'promo' => $promo,
                'discount' => $discount,
                'total' => (float)$applied['total'],
            ];
        }
    }
    return $best;
}

function merchantRatingSummary(mysqli $conn, string $merchantId): array {
    if (!merchantTableExists($conn, 'merchant_reviews')) {
        return ['rating' => 0.0, 'reviewCount' => 0];
    }
    $stmt = $conn->prepare("SELECT AVG(rating) AS rating, COUNT(*) AS total FROM merchant_reviews WHERE merchant_id = ? AND deleted_at IS NULL");
    if (!$stmt) return ['rating' => 0.0, 'reviewCount' => 0];
    $stmt->bind_param('s', $merchantId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return [
        'rating' => round((float)($row['rating'] ?? 0), 1),
        'reviewCount' => (int)($row['total'] ?? 0),
    ];
}

function merchantProfilePayload(mysqli $conn, array $merchant): array {
    $type = merchantTypeFromRow($merchant);
    $summary = merchantRatingSummary($conn, (string)$merchant['id']);
    return [
        'id' => (string)$merchant['id'],
        'merchantCode' => $merchant['merchant_code'] ?? '',
        'merchantType' => $type,
        'businessName' => $merchant['business_name'] ?? $merchant['display_name'] ?? 'Merchant',
        'description' => $merchant['description'] ?? '',
        'phone' => $merchant['phone'] ?? '',
        'address' => $merchant['address'] ?? '',
        'latitude' => isset($merchant['latitude']) ? (float)$merchant['latitude'] : null,
        'longitude' => isset($merchant['longitude']) ? (float)$merchant['longitude'] : null,
        'photoUrl' => $merchant['photo_url'] ?? '',
        'openTime' => $merchant['open_time'] ?? '08:00',
        'closeTime' => $merchant['close_time'] ?? '21:00',
        'rating' => $summary['rating'],
        'reviewCount' => $summary['reviewCount'],
        'status' => $merchant['status'] ?? 'active',
        'email' => $merchant['email'] ?? '',
    ];
}

function merchantCreateNotification(mysqli $conn, string $userId, string $title, string $message, string $type = 'info', ?string $actionText = null, ?string $actionUrl = null, string $importance = 'normal', bool $dispatch = true): int {
    if (!merchantTableExists($conn, 'app_notifications')) return 0;

    $importance = merchantNormalizeNotificationImportance($importance);
    $hasType = merchantColumnExists($conn, 'app_notifications', 'type');
    $hasAction = merchantColumnExists($conn, 'app_notifications', 'action_text');
    $hasActionUrl = merchantColumnExists($conn, 'app_notifications', 'action_url');
    $hasImportance = merchantColumnExists($conn, 'app_notifications', 'importance');
    $notificationId = 0;

    if ($hasType && $hasAction && $hasActionUrl && $hasImportance) {
        $stmt = $conn->prepare("
            INSERT INTO app_notifications (user_id, title, message, type, action_text, action_url, importance, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
        ");
        if ($stmt) {
            $stmt->bind_param('sssssss', $userId, $title, $message, $type, $actionText, $actionUrl, $importance);
            $stmt->execute();
            $notificationId = (int)$conn->insert_id;
            $stmt->close();
        }
    } elseif ($hasType && $hasAction && $hasActionUrl) {
        $stmt = $conn->prepare("
            INSERT INTO app_notifications (user_id, title, message, type, action_text, action_url, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
        ");
        if ($stmt) {
            $stmt->bind_param('ssssss', $userId, $title, $message, $type, $actionText, $actionUrl);
            $stmt->execute();
            $notificationId = (int)$conn->insert_id;
            $stmt->close();
        }
    } elseif ($hasType && $hasAction) {
        $stmt = $conn->prepare("
            INSERT INTO app_notifications (user_id, title, message, type, action_text, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, NOW(), NOW())
        ");
        if ($stmt) {
            $stmt->bind_param('sssss', $userId, $title, $message, $type, $actionText);
            $stmt->execute();
            $notificationId = (int)$conn->insert_id;
            $stmt->close();
        }
    } else {
        $stmt = $conn->prepare("
            INSERT INTO app_notifications (user_id, title, message, created_at, updated_at)
            VALUES (?, ?, ?, NOW(), NOW())
        ");
        if ($stmt) {
            $stmt->bind_param('sss', $userId, $title, $message);
            $stmt->execute();
            $notificationId = (int)$conn->insert_id;
            $stmt->close();
        }
    }

    if ($dispatch) {
        merchantDispatchImportantNotification($conn, $notificationId, $userId, $title, $message, $type, $actionUrl, $importance);
    }
    return $notificationId;
}

function merchantNormalizeNotificationImportance(string $importance): string {
    $value = strtolower(trim($importance));
    return in_array($value, ['low', 'normal', 'high', 'important'], true) ? $value : 'normal';
}

function merchantNotificationIsImportant(string $type, string $title, string $message, string $importance): bool {
    $importance = merchantNormalizeNotificationImportance($importance);
    if (in_array($importance, ['high', 'important'], true)) return true;

    $type = strtolower(trim($type));
    $haystack = strtolower($type . ' ' . $title . ' ' . $message);

    if ($type === 'payment') return true;

    if ($type === 'promo') {
        foreach (['promo baru', 'promo spesial', 'promo besar', 'diskon', 'potongan'] as $term) {
            if (str_contains($haystack, $term)) return true;
        }
        return false;
    }

    if (in_array($type, ['order', 'laundry'], true)) {
        foreach ([
            'diterima',
            'total pembayaran',
            'pembayaran berhasil',
            'diverifikasi',
            'diproses',
            'siap diantar',
            'pengiriman',
            'selesai',
        ] as $term) {
            if (str_contains($haystack, $term)) return true;
        }
    }

    return false;
}

function merchantUserIsActiveInApp(mysqli $conn, string $userId): bool {
    if (!merchantTableExists($conn, 'user_app_presence')) return false;

    $stmt = $conn->prepare("
        SELECT is_active, last_seen_at
        FROM user_app_presence
        WHERE user_id = ?
        LIMIT 1
    ");
    if (!$stmt) return false;
    $stmt->bind_param('s', $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row || (int)($row['is_active'] ?? 0) !== 1) return false;

    $lastSeen = strtotime((string)($row['last_seen_at'] ?? ''));
    return $lastSeen !== false && $lastSeen >= (time() - 45);
}

function merchantNotificationDeviceTokens(mysqli $conn, string $userId): array {
    if (!merchantTableExists($conn, 'user_notification_devices')) return [];

    $stmt = $conn->prepare("
        SELECT fcm_token
        FROM user_notification_devices
        WHERE user_id = ? AND is_active = 1 AND fcm_token <> ''
        ORDER BY last_seen_at DESC
        LIMIT 10
    ");
    if (!$stmt) return [];
    $stmt->bind_param('s', $userId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $tokens = [];
    foreach ($rows as $row) {
        $token = trim((string)($row['fcm_token'] ?? ''));
        if ($token !== '') $tokens[] = $token;
    }
    return array_values(array_unique($tokens));
}

function merchantDispatchImportantNotification(mysqli $conn, int $notificationId, string $userId, string $title, string $message, string $type, ?string $actionUrl, string $importance): array {
    if (!merchantNotificationIsImportant($type, $title, $message, $importance)) {
        return [
            'sent' => false,
            'skipped' => 'not_important',
            'message' => 'Event tidak termasuk notifikasi penting',
        ];
    }

    return merchantDispatchNotificationPush($conn, $notificationId, $userId, $title, $message, $type, $actionUrl);
}

function merchantDispatchNotificationPush(mysqli $conn, int $notificationId, string $userId, string $title, string $message, string $type, ?string $actionUrl, bool $forcePush = false): array {
    if (merchantUserIsActiveInApp($conn, $userId)) {
        if ($notificationId > 0 && merchantColumnExists($conn, 'app_notifications', 'seen_in_app_at')) {
            $stmt = $conn->prepare("UPDATE app_notifications SET seen_in_app_at = COALESCE(seen_in_app_at, NOW()) WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param('i', $notificationId);
                $stmt->execute();
                $stmt->close();
            }
        }
        if (!$forcePush) {
            return [
                'sent' => false,
                'skipped' => 'active_in_app',
                'message' => 'User sedang aktif di aplikasi, push tidak dikirim',
            ];
        }
    }

    $tokens = merchantNotificationDeviceTokens($conn, $userId);
    if (empty($tokens)) {
        return [
            'sent' => false,
            'skipped' => 'no_device_token',
            'message' => 'Belum ada FCM token aktif untuk user ini',
            'fcm' => merchantFcmConfigStatus(),
        ];
    }

    $sent = false;
    $results = [];
    foreach ($tokens as $token) {
        $result = merchantSendFcmNotificationDetailed($token, $title, $message, [
            'notificationId' => (string)$notificationId,
            'type' => $type,
            'actionUrl' => $actionUrl ?? '',
        ]);
        if (merchantFcmResultIndicatesInvalidToken($result)) {
            merchantDeactivateNotificationToken($conn, $token);
            $result['tokenDeactivated'] = true;
        }
        $results[] = $result;
        $sent = !empty($result['ok']) || $sent;
    }

    if ($sent && $notificationId > 0 && merchantColumnExists($conn, 'app_notifications', 'delivered_push_at')) {
        $stmt = $conn->prepare("UPDATE app_notifications SET delivered_push_at = COALESCE(delivered_push_at, NOW()) WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param('i', $notificationId);
            $stmt->execute();
            $stmt->close();
        }
    }

    return [
        'sent' => $sent,
        'tokenCount' => count($tokens),
        'results' => $results,
        'fcm' => merchantFcmConfigStatus(),
    ];
}

function merchantFcmResultIndicatesInvalidToken(array $result): bool {
    if (!empty($result['ok'])) return false;
    $text = strtolower(json_encode($result, JSON_UNESCAPED_UNICODE) ?: '');
    foreach (['unregistered', 'not registered', 'registration-token-not-registered', 'invalid-registration-token', 'invalid argument', 'invalidargument', 'requested entity was not found'] as $term) {
        if (str_contains($text, $term)) return true;
    }
    return false;
}

function merchantDeactivateNotificationToken(mysqli $conn, string $token): void {
    if (!merchantTableExists($conn, 'user_notification_devices') || $token === '') return;
    $stmt = $conn->prepare("
        UPDATE user_notification_devices
        SET is_active = 0, updated_at = NOW()
        WHERE fcm_token = ?
    ");
    if (!$stmt) return;
    $stmt->bind_param('s', $token);
    $stmt->execute();
    $stmt->close();
}

function merchantSendFcmNotification(string $token, string $title, string $message, array $data = []): bool {
    $result = merchantSendFcmNotificationDetailed($token, $title, $message, $data);
    return !empty($result['ok']);
}

function merchantSendFcmNotificationDetailed(string $token, string $title, string $message, array $data = []): array {
    if (!function_exists('curl_init')) {
        return [
            'ok' => false,
            'method' => 'none',
            'error' => 'PHP cURL extension belum aktif',
        ];
    }

    $serviceAccount = merchantFirebaseServiceAccount();
    $projectId = merchantEnv('FIREBASE_PROJECT_ID') ?: merchantEnv('FCM_PROJECT_ID') ?: (string)($serviceAccount['project_id'] ?? '');
    $accessToken = merchantFirebaseAccessToken($serviceAccount);
    if ($projectId !== '' && $accessToken !== '') {
        return merchantSendFcmV1NotificationDetailed($projectId, $accessToken, $token, $title, $message, $data);
    }

    $legacyKey = merchantEnv('FCM_SERVER_KEY') ?: merchantEnv('FIREBASE_SERVER_KEY') ?: '';
    if ($legacyKey !== '') {
        return merchantSendFcmLegacyNotificationDetailed($token, $title, $message, $data);
    }

    return [
        'ok' => false,
        'method' => 'none',
        'error' => 'Credential Firebase backend belum tersedia',
        'config' => merchantFcmConfigStatus(),
    ];
}

function merchantFcmConfigStatus(): array {
    $path = merchantFirebaseCredentialPath();
    $localConfig = merchantFirebaseLocalConfig();
    $serviceAccount = merchantFirebaseServiceAccount();
    $projectId = merchantEnv('FIREBASE_PROJECT_ID')
        ?: merchantEnv('FCM_PROJECT_ID')
        ?: (string)($localConfig['project_id'] ?? '')
        ?: (string)($serviceAccount['project_id'] ?? '');
    $hasClientEmail = trim((string)($serviceAccount['client_email'] ?? '')) !== '';
    $hasPrivateKey = trim((string)($serviceAccount['private_key'] ?? '')) !== '';
    $hasLegacyKey = (merchantEnv('FCM_SERVER_KEY') ?: merchantEnv('FIREBASE_SERVER_KEY') ?: '') !== '';

    return [
        'curl' => function_exists('curl_init'),
        'openssl' => function_exists('openssl_sign'),
        'projectId' => $projectId,
        'credentialPathConfigured' => $path !== '',
        'credentialPathReadable' => $path !== '' && is_readable($path),
        'serviceAccountSource' => $path !== '' && is_readable($path)
            ? 'file'
            : ($hasClientEmail || $hasPrivateKey
                ? (!empty($localConfig) ? 'local_config' : 'environment')
                : 'none'),
        'hasServiceAccount' => $projectId !== '' && $hasClientEmail && $hasPrivateKey,
        'hasLegacyServerKey' => $hasLegacyKey,
        'preferredMethod' => $projectId !== '' && $hasClientEmail && $hasPrivateKey
            ? 'fcm_http_v1'
            : ($hasLegacyKey ? 'legacy_server_key' : 'not_configured'),
    ];
}

function merchantFirebaseServiceAccount(): array {
    $localConfig = merchantFirebaseLocalConfig();
    $path = merchantFirebaseCredentialPath();
    if ($path !== '' && is_readable($path)) {
        $decoded = json_decode((string)file_get_contents($path), true);
        if (is_array($decoded)) return $decoded;
    }

    return [
        'project_id' => merchantEnv('FIREBASE_PROJECT_ID')
            ?: merchantEnv('FCM_PROJECT_ID')
            ?: (string)($localConfig['project_id'] ?? ''),
        'client_email' => merchantEnv('FIREBASE_CLIENT_EMAIL')
            ?: (string)($localConfig['client_email'] ?? ''),
        'private_key' => merchantEnv('FIREBASE_PRIVATE_KEY')
            ?: (string)($localConfig['private_key'] ?? ''),
    ];
}

function merchantFirebaseCredentialPath(): string {
    $localConfig = merchantFirebaseLocalConfig();
    return merchantEnv('GOOGLE_APPLICATION_CREDENTIALS')
        ?: merchantEnv('GOOGLE_APPLICATIONS_CREDENTIALS')
        ?: merchantEnv('FIREBASE_SERVICE_ACCOUNT_PATH')
        ?: (string)($localConfig['service_account_path'] ?? '');
}

function merchantFirebaseLocalConfig(): array {
    $path = __DIR__ . '/../config/firebase.local.php';
    if (!is_readable($path)) return [];
    $config = require $path;
    return is_array($config) ? $config : [];
}

function merchantEnv(string $key): string {
    $value = getenv($key);
    if ($value !== false && $value !== '') return (string)$value;
    if (isset($_SERVER[$key]) && $_SERVER[$key] !== '') return (string)$_SERVER[$key];
    if (isset($_ENV[$key]) && $_ENV[$key] !== '') return (string)$_ENV[$key];
    if (function_exists('apache_getenv')) {
        $apacheValue = apache_getenv($key);
        if ($apacheValue !== false && $apacheValue !== '') return (string)$apacheValue;
    }
    return '';
}

function merchantFirebaseAccessToken(array $serviceAccount): string {
    $clientEmail = trim((string)($serviceAccount['client_email'] ?? ''));
    $privateKey = (string)($serviceAccount['private_key'] ?? '');
    $privateKey = str_replace('\\n', "\n", $privateKey);
    if ($clientEmail === '' || $privateKey === '' || !function_exists('openssl_sign')) {
        return '';
    }

    $now = time();
    $cachePath = merchantFirebaseAccessTokenCachePath($clientEmail);
    if ($cachePath !== '' && is_readable($cachePath)) {
        $cached = json_decode((string)file_get_contents($cachePath), true);
        if (is_array($cached) &&
            !empty($cached['access_token']) &&
            (int)($cached['expires_at'] ?? 0) > $now + 60) {
            return (string)$cached['access_token'];
        }
    }

    $header = ['alg' => 'RS256', 'typ' => 'JWT'];
    $claims = [
        'iss' => $clientEmail,
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => 'https://oauth2.googleapis.com/token',
        'iat' => $now,
        'exp' => $now + 3600,
    ];
    $unsignedJwt = merchantBase64UrlEncode(json_encode($header)) . '.' .
        merchantBase64UrlEncode(json_encode($claims));

    $signature = '';
    if (!openssl_sign($unsignedJwt, $signature, $privateKey, OPENSSL_ALGO_SHA256)) {
        return '';
    }
    $assertion = $unsignedJwt . '.' . merchantBase64UrlEncode($signature);

    $ch = curl_init('https://oauth2.googleapis.com/token');
    if (!$ch) return '';
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 8,
        CURLOPT_TIMEOUT => 20,
        CURLOPT_POSTFIELDS => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $assertion,
        ]),
    ]);
    $response = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($response === false || $status < 200 || $status >= 300) return '';

    $decoded = json_decode((string)$response, true);
    $token = is_array($decoded) ? (string)($decoded['access_token'] ?? '') : '';
    if ($token !== '' && $cachePath !== '') {
        $expiresIn = max(300, (int)($decoded['expires_in'] ?? 3600));
        @file_put_contents(
            $cachePath,
            json_encode([
                'access_token' => $token,
                'expires_at' => $now + $expiresIn - 120,
            ]),
            LOCK_EX
        );
    }
    return $token;
}

function merchantBase64UrlEncode(string $value): string {
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

function merchantFirebaseAccessTokenCachePath(string $clientEmail): string {
    $dir = sys_get_temp_dir();
    if ($dir === '' || !is_dir($dir) || !is_writable($dir)) return '';
    return rtrim($dir, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR .
        'kosfinder_fcm_' . md5($clientEmail) . '.json';
}

function merchantSendFcmV1Notification(string $projectId, string $accessToken, string $token, string $title, string $message, array $data = []): bool {
    $result = merchantSendFcmV1NotificationDetailed($projectId, $accessToken, $token, $title, $message, $data);
    return !empty($result['ok']);
}

function merchantSendFcmV1NotificationDetailed(string $projectId, string $accessToken, string $token, string $title, string $message, array $data = []): array {
    $payload = [
        'message' => [
            'token' => $token,
            'notification' => [
                'title' => $title,
                'body' => $message,
            ],
            'data' => array_map(static fn($value) => (string)$value, $data),
            'android' => [
                'priority' => 'HIGH',
                'notification' => ['sound' => 'default'],
            ],
            'apns' => [
                'payload' => [
                    'aps' => ['sound' => 'default'],
                ],
            ],
        ],
    ];

    $ch = curl_init('https://fcm.googleapis.com/v1/projects/' . rawurlencode($projectId) . '/messages:send');
    if (!$ch) {
        return [
            'ok' => false,
            'method' => 'fcm_http_v1',
            'error' => 'Gagal membuat cURL handle',
        ];
    }
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => [
            'Authorization: Bearer ' . $accessToken,
            'Content-Type: application/json',
        ],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 8,
        CURLOPT_TIMEOUT => 20,
        CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_UNICODE),
    ]);
    $response = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);

    return [
        'ok' => $response !== false && $status >= 200 && $status < 300,
        'method' => 'fcm_http_v1',
        'status' => $status,
        'error' => $response === false ? $curlError : null,
        'response' => is_string($response) ? substr($response, 0, 500) : null,
    ];
}

function merchantSendFcmLegacyNotification(string $token, string $title, string $message, array $data = []): bool {
    $result = merchantSendFcmLegacyNotificationDetailed($token, $title, $message, $data);
    return !empty($result['ok']);
}

function merchantSendFcmLegacyNotificationDetailed(string $token, string $title, string $message, array $data = []): array {
    $serverKey = getenv('FCM_SERVER_KEY') ?: getenv('FIREBASE_SERVER_KEY') ?: '';
    if ($serverKey === '') {
        return [
            'ok' => false,
            'method' => 'legacy_server_key',
            'error' => 'FCM server key belum tersedia',
        ];
    }

    $payload = [
        'to' => $token,
        'priority' => 'high',
        'notification' => [
            'title' => $title,
            'body' => $message,
            'sound' => 'default',
        ],
        'data' => array_map(static fn($value) => (string)$value, $data),
    ];

    $ch = curl_init('https://fcm.googleapis.com/fcm/send');
    if (!$ch) {
        return [
            'ok' => false,
            'method' => 'legacy_server_key',
            'error' => 'Gagal membuat cURL handle',
        ];
    }
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => [
            'Authorization: key=' . $serverKey,
            'Content-Type: application/json',
        ],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 8,
        CURLOPT_TIMEOUT => 20,
        CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_UNICODE),
    ]);
    $response = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);

    if ($response === false || $status < 200 || $status >= 300) {
        return [
            'ok' => false,
            'method' => 'legacy_server_key',
            'status' => $status,
            'error' => $response === false ? $curlError : null,
            'response' => is_string($response) ? substr($response, 0, 500) : null,
        ];
    }
    $decoded = json_decode((string)$response, true);
    $ok = !isset($decoded['failure']) || (int)$decoded['failure'] === 0;
    return [
        'ok' => $ok,
        'method' => 'legacy_server_key',
        'status' => $status,
        'error' => $ok ? null : 'FCM legacy response contains failure',
        'response' => substr((string)$response, 0, 500),
    ];
}

function merchantSyncPlace(mysqli $conn, array $merchant): void {
    $type = merchantTypeFromRow($merchant);
    $merchantId = (string)$merchant['id'];
    $name = (string)($merchant['business_name'] ?? 'Merchant');
    $address = (string)($merchant['address'] ?? '');
    $rating = merchantRatingSummary($conn, $merchantId)['rating'];
    $image = (string)($merchant['photo_url'] ?? '');
    $placeImage = strlen($image) > 60000 ? '' : $image;
    $openHours = ($merchant['open_time'] ?? '08:00') . ' - ' . ($merchant['close_time'] ?? '21:00');
    $lat = isset($merchant['latitude']) ? (float)$merchant['latitude'] : null;
    $lng = isset($merchant['longitude']) ? (float)$merchant['longitude'] : null;

    if ($type === 'laundry' && merchantTableExists($conn, 'laundry_places')) {
        merchantAddColumn($conn, 'laundry_places', 'latitude', "`latitude` DECIMAL(10,8) DEFAULT NULL");
        merchantAddColumn($conn, 'laundry_places', 'longitude', "`longitude` DECIMAL(11,8) DEFAULT NULL");
        $stmt = $conn->prepare("
            INSERT INTO laundry_places (id, name, address, rating, distance_km, image_url, open_hours, merchant_id, latitude, longitude, created_at, updated_at)
            VALUES (?, ?, ?, ?, 0, ?, ?, ?, ?, ?, NOW(), NOW())
            ON DUPLICATE KEY UPDATE
                name = VALUES(name), address = VALUES(address), rating = VALUES(rating),
                image_url = VALUES(image_url), open_hours = VALUES(open_hours),
                merchant_id = VALUES(merchant_id), latitude = VALUES(latitude), longitude = VALUES(longitude),
                updated_at = NOW()
        ");
        if ($stmt) {
            $stmt->bind_param('sssdsssdd', $merchantId, $name, $address, $rating, $placeImage, $openHours, $merchantId, $lat, $lng);
            $stmt->execute();
            $stmt->close();
        }
    }

    if ($type === 'catering' && merchantTableExists($conn, 'catering_places')) {
        merchantAddColumn($conn, 'catering_places', 'latitude', "`latitude` DECIMAL(10,8) DEFAULT NULL");
        merchantAddColumn($conn, 'catering_places', 'longitude', "`longitude` DECIMAL(11,8) DEFAULT NULL");
        $specialty = 'Catering';
        $stmt = $conn->prepare("
            INSERT INTO catering_places (id, name, address, specialty, rating, distance_km, image_url, min_order_portion, merchant_id, latitude, longitude, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, 0, ?, 1, ?, ?, ?, NOW(), NOW())
            ON DUPLICATE KEY UPDATE
                name = VALUES(name), address = VALUES(address), specialty = VALUES(specialty),
                rating = VALUES(rating), image_url = VALUES(image_url), merchant_id = VALUES(merchant_id),
                latitude = VALUES(latitude), longitude = VALUES(longitude), updated_at = NOW()
        ");
        if ($stmt) {
            $stmt->bind_param('ssssdssdd', $merchantId, $name, $address, $specialty, $rating, $placeImage, $merchantId, $lat, $lng);
            $stmt->execute();
            $stmt->close();
        }
    }
}

function merchantResolveMerchantId(mysqli $conn, string $id): ?string {
    if ($id === '') return null;
    $found = merchantQueryValue($conn, 'SELECT id FROM merchants WHERE id = ? LIMIT 1', 's', [$id]);
    if ($found) return (string)$found;

    foreach (['laundry_places', 'catering_places'] as $table) {
        if (!merchantTableExists($conn, $table) || !merchantColumnExists($conn, $table, 'merchant_id')) continue;
        $found = merchantQueryValue($conn, "SELECT merchant_id FROM `$table` WHERE id = ? LIMIT 1", 's', [$id]);
        if ($found) return (string)$found;
    }
    return null;
}

function merchantFallbackProductId(mysqli $conn, string $merchantId, string $name, float $price): ?int {
    $stmt = $conn->prepare("SELECT id FROM products WHERE merchant_id = ? AND nama_produk = ? LIMIT 1");
    if ($stmt) {
        $stmt->bind_param('ss', $merchantId, $name);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if ($row) return (int)$row['id'];
    }

    $desc = 'Produk dibuat otomatis dari pesanan user';
    $merchantType = merchantQueryValue($conn, 'SELECT merchant_type FROM merchants WHERE id = ? LIMIT 1', 's', [$merchantId]);
    $unit = $merchantType === 'laundry' ? 'item' : '/paket';
    $stmt = $conn->prepare("
        INSERT INTO products (merchant_id, nama_produk, harga, deskripsi, category, unit, service_type, is_active, created_at, updated_at)
        VALUES (?, ?, ?, ?, 'Pesanan', ?, ?, 1, NOW(), NOW())
    ");
    if (!$stmt) return null;
    $stmt->bind_param('ssdsss', $merchantId, $name, $price, $desc, $unit, $merchantType);
    $stmt->execute();
    $id = (int)$conn->insert_id;
    $stmt->close();
    return $id > 0 ? $id : null;
}

?>
