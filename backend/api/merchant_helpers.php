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
    merchantAddColumn($conn, 'merchants', 'service_categories', "`service_categories` TEXT DEFAULT NULL");
    merchantAddColumn($conn, 'merchants', 'status', "`status` ENUM('active','inactive') DEFAULT 'active'");

    if (merchantTableExists($conn, 'products')) {
        merchantAddColumn($conn, 'products', 'category', "`category` VARCHAR(100) DEFAULT NULL");
        merchantAddColumn($conn, 'products', 'unit', "`unit` VARCHAR(30) DEFAULT NULL");
        merchantAddColumn($conn, 'products', 'image_url', "`image_url` LONGTEXT DEFAULT NULL");
        merchantAddColumn($conn, 'products', 'is_active', "`is_active` TINYINT(1) NOT NULL DEFAULT 1");
        merchantAddColumn($conn, 'products', 'service_type', "`service_type` VARCHAR(30) DEFAULT NULL");
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
        merchantAddColumn($conn, 'orders', 'promo_id', "`promo_id` BIGINT UNSIGNED DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'promo_name', "`promo_name` VARCHAR(255) DEFAULT NULL");
        merchantAddColumn($conn, 'orders', 'promo_discount_amount', "`promo_discount_amount` DECIMAL(14,2) NOT NULL DEFAULT 0");
        merchantAddColumn($conn, 'orders', 'subtotal_amount', "`subtotal_amount` DECIMAL(14,2) NOT NULL DEFAULT 0");
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
                promo_id BIGINT UNSIGNED DEFAULT NULL,
                promo_name VARCHAR(255) DEFAULT NULL,
                promo_discount_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
                subtotal_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
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

    if (merchantTableExists($conn, 'app_notifications')) {
        merchantAddColumn($conn, 'app_notifications', 'type', "`type` VARCHAR(30) DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'action_text', "`action_text` VARCHAR(80) DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'action_url', "`action_url` VARCHAR(160) DEFAULT NULL");
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
               o.subscription_status, o.cancellation_requested_at
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

    $packageType = ((int)($row['subscription_days'] ?? 30)) . '_days';
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
        SELECT subscription_days, subscription_status
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

    $days = (int)($row['subscription_days'] ?? 30);
    if (!in_array($days, [20, 30], true)) {
        $days = 30;
    }
    $start = new DateTime('tomorrow');
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
        INSERT INTO merchants (id, user_id, business_name, merchant_type, merchant_code, service_categories, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
    ");
    if (!$ins) {
        merchantSendJson(false, null, 'Gagal membuat profil merchant', 500);
    }
    $code = 'M-' . strtoupper(substr(str_replace('-', '', $merchantId), 0, 8));
    $categories = $type === 'laundry' ? 'Laundry Kiloan,Antar Jemput' : 'Paket Bulanan,Menu Harian';
    $ins->bind_param('ssssss', $merchantId, $userId, $businessName, $type, $code, $categories);
    $ins->execute();
    $ins->close();

    return merchantCurrent($conn, $payload);
}

function merchantTypeFromRow(array $merchant): string {
    $type = strtolower((string)($merchant['merchant_type'] ?? $merchant['merchantType'] ?? 'laundry'));
    return in_array($type, ['laundry', 'catering'], true) ? $type : 'laundry';
}

function merchantCategories(?string $raw, string $type): array {
    if ($raw === null || trim($raw) === '') {
        return $type === 'laundry'
            ? ['Laundry Kiloan', 'Antar Jemput']
            : ['Paket Bulanan', 'Menu Harian'];
    }
    $decoded = json_decode($raw, true);
    if (is_array($decoded)) {
        return array_values(array_filter(array_map('strval', $decoded)));
    }
    return array_values(array_filter(array_map('trim', explode(',', $raw))));
}

function merchantStatusGroup(string $status): string {
    return match ($status) {
        'pending' => 'pending',
        'done' => 'done',
        default => 'processing',
    };
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

function merchantPaymentMethodLabel(?string $method): string {
    $key = strtolower(trim((string)$method));
    return match ($key) {
        'bca' => 'Transfer Bank BCA',
        'mandiri' => 'Transfer Bank Mandiri',
        'bni' => 'Transfer Bank BNI',
        'cimb' => 'Transfer Bank CIMB Niaga',
        'gopay' => 'GoPay',
        'ovo' => 'OVO',
        'dana' => 'DANA',
        'shopeepay' => 'ShopeePay',
        'linkaja' => 'LinkAja',
        'qris' => 'QRIS',
        'cod', 'cash' => 'Bayar di Tempat (COD)',
        default => $method !== '' ? ucwords(str_replace('_', ' ', $key)) : 'Belum dipilih',
    };
}

function merchantPaymentStatusLabel(?string $status, ?string $method = null, ?float $totalAmount = null, ?string $serviceType = null): string {
    $normalized = strtolower(trim((string)$status));
    $methodNormalized = strtolower(trim((string)$method));
    if (str_contains($methodNormalized, 'cod') || str_contains($methodNormalized, 'cash')) {
        return 'COD';
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

function merchantFinalizeLaundryOrder(
    mysqli $conn,
    int $orderId,
    string $merchantId,
    float $weightKg,
    float $totalAmount
): void {
    if ($weightKg <= 0 || $totalAmount <= 0) {
        merchantSendJson(false, null, 'Berat dan total bayar wajib diisi', 400);
    }

    $stmt = $conn->prepare("
        SELECT id, service_type, payment_status
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
    if ($paymentStatus !== 'awaiting_weighing') {
        merchantSendJson(false, null, 'Total laundry sudah ditetapkan', 400);
    }

    $conn->begin_transaction();
    try {
        $itemStmt = $conn->prepare("
            SELECT id, harga FROM order_items WHERE order_id = ? ORDER BY id ASC LIMIT 1
        ");
        if (!$itemStmt) {
            throw new Exception($conn->error);
        }
        $itemStmt->bind_param('i', $orderId);
        $itemStmt->execute();
        $item = $itemStmt->get_result()->fetch_assoc();
        $itemStmt->close();

        if ($item) {
            $itemId = (int)$item['id'];
            $unitPrice = $weightKg > 0 ? round($totalAmount / $weightKg, 2) : (float)$item['harga'];
            $qty = max(1, (int)round($weightKg));
            $updateItem = $conn->prepare("
                UPDATE order_items SET qty = ?, harga = ? WHERE id = ?
            ");
            if (!$updateItem) {
                throw new Exception($conn->error);
            }
            $updateItem->bind_param('idi', $qty, $unitPrice, $itemId);
            $updateItem->execute();
            $updateItem->close();
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
            SET total_harga = ?, payment_status = ?, updated_at = NOW()
            WHERE id = ? AND merchant_id = ?
        ");
        if (!$updateOrder) {
            throw new Exception($conn->error);
        }
        $updateOrder->bind_param('dsis', $totalAmount, $nextPayment, $orderId, $merchantId);
        $updateOrder->execute();
        $updateOrder->close();

        $userId = (string)merchantQueryValue(
            $conn,
            'SELECT user_id FROM orders WHERE id = ?',
            'i',
            [$orderId]
        );
        $orderCode = (string)merchantQueryValue(
            $conn,
            'SELECT order_code FROM orders WHERE id = ?',
            'i',
            [$orderId]
        );
        if ($userId !== '') {
            $amountText = number_format($totalAmount, 0, ',', '.');
            merchantCreateNotification(
                $conn,
                $userId,
                'Total laundry sudah ditetapkan',
                'Pesanan ' . ($orderCode !== '' ? $orderCode : ('#' . $orderId)) .
                    ' sebesar Rp ' . $amountText . ' siap dibayar. Silakan buka detail pesanan.',
                'payment',
                'Bayar sekarang',
                'order:' . $orderId
            );
        }

        $conn->commit();
    } catch (Throwable $e) {
        $conn->rollback();
        merchantSendJson(false, null, $e->getMessage(), 500);
    }
}

function merchantOrderCanApprove(array $row): bool {
    $status = strtolower(trim((string)($row['status'] ?? 'pending')));
    if ($status !== 'pending') return true;

    $method = strtolower(trim((string)($row['payment_method'] ?? '')));
    $paymentStatus = strtolower(trim((string)($row['payment_status'] ?? 'waiting_payment')));
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
            'accepted' => 'done',
            default => 'done',
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

function merchantProductPayload(array $row): array {
    $payload = [
        'id' => (string)($row['id'] ?? ''),
        'merchantId' => (string)($row['merchant_id'] ?? ''),
        'name' => $row['nama_produk'] ?? $row['name'] ?? '',
        'description' => $row['deskripsi'] ?? $row['description'] ?? '',
        'price' => (float)($row['harga'] ?? $row['price'] ?? 0),
        'price20Days' => isset($row['price_20_days']) ? (float)$row['price_20_days'] : null,
        'category' => $row['category'] ?? '',
        'unit' => $row['unit'] ?? '',
        'imageUrl' => $row['image_url'] ?? $row['imageUrl'] ?? '',
        'isActive' => (int)($row['is_active'] ?? 1) === 1,
        'serviceType' => $row['service_type'] ?? '',
        'packageDeliveryType' => $row['package_delivery_type'] ?? null,
    ];
    return $payload;
}

function merchantOrderItems(mysqli $conn, int $orderId): array {
    if (!merchantTableExists($conn, 'order_items')) return [];
    $stmt = $conn->prepare("
        SELECT oi.id, oi.product_id, oi.qty, oi.harga,
               p.nama_produk, p.deskripsi, p.image_url
        FROM order_items oi
        LEFT JOIN products p ON p.id = oi.product_id
        WHERE oi.order_id = ?
        ORDER BY oi.id ASC
    ");
    if (!$stmt) return [];
    $stmt->bind_param('i', $orderId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    return array_map(function ($row) {
        $qty = (int)($row['qty'] ?? 0);
        $price = (float)($row['harga'] ?? 0);
        return [
            'id' => (string)($row['id'] ?? ''),
            'productId' => (string)($row['product_id'] ?? ''),
            'name' => $row['nama_produk'] ?? 'Item Pesanan',
            'description' => $row['deskripsi'] ?? '',
            'quantity' => $qty,
            'price' => $price,
            'subtotal' => $qty * $price,
            'imageUrl' => $row['image_url'] ?? '',
        ];
    }, $rows);
}

function merchantOrderPayload(mysqli $conn, array $row, bool $withItems = true): array {
    $orderId = (int)($row['id'] ?? 0);
    $items = $withItems ? merchantOrderItems($conn, $orderId) : [];
    $createdAt = $row['created_at'] ?? date(DATE_ATOM);
    $code = $row['order_code'] ?? ('SR-ORDER-' . str_pad((string)$orderId, 6, '0', STR_PAD_LEFT));
    $status = $row['status'] ?? 'pending';
    $serviceType = $row['service_type'] ?? $row['merchant_type'] ?? 'laundry';
    $firstItem = $items[0]['name'] ?? ($serviceType === 'laundry' ? 'Layanan Laundry' : 'Paket Catering');

    return [
        'id' => (string)$orderId,
        'code' => $code,
        'customerName' => $row['customer_name'] ?? 'Pelanggan',
        'customerPhone' => $row['customer_phone'] ?? '',
        'customerEmail' => $row['customer_email'] ?? '',
        'serviceType' => $serviceType,
        'serviceName' => $firstItem,
        'createdAt' => date(DATE_ATOM, strtotime($createdAt)),
        'estimatedTime' => $row['estimated_time'] ?? '',
        'status' => $status,
        'statusLabel' => merchantStatusLabel($status),
        'statusGroup' => merchantStatusGroup($status),
        'deliveryAddress' => $row['delivery_address'] ?? '',
        'deliveryLatitude' => isset($row['delivery_latitude']) ? (float)$row['delivery_latitude'] : null,
        'deliveryLongitude' => isset($row['delivery_longitude']) ? (float)$row['delivery_longitude'] : null,
        'totalAmount' => (float)($row['total_harga'] ?? 0),
        'paymentMethod' => $row['payment_method'] ?? '',
        'paymentStatus' => $row['payment_status'] ?? '',
        'paymentMethodLabel' => merchantPaymentMethodLabel($row['payment_method'] ?? null),
        'paymentStatusLabel' => merchantPaymentStatusLabel(
            $row['payment_status'] ?? null,
            $row['payment_method'] ?? null,
            (float)($row['total_harga'] ?? 0),
            $serviceType
        ),
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
        'items' => $items,
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
    }

    if ($statusGroup === 'pending') {
        $where[] = "o.status = 'pending'";
    } elseif ($statusGroup === 'processing') {
        $where[] = "o.status IN ('accepted','processing','delivered')";
    } elseif ($statusGroup === 'done') {
        $where[] = "o.status = 'done'";
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
               m.merchant_type
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

    return array_map(fn($row) => merchantOrderPayload($conn, $row), $rows);
}

function merchantPromoPayload(array $row): array {
    $now = time();
    $startAt = $row['start_at'] ?? null;
    $endAt = $row['end_at'] ?? null;
    $isActive = (int)($row['is_active'] ?? 1) === 1;
    $isLive = $isActive &&
        (!$startAt || strtotime($startAt) <= $now) &&
        (!$endAt || strtotime($endAt) >= $now);
    $status = !$isActive ? 'paused' : ($isLive ? 'active' : (($endAt && strtotime($endAt) < $now) ? 'expired' : 'scheduled'));

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
        'categories' => merchantCategories($merchant['service_categories'] ?? null, $type),
        'rating' => $summary['rating'],
        'reviewCount' => $summary['reviewCount'],
        'status' => $merchant['status'] ?? 'active',
        'email' => $merchant['email'] ?? '',
    ];
}

function merchantCreateNotification(mysqli $conn, string $userId, string $title, string $message, string $type = 'info', ?string $actionText = null, ?string $actionUrl = null): void {
    if (!merchantTableExists($conn, 'app_notifications')) return;

    $hasType = merchantColumnExists($conn, 'app_notifications', 'type');
    $hasAction = merchantColumnExists($conn, 'app_notifications', 'action_text');
    $hasActionUrl = merchantColumnExists($conn, 'app_notifications', 'action_url');

    if ($hasType && $hasAction && $hasActionUrl) {
        $stmt = $conn->prepare("
            INSERT INTO app_notifications (user_id, title, message, type, action_text, action_url, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
        ");
        if ($stmt) {
            $stmt->bind_param('ssssss', $userId, $title, $message, $type, $actionText, $actionUrl);
            $stmt->execute();
            $stmt->close();
        }
        return;
    }

    if ($hasType && $hasAction) {
        $stmt = $conn->prepare("
            INSERT INTO app_notifications (user_id, title, message, type, action_text, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, NOW(), NOW())
        ");
        if ($stmt) {
            $stmt->bind_param('sssss', $userId, $title, $message, $type, $actionText);
            $stmt->execute();
            $stmt->close();
        }
        return;
    }

    $stmt = $conn->prepare("
        INSERT INTO app_notifications (user_id, title, message, created_at, updated_at)
        VALUES (?, ?, ?, NOW(), NOW())
    ");
    if ($stmt) {
        $stmt->bind_param('sss', $userId, $title, $message);
        $stmt->execute();
        $stmt->close();
    }
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
        $specialty = implode(', ', merchantCategories($merchant['service_categories'] ?? null, $type));
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
