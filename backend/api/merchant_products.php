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

try {
    $payload = merchantRequireMerchant();
    $merchant = merchantCurrent($conn, $payload);
    $merchantId = (string)$merchant['id'];
    $merchantType = merchantTypeFromRow($merchant);

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $id = trim($_GET['id'] ?? '');
        $includeInactive = !empty($_GET['includeInactive']);
        $where = 'merchant_id = ?';
        $types = 's';
        $params = [$merchantId];

        if ($id !== '') {
            $where .= ' AND CAST(id AS CHAR) = ?';
            $types .= 's';
            $params[] = $id;
        } elseif (!$includeInactive) {
            $where .= ' AND is_active = 1';
        }

        $stmt = $conn->prepare("
            SELECT *
            FROM products
            WHERE $where
            ORDER BY is_active DESC, updated_at DESC, id DESC
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();

        $data = array_map(fn($row) => merchantProductPayload($row, $conn), $rows);
        if ($id !== '') {
            if (empty($data)) {
                merchantSendJson(false, null, 'Produk tidak ditemukan', 404);
            }
            merchantSendJson(true, $data[0], 'Produk berhasil dimuat');
        }
        merchantSendJson(true, $data, 'Produk merchant berhasil dimuat');
    }

    $body = merchantBody();
    $id = trim((string)($body['id'] ?? $_GET['id'] ?? ''));
    $name = trim((string)($body['name'] ?? $body['namaProduk'] ?? ''));
    $description = trim((string)($body['description'] ?? ''));
    $price = (float)($body['price'] ?? 0);
    $price20Days = (float)($body['price20Days'] ?? 0);
    $category = trim((string)($body['category'] ?? ''));
    $pricingType = merchantNormalizePricingType($body['pricingType'] ?? $body['pricing_type'] ?? 'per_kg');
    $unit = $merchantType === 'laundry'
        ? merchantPricingUnit($pricingType)
        : trim((string)($body['unit'] ?? ''));
    $durationValue = isset($body['durationValue']) ? (int)$body['durationValue'] : null;
    $durationUnit = merchantNormalizeDurationUnit($body['durationUnit'] ?? 'day');
    $addons = is_array($body['addons'] ?? null) ? $body['addons'] : [];
    $packageDeliveryType = null;
    $imageUrl = trim((string)($body['imageUrl'] ?? ''));
    $isActive = !array_key_exists('isActive', $body) || !empty($body['isActive']) ? 1 : 0;

    if ($_SERVER['REQUEST_METHOD'] === 'POST' || $_SERVER['REQUEST_METHOD'] === 'PUT') {
        if ($name === '') {
            merchantSendJson(false, null, 'Nama layanan/produk wajib diisi', 400);
        }
        if ($price <= 0) {
            merchantSendJson(false, null, 'Harga wajib lebih dari 0', 400);
        }
        if ($merchantType === 'laundry' && ($durationValue === null || $durationValue <= 0)) {
            merchantSendJson(false, null, 'Estimasi durasi layanan wajib diisi', 400);
        }

        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $stmt = $conn->prepare("
                INSERT INTO products
                    (merchant_id, nama_produk, harga, price_20_days, deskripsi, category, unit, image_url,
                     is_active, service_type, package_delivery_type, pricing_type, duration_value, duration_unit,
                     created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Database error', 500);
            }
            $price20Value = $merchantType === 'catering' ? $price20Days : 0.0;
            $stmt->bind_param(
                'ssddssssisssis',
                $merchantId,
                $name,
                $price,
                $price20Value,
                $description,
                $category,
                $unit,
                $imageUrl,
                $isActive,
                $merchantType,
                $packageDeliveryType,
                $pricingType,
                $durationValue,
                $durationUnit
            );
            $stmt->execute();
            $id = (string)$conn->insert_id;
            $stmt->close();
        } else {
            if ($id === '') {
                merchantSendJson(false, null, 'ID produk wajib diisi', 400);
            }
            $price20Value = $merchantType === 'catering' ? $price20Days : 0.0;
            $stmt = $conn->prepare("
                UPDATE products
                SET nama_produk = ?,
                    harga = ?,
                    price_20_days = ?,
                    deskripsi = ?,
                    category = ?,
                    unit = ?,
                    image_url = ?,
                    is_active = ?,
                    service_type = ?,
                    package_delivery_type = ?,
                    pricing_type = ?,
                    duration_value = ?,
                    duration_unit = ?,
                    updated_at = NOW()
                WHERE id = ? AND merchant_id = ?
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Database error', 500);
            }
            $stmt->bind_param(
                'sddssssisssiss',
                $name,
                $price,
                $price20Value,
                $description,
                $category,
                $unit,
                $imageUrl,
                $isActive,
                $merchantType,
                $packageDeliveryType,
                $pricingType,
                $durationValue,
                $durationUnit,
                $id,
                $merchantId
            );
            $stmt->execute();
            $stmt->close();
        }

        if ($merchantType === 'laundry') {
            merchantSyncProductAddons($conn, $merchantId, (int)$id, $addons);
        }

        $stmt = $conn->prepare("SELECT * FROM products WHERE id = ? AND merchant_id = ? LIMIT 1");
        $stmt->bind_param('ss', $id, $merchantId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        merchantSyncPlace($conn, $merchant);
        merchantSendJson(true, merchantProductPayload($row ?? [], $conn), 'Produk berhasil disimpan');
    }

    if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        if ($id === '') {
            merchantSendJson(false, null, 'ID produk wajib diisi', 400);
        }
        $stmt = $conn->prepare("UPDATE products SET is_active = 0, updated_at = NOW() WHERE id = ? AND merchant_id = ?");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param('ss', $id, $merchantId);
        $stmt->execute();
        $stmt->close();
        merchantSendJson(true, ['id' => $id], 'Produk berhasil dihapus dari katalog aktif');
    }

    merchantSendJson(false, null, 'Method tidak didukung', 405);
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
