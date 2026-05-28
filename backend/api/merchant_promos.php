<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function merchantPromoProduct(mysqli $conn, string $merchantId, ?string $productId): ?array {
    if (!$productId) return null;
    $stmt = $conn->prepare("SELECT * FROM products WHERE id = ? AND merchant_id = ? AND is_active = 1 LIMIT 1");
    if (!$stmt) return null;
    $stmt->bind_param('ss', $productId, $merchantId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

function merchantNormalizeDate(?string $value): ?string {
    if ($value === null || trim($value) === '') return null;
    $time = strtotime($value);
    return $time ? date('Y-m-d H:i:s', $time) : null;
}

try {
    $payload = merchantRequireMerchant();
    $merchant = merchantCurrent($conn, $payload);
    $merchantId = (string)$merchant['id'];

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $id = trim($_GET['id'] ?? '');
        $where = 'mp.merchant_id = ?';
        $types = 's';
        $params = [$merchantId];
        if ($id !== '') {
            $where .= ' AND CAST(mp.id AS CHAR) = ?';
            $types .= 's';
            $params[] = $id;
        }

        $stmt = $conn->prepare("
            SELECT mp.*, p.nama_produk
            FROM merchant_promos mp
            LEFT JOIN products p ON p.id = mp.product_id
            WHERE $where
            ORDER BY mp.is_active DESC, mp.end_at DESC, mp.id DESC
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();

        $data = array_map(function ($row) use ($conn) {
            $payload = merchantPromoPayload($row);
            $payload['productIds'] = merchantPromoProductIds($conn, (int)($row['id'] ?? 0));
            if (empty($payload['productIds']) && !empty($payload['productId'])) {
                $payload['productIds'] = [(string)$payload['productId']];
            }
            return $payload;
        }, $rows);
        if ($id !== '') {
            if (empty($data)) {
                merchantSendJson(false, null, 'Promo tidak ditemukan', 404);
            }
            merchantSendJson(true, $data[0], 'Promo berhasil dimuat');
        }
        merchantSendJson(true, $data, 'Promo merchant berhasil dimuat');
    }

    $body = merchantBody();
    $id = trim((string)($body['id'] ?? $_GET['id'] ?? ''));
    $name = trim((string)($body['name'] ?? ''));
    $description = trim((string)($body['description'] ?? ''));
    $productId = trim((string)($body['productId'] ?? ''));
    $discountType = strtolower(trim((string)($body['discountType'] ?? 'percentage')));
    $discountValue = (float)($body['discountValue'] ?? 0);
    $minOrder = (float)($body['minOrderAmount'] ?? 0);
    $maxDiscount = (float)($body['maxDiscountAmount'] ?? 0);
    $startAt = merchantNormalizeDate($body['startAt'] ?? null);
    $endAt = merchantNormalizeDate($body['endAt'] ?? null);
    $isActive = !array_key_exists('isActive', $body) || !empty($body['isActive']) ? 1 : 0;
    $usageLimit = isset($body['usageLimit']) && $body['usageLimit'] !== '' ? (int)$body['usageLimit'] : null;
    $perUserUsageLimit = max(1, (int)($body['perUserUsageLimit'] ?? 1));
    $productIds = [];
    $rawProductIds = $body['productIds'] ?? [];
    if (is_array($rawProductIds)) {
        foreach ($rawProductIds as $rawId) {
            $pid = (int)(is_array($rawId) ? ($rawId['id'] ?? $rawId['productId'] ?? 0) : $rawId);
            if ($pid > 0) {
                $productIds[] = $pid;
            }
        }
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST' || $_SERVER['REQUEST_METHOD'] === 'PUT') {
        if ($name === '') {
            merchantSendJson(false, null, 'Nama promo wajib diisi', 400);
        }
        if (!in_array($discountType, ['percentage', 'fixed'], true)) {
            merchantSendJson(false, null, 'Tipe diskon tidak valid', 400);
        }
        if ($discountValue <= 0) {
            merchantSendJson(false, null, 'Nilai promo wajib lebih dari 0', 400);
        }
        if ($discountType === 'percentage' && $discountValue > 35) {
            merchantSendJson(false, null, 'Diskon persentase maksimal 35% agar margin merchant tetap aman', 400);
        }
        if ($minOrder <= 0) {
            merchantSendJson(false, null, 'Minimal transaksi wajib diisi supaya promo tetap terkendali', 400);
        }
        if ($discountType === 'fixed' && $discountValue > ($minOrder * 0.35)) {
            merchantSendJson(false, null, 'Potongan nominal tidak boleh melebihi 35% dari minimal transaksi', 400);
        }
        if ($discountType === 'percentage' && $maxDiscount <= 0) {
            merchantSendJson(false, null, 'Batas maksimal diskon wajib diisi untuk promo persentase', 400);
        }
        if ($discountType === 'percentage' && $maxDiscount > ($minOrder * 0.35)) {
            merchantSendJson(false, null, 'Batas diskon maksimal terlalu tinggi untuk minimal transaksi tersebut', 400);
        }
        if ($endAt !== null && $startAt !== null && strtotime($endAt) <= strtotime($startAt)) {
            merchantSendJson(false, null, 'Tanggal berakhir harus setelah tanggal mulai', 400);
        }

        if (!empty($productIds)) {
            foreach ($productIds as $pid) {
                $validProduct = merchantPromoProduct($conn, $merchantId, (string)$pid);
                if (!$validProduct) {
                    merchantSendJson(false, null, 'Ada produk promo yang tidak valid', 400);
                }
            }
            $nullableProductId = null;
        } else {
            $product = merchantPromoProduct($conn, $merchantId, $productId !== '' ? $productId : null);
            if ($productId !== '' && !$product) {
                merchantSendJson(false, null, 'Produk promo tidak ditemukan', 404);
            }
            if ($product && $minOrder < (float)$product['harga']) {
                merchantSendJson(false, null, 'Minimal transaksi harus setidaknya sama dengan harga produk yang dipilih', 400);
            }
            $nullableProductId = $product ? (int)$product['id'] : null;
        }

        $wasActiveBeforeUpdate = false;
        if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
            $prev = $conn->prepare("
                SELECT is_active, start_at, end_at
                FROM merchant_promos
                WHERE id = ? AND merchant_id = ?
                LIMIT 1
            ");
            if ($prev) {
                $prev->bind_param('ss', $id, $merchantId);
                $prev->execute();
                $prevRow = $prev->get_result()->fetch_assoc();
                $prev->close();
                if ($prevRow) {
                    $now = time();
                    $wasActiveBeforeUpdate = (int)($prevRow['is_active'] ?? 0) === 1
                        && (!$prevRow['start_at'] || strtotime((string)$prevRow['start_at']) <= $now)
                        && (!$prevRow['end_at'] || strtotime((string)$prevRow['end_at']) >= $now);
                }
            }
        }

        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $stmt = $conn->prepare("
                INSERT INTO merchant_promos
                    (merchant_id, product_id, name, description, discount_type, discount_value,
                     min_order_amount, max_discount_amount, start_at, end_at, is_active, usage_limit,
                     per_user_usage_limit, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Database error', 500);
            }
            $stmt->bind_param(
                'sisssdddssiii',
                $merchantId,
                $nullableProductId,
                $name,
                $description,
                $discountType,
                $discountValue,
                $minOrder,
                $maxDiscount,
                $startAt,
                $endAt,
                $isActive,
                $usageLimit,
                $perUserUsageLimit
            );
            $stmt->execute();
            $id = (string)$conn->insert_id;
            $stmt->close();
        } else {
            if ($id === '') {
                merchantSendJson(false, null, 'ID promo wajib diisi', 400);
            }
            $stmt = $conn->prepare("
                UPDATE merchant_promos
                SET product_id = ?,
                    name = ?,
                    description = ?,
                    discount_type = ?,
                    discount_value = ?,
                    min_order_amount = ?,
                    max_discount_amount = ?,
                    start_at = ?,
                    end_at = ?,
                    is_active = ?,
                    usage_limit = ?,
                    per_user_usage_limit = ?,
                    updated_at = NOW()
                WHERE id = ? AND merchant_id = ?
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Database error', 500);
            }
            $stmt->bind_param(
                'isssdddssiiiss',
                $nullableProductId,
                $name,
                $description,
                $discountType,
                $discountValue,
                $minOrder,
                $maxDiscount,
                $startAt,
                $endAt,
                $isActive,
                $usageLimit,
                $perUserUsageLimit,
                $id,
                $merchantId
            );
            $stmt->execute();
            $stmt->close();
        }

        merchantPromoSyncProducts($conn, (int)$id, $productIds);

        $stmt = $conn->prepare("
            SELECT mp.*, p.nama_produk
            FROM merchant_promos mp
            LEFT JOIN products p ON p.id = mp.product_id
            WHERE mp.id = ? AND mp.merchant_id = ?
            LIMIT 1
        ");
        $stmt->bind_param('ss', $id, $merchantId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        $promo = merchantPromoPayload($row ?? []);
        $promo['productIds'] = merchantPromoProductIds($conn, (int)$id);
        if (empty($promo['productIds']) && !empty($promo['productId'])) {
            $promo['productIds'] = [(string)$promo['productId']];
        }

        $shouldBroadcastPromo = $_SERVER['REQUEST_METHOD'] === 'POST'
            ? $promo['status'] === 'active'
            : (!$wasActiveBeforeUpdate && $promo['status'] === 'active');
        if ($shouldBroadcastPromo) {
            $users = $conn->query("SELECT id FROM users WHERE role = 'user'");
            if ($users) {
                while ($user = $users->fetch_assoc()) {
                    merchantCreateNotification(
                        $conn,
                        (string)$user['id'],
                        'Promo baru dari ' . ($merchant['business_name'] ?? 'merchant'),
                        $name . ' sudah aktif. Cek produk yang sedang promo sebelum periode berakhir.',
                        'promo',
                        'Lihat Promo'
                    );
                }
            }
        }

        merchantSendJson(true, $promo, 'Promo berhasil disimpan');
    }

    if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        if ($id === '') {
            merchantSendJson(false, null, 'ID promo wajib diisi', 400);
        }
        $stmt = $conn->prepare("UPDATE merchant_promos SET is_active = 0, updated_at = NOW() WHERE id = ? AND merchant_id = ?");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param('ss', $id, $merchantId);
        $stmt->execute();
        $affected = $stmt->affected_rows;
        $stmt->close();
        if ($affected <= 0) {
            merchantSendJson(false, null, 'Promo tidak ditemukan atau sudah nonaktif', 404);
        }
        merchantSendJson(true, ['id' => $id], 'Promo berhasil dinonaktifkan');
    }

    merchantSendJson(false, null, 'Method tidak didukung', 405);
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
