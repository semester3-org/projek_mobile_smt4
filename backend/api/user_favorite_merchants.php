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
        function ($row) {
            return userFavoriteKey((string)$row['merchant_type'], (string)$row['merchant_id']);
        },
        $rows
    );
    return [
        'keys' => $keys,
        'items' => array_map(
            function ($row) {
                return [
                    'type' => (string)$row['merchant_type'],
                    'merchantId' => (string)$row['merchant_id'],
                    'key' => userFavoriteKey((string)$row['merchant_type'], (string)$row['merchant_id']),
                ];
            },
            $rows
        ),
    ];
}

function userFavoriteInput(): array {
    $body = merchantBody();
    $merchantInput = trim((string)($body['merchantId'] ?? $_GET['merchantId'] ?? ''));
    $type = strtolower(trim((string)($body['type'] ?? $_GET['type'] ?? '')));
    $action = strtolower(trim((string)($body['action'] ?? 'toggle')));
    return [$merchantInput, $type, $action];
}

function userFavoriteNeedsExplicitId(mysqli $conn): bool {
    $stmt = $conn->prepare("
        SELECT EXTRA, IS_NULLABLE, COLUMN_DEFAULT
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'user_favorite_merchants'
          AND COLUMN_NAME = 'id'
        LIMIT 1
    ");
    if (!$stmt) return false;
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) return false;

    $extra = strtolower((string)($row['EXTRA'] ?? ''));
    $nullable = strtoupper((string)($row['IS_NULLABLE'] ?? 'YES'));
    $default = $row['COLUMN_DEFAULT'] ?? null;
    return strpos($extra, 'auto_increment') === false &&
        $nullable === 'NO' &&
        $default === null;
}

function userFavoriteGeneratedId(): string {
    try {
        return (string)random_int(100000000, 999999999);
    } catch (Throwable $e) {
        return (string)time();
    }
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
        if (in_array($action, ['add', 'favorite', 'save'], true)) {
            $shouldFavorite = true;
        } elseif (in_array($action, ['remove', 'delete', 'unfavorite'], true)) {
            $shouldFavorite = false;
        } else {
            $shouldFavorite = !$exists;
        }
    }

    if ($shouldFavorite && !$exists) {
        $needsExplicitId = userFavoriteNeedsExplicitId($conn);
        $stmt = $needsExplicitId
            ? $conn->prepare("
                INSERT INTO user_favorite_merchants
                    (id, user_id, merchant_id, merchant_type, created_at, updated_at)
                VALUES (?, ?, ?, ?, NOW(), NOW())
            ")
            : $conn->prepare("
                INSERT INTO user_favorite_merchants
                    (user_id, merchant_id, merchant_type, created_at, updated_at)
                VALUES (?, ?, ?, NOW(), NOW())
            ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        if ($needsExplicitId) {
            $id = userFavoriteGeneratedId();
            $stmt->bind_param('ssss', $id, $userId, $merchantId, $type);
        } else {
            $stmt->bind_param('sss', $userId, $merchantId, $type);
        }
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
