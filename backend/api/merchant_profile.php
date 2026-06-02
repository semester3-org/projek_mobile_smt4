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

    if ($businessName === '') {
        merchantSendJson(false, null, 'Nama merchant wajib diisi', 400);
    }
    if (strlen(preg_replace('/\s+/', ' ', $businessName)) < 3) {
        merchantSendJson(false, null, 'Nama merchant minimal 3 karakter', 400);
    }
    if (!preg_match('/[A-Za-z]/', $businessName)) {
        merchantSendJson(false, null, 'Nama merchant harus memuat huruf', 400);
    }
    if ($phone !== '') {
        if (!preg_match('/^[0-9+\s().-]+$/', $phone)) {
            merchantSendJson(false, null, 'Nomor kontak hanya boleh berisi angka dan tanda +', 400);
        }
        $phoneDigits = preg_replace('/\D/', '', $phone);
        if (strlen($phoneDigits) < 10 || strlen($phoneDigits) > 15) {
            merchantSendJson(false, null, 'Nomor kontak harus 10-15 digit', 400);
        }
        $phone = $phoneDigits;
    }

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
            updated_at = NOW()
        WHERE id = ?
    ");
    if (!$stmt) {
        merchantSendJson(false, null, 'Database error', 500);
    }
    $stmt->bind_param(
        'sssssddsss',
        $businessName,
        $description,
        $phone,
        $address,
        $photoUrl,
        $latitude,
        $longitude,
        $openTime,
        $closeTime,
        $merchantId
    );
    $stmt->execute();
    $stmt->close();

    if (merchantTableExists($conn, 'users')) {
        $userId = (string)$merchant['user_id'];
        $stmt = $conn->prepare("
            UPDATE users
            SET display_name = ?,
                phone = NULLIF(?, ''),
                address = NULLIF(?, ''),
                latitude = ?,
                longitude = ?,
                updated_at = NOW()
            WHERE id = ?
        ");
        if ($stmt) {
            $stmt->bind_param('sssdds', $businessName, $phone, $address, $latitude, $longitude, $userId);
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
