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

function laundryEstimatePayload(array $row): array {
    $minH = (int)($row['min_hours'] ?? 0);
    $maxH = (int)($row['max_hours'] ?? 0);
    $label = (string)($row['service_name'] ?? '');
    if ($label === '' && $minH > 0) {
        if ($maxH <= 24) {
            $label = "Estimasi $minH" . ($maxH > $minH ? "-$maxH" : '') . ' jam';
        } else {
            $label = 'Estimasi ' . max(1, (int)ceil($minH / 24)) . '-' . max(1, (int)ceil($maxH / 24)) . ' hari';
        }
    }
    return [
        'id' => (string)($row['id'] ?? ''),
        'serviceName' => (string)($row['service_name'] ?? ''),
        'minHours' => $minH,
        'maxHours' => $maxH,
        'estimateLabel' => $label,
        'isActive' => (int)($row['is_active'] ?? 1) === 1,
    ];
}

try {
    merchantEnsureSchema($conn);
    $payload = merchantRequireMerchant();
    $merchant = merchantCurrent($conn, $payload);
    $merchantId = (string)$merchant['id'];

    if (!merchantTableExists($conn, 'laundry_service_estimates')) {
        merchantSendJson(false, null, 'Tabel estimasi belum tersedia. Jalankan migrasi database.', 500);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $stmt = $conn->prepare("
            SELECT * FROM laundry_service_estimates
            WHERE merchant_id = ?
            ORDER BY is_active DESC, service_name ASC
        ");
        $stmt->bind_param('s', $merchantId);
        $stmt->execute();
        $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        merchantSendJson(true, array_map('laundryEstimatePayload', $rows), 'Estimasi layanan dimuat');
    }

    $body = merchantBody();
    $id = trim((string)($body['id'] ?? $_GET['id'] ?? ''));
    $serviceName = trim((string)($body['serviceName'] ?? ''));
    $minHours = (int)($body['minHours'] ?? 0);
    $maxHours = (int)($body['maxHours'] ?? 0);
    $isActive = !array_key_exists('isActive', $body) || !empty($body['isActive']) ? 1 : 0;

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if ($serviceName === '' || $maxHours <= 0) {
            merchantSendJson(false, null, 'Nama layanan dan estimasi wajib diisi', 400);
        }
        if ($minHours <= 0) {
            $minHours = 1;
        }
        $id = merchantUuid();
        $stmt = $conn->prepare("
            INSERT INTO laundry_service_estimates (id, merchant_id, service_name, min_hours, max_hours, is_active)
            VALUES (?, ?, ?, ?, ?, ?)
        ");
        $stmt->bind_param('sssiii', $id, $merchantId, $serviceName, $minHours, $maxHours, $isActive);
        $stmt->execute();
        $stmt->close();
        merchantSendJson(true, ['id' => $id], 'Estimasi layanan ditambahkan');
    }

    if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        if ($id === '' || $serviceName === '') {
            merchantSendJson(false, null, 'ID dan nama layanan wajib diisi', 400);
        }
        $stmt = $conn->prepare("
            UPDATE laundry_service_estimates
            SET service_name = ?, min_hours = ?, max_hours = ?, is_active = ?, updated_at = NOW()
            WHERE id = ? AND merchant_id = ?
        ");
        $stmt->bind_param('siiiss', $serviceName, $minHours, $maxHours, $isActive, $id, $merchantId);
        $stmt->execute();
        $stmt->close();
        merchantSendJson(true, ['id' => $id], 'Estimasi diperbarui');
    }

    if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        if ($id === '') {
            merchantSendJson(false, null, 'ID wajib diisi', 400);
        }
        $stmt = $conn->prepare("
            UPDATE laundry_service_estimates SET is_active = 0, updated_at = NOW()
            WHERE id = ? AND merchant_id = ?
        ");
        $stmt->bind_param('ss', $id, $merchantId);
        $stmt->execute();
        $stmt->close();
        merchantSendJson(true, ['id' => $id], 'Estimasi dinonaktifkan');
    }

    merchantSendJson(false, null, 'Method tidak didukung', 405);
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}
