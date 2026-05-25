<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    $payload = merchantRequireMerchant();
    $merchant = merchantCurrent($conn, $payload);

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        merchantSendJson(true, merchantProfilePayload($conn, $merchant), 'Profil merchant berhasil dimuat');
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
        merchantSendJson(false, null, 'Only GET or PUT method allowed', 405);
    }

    $body = merchantBody();
    $businessName = trim((string)($body['businessName'] ?? ''));
    $description = trim((string)($body['description'] ?? ''));
    $phone = trim((string)($body['phone'] ?? ''));
    $address = trim((string)($body['address'] ?? ''));
    $photoUrl = trim((string)($body['photoUrl'] ?? ''));
    $openTime = trim((string)($body['openTime'] ?? '08:00'));
    $closeTime = trim((string)($body['closeTime'] ?? '21:00'));
    $latitude = isset($body['latitude']) && $body['latitude'] !== '' ? (float)$body['latitude'] : null;
    $longitude = isset($body['longitude']) && $body['longitude'] !== '' ? (float)$body['longitude'] : null;
    $categories = $body['categories'] ?? [];

    if ($businessName === '') {
        merchantSendJson(false, null, 'Nama merchant wajib diisi', 400);
    }

    if (!is_array($categories)) {
        $categories = [];
    }
    $categories = array_values(array_filter(array_map(
        fn($item) => trim((string)$item),
        $categories
    )));
    if (empty($categories)) {
        $categories = merchantCategories(null, merchantTypeFromRow($merchant));
    }
    $categoryRaw = implode(',', $categories);
    $merchantId = (string)$merchant['id'];

    $stmt = $conn->prepare("
        UPDATE merchants
        SET business_name = ?,
            description = ?,
            phone = NULLIF(?, ''),
            address = NULLIF(?, ''),
            photo_url = NULLIF(?, ''),
            latitude = ?,
            longitude = ?,
            open_time = ?,
            close_time = ?,
            service_categories = ?,
            updated_at = NOW()
        WHERE id = ?
    ");
    if (!$stmt) {
        merchantSendJson(false, null, 'Database error', 500);
    }
    $stmt->bind_param(
        'sssssddssss',
        $businessName,
        $description,
        $phone,
        $address,
        $photoUrl,
        $latitude,
        $longitude,
        $openTime,
        $closeTime,
        $categoryRaw,
        $merchantId
    );
    $stmt->execute();
    $stmt->close();

    if (merchantTableExists($conn, 'users')) {
        $userId = (string)$merchant['user_id'];
        $stmt = $conn->prepare("UPDATE users SET display_name = ?, phone = NULLIF(?, ''), address = NULLIF(?, ''), updated_at = NOW() WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param('ssss', $businessName, $phone, $address, $userId);
            $stmt->execute();
            $stmt->close();
        }
    }

    $updated = merchantCurrent($conn, $payload);
    merchantSyncPlace($conn, $updated);

    merchantSendJson(true, merchantProfilePayload($conn, $updated), 'Profil merchant berhasil diperbarui');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
