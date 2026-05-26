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
    merchantEnsureSchema($conn);
    $payload = merchantRequireMerchant();
    $merchant = merchantCurrent($conn, $payload);
    $merchantId = (string)$merchant['id'];

    if (!merchantTableExists($conn, 'catering_package_categories')) {
        merchantSendJson(false, null, 'Tabel kategori belum tersedia. Jalankan migrasi database.', 500);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $stmt = $conn->prepare("
            SELECT * FROM catering_package_categories
            WHERE merchant_id = ?
            ORDER BY is_active DESC, category_name ASC
        ");
        $stmt->bind_param('s', $merchantId);
        $stmt->execute();
        $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        $data = array_map(fn($r) => [
            'id' => (string)$r['id'],
            'categoryName' => $r['category_name'],
            'description' => $r['description'] ?? '',
            'isActive' => (int)($r['is_active'] ?? 1) === 1,
        ], $rows);
        merchantSendJson(true, $data, 'Kategori paket berhasil dimuat');
    }

    $body = merchantBody();
    $id = trim((string)($body['id'] ?? $_GET['id'] ?? ''));
    $name = trim((string)($body['categoryName'] ?? $body['name'] ?? ''));
    $description = trim((string)($body['description'] ?? ''));
    $isActive = !array_key_exists('isActive', $body) || !empty($body['isActive']) ? 1 : 0;

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if ($name === '') {
            merchantSendJson(false, null, 'Nama kategori wajib diisi', 400);
        }
        $id = merchantUuid();
        $stmt = $conn->prepare("
            INSERT INTO catering_package_categories (id, merchant_id, category_name, description, is_active)
            VALUES (?, ?, ?, ?, ?)
        ");
        $stmt->bind_param('ssssi', $id, $merchantId, $name, $description, $isActive);
        $stmt->execute();
        $stmt->close();
        merchantSendJson(true, ['id' => $id], 'Kategori berhasil ditambahkan');
    }

    if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        if ($id === '' || $name === '') {
            merchantSendJson(false, null, 'ID dan nama kategori wajib diisi', 400);
        }
        $stmt = $conn->prepare("
            UPDATE catering_package_categories
            SET category_name = ?, description = ?, is_active = ?, updated_at = NOW()
            WHERE id = ? AND merchant_id = ?
        ");
        $stmt->bind_param('ssiss', $name, $description, $isActive, $id, $merchantId);
        $stmt->execute();
        $stmt->close();
        merchantSendJson(true, ['id' => $id], 'Kategori berhasil diperbarui');
    }

    if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        if ($id === '') {
            merchantSendJson(false, null, 'ID kategori wajib diisi', 400);
        }
        $stmt = $conn->prepare("
            UPDATE catering_package_categories SET is_active = 0, updated_at = NOW()
            WHERE id = ? AND merchant_id = ?
        ");
        $stmt->bind_param('ss', $id, $merchantId);
        $stmt->execute();
        $stmt->close();
        merchantSendJson(true, ['id' => $id], 'Kategori dinonaktifkan');
    }

    merchantSendJson(false, null, 'Method tidak didukung', 405);
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}
