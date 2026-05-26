<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function userFavoriteKey(string $type, string $merchantId): string {
    return $type . ':' . $merchantId;
}

function userFavoriteRows(mysqli $conn, string $userId): array {
    $stmt = $conn->prepare("
        SELECT merchant_type, merchant_id
        FROM user_favorite_merchants
        WHERE user_id = ?
        ORDER BY created_at DESC
    ");
    if (!$stmt) {
        merchantSendJson(false, null, 'Database error', 500);
    }
    $stmt->bind_param('s', $userId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return $rows;
}

function userFavoritePayload(mysqli $conn, string $userId): array {
    $rows = userFavoriteRows($conn, $userId);
    $keys = array_map(
        fn($row) => userFavoriteKey((string)$row['merchant_type'], (string)$row['merchant_id']),
        $rows
    );
    return [
        'keys' => $keys,
        'items' => array_map(fn($row) => [
            'type' => (string)$row['merchant_type'],
            'merchantId' => (string)$row['merchant_id'],
            'key' => userFavoriteKey((string)$row['merchant_type'], (string)$row['merchant_id']),
        ], $rows),
    ];
}

function userFavoriteInput(): array {
    $body = merchantBody();
    $merchantInput = trim((string)($body['merchantId'] ?? $_GET['merchantId'] ?? ''));
    $type = strtolower(trim((string)($body['type'] ?? $_GET['type'] ?? '')));
    $action = strtolower(trim((string)($body['action'] ?? 'toggle')));
    return [$merchantInput, $type, $action];
}

try {
    merchantEnsureSchema($conn);
    $payload = merchantRequireAuth();
    $userId = (string)($payload['sub'] ?? '');
    if ($userId === '') {
        merchantSendJson(false, null, 'User tidak valid', 401);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        merchantSendJson(true, userFavoritePayload($conn, $userId), 'Favorite berhasil dimuat');
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST' && $_SERVER['REQUEST_METHOD'] !== 'DELETE') {
        merchantSendJson(false, null, 'Only GET, POST, or DELETE method allowed', 405);
    }

    [$merchantInput, $type, $action] = userFavoriteInput();
    if (!in_array($type, ['laundry', 'catering'], true)) {
        merchantSendJson(false, null, 'Tipe merchant tidak valid', 400);
    }

    $merchantId = merchantResolveMerchantId($conn, $merchantInput);
    if (!$merchantId) {
        merchantSendJson(false, null, 'Merchant tidak ditemukan', 404);
    }

    $merchantType = merchantQueryValue(
        $conn,
        'SELECT merchant_type FROM merchants WHERE id = ? LIMIT 1',
        's',
        [$merchantId]
    );
    if ($merchantType && in_array((string)$merchantType, ['laundry', 'catering'], true)) {
        $type = (string)$merchantType;
    }

    $exists = merchantQueryValue(
        $conn,
        'SELECT id FROM user_favorite_merchants WHERE user_id = ? AND merchant_id = ? AND merchant_type = ? LIMIT 1',
        'sss',
        [$userId, $merchantId, $type]
    );

    $shouldFavorite = $_SERVER['REQUEST_METHOD'] !== 'DELETE';
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $shouldFavorite = match ($action) {
            'add', 'favorite', 'save' => true,
            'remove', 'delete', 'unfavorite' => false,
            default => !$exists,
        };
    }

    if ($shouldFavorite && !$exists) {
        $stmt = $conn->prepare("
            INSERT INTO user_favorite_merchants
                (user_id, merchant_id, merchant_type, created_at, updated_at)
            VALUES (?, ?, ?, NOW(), NOW())
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param('sss', $userId, $merchantId, $type);
        $stmt->execute();
        $stmt->close();
    } elseif (!$shouldFavorite && $exists) {
        $stmt = $conn->prepare("
            DELETE FROM user_favorite_merchants
            WHERE user_id = ? AND merchant_id = ? AND merchant_type = ?
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param('sss', $userId, $merchantId, $type);
        $stmt->execute();
        $stmt->close();
    }

    merchantSendJson(true, [
        'favorite' => $shouldFavorite,
        'type' => $type,
        'merchantId' => $merchantId,
        'key' => userFavoriteKey($type, $merchantId),
        'keys' => userFavoritePayload($conn, $userId)['keys'],
    ], $shouldFavorite ? 'Disimpan ke favorite' : 'Dihapus dari favorite');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
