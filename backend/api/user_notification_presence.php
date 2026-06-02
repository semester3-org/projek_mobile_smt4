<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    merchantEnsureSchema($conn);
    $payload = merchantRequireAuth();
    $userId = (string)($payload['sub'] ?? '');
    $body = merchantBody();

    if ($userId === '') {
        merchantSendJson(false, null, 'User tidak valid', 401);
    }

    $method = $_SERVER['REQUEST_METHOD'];
    $token = trim((string)($body['fcmToken'] ?? $body['fcm_token'] ?? ''));
    $platform = substr(trim((string)($body['platform'] ?? 'flutter')), 0, 30);
    if ($platform === '') $platform = 'flutter';

    if ($method === 'DELETE') {
        if ($token !== '' && merchantTableExists($conn, 'user_notification_devices')) {
            $stmt = $conn->prepare("
                UPDATE user_notification_devices
                SET is_active = 0, updated_at = NOW()
                WHERE user_id = ? AND fcm_token = ?
            ");
            if ($stmt) {
                $stmt->bind_param('ss', $userId, $token);
                $stmt->execute();
                $stmt->close();
            }
        }

        if (merchantTableExists($conn, 'user_app_presence')) {
            $stmt = $conn->prepare("
                INSERT INTO user_app_presence (user_id, is_active, last_seen_at, created_at, updated_at)
                VALUES (?, 0, NOW(), NOW(), NOW())
                ON DUPLICATE KEY UPDATE is_active = 0, last_seen_at = NOW(), updated_at = NOW()
            ");
            if ($stmt) {
                $stmt->bind_param('s', $userId);
                $stmt->execute();
                $stmt->close();
            }
        }

        merchantSendJson(true, ['active' => false], 'Presence notifikasi dinonaktifkan');
    }

    if ($method !== 'POST' && $method !== 'PUT') {
        merchantSendJson(false, null, 'Only POST, PUT or DELETE method allowed', 405);
    }

    $rawActive = $body['isActive'] ?? $body['active'] ?? true;
    $parsedActive = filter_var($rawActive, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
    $isActive = $parsedActive === null ? true : $parsedActive;
    $activeInt = $isActive ? 1 : 0;

    if (merchantTableExists($conn, 'user_app_presence')) {
        $stmt = $conn->prepare("
            INSERT INTO user_app_presence (user_id, is_active, last_seen_at, created_at, updated_at)
            VALUES (?, ?, NOW(), NOW(), NOW())
            ON DUPLICATE KEY UPDATE is_active = VALUES(is_active), last_seen_at = NOW(), updated_at = NOW()
        ");
        if (!$stmt) merchantSendJson(false, null, 'Database error', 500);
        $stmt->bind_param('si', $userId, $activeInt);
        $stmt->execute();
        $stmt->close();
    }

    if ($token !== '' && merchantTableExists($conn, 'user_notification_devices')) {
        $stmt = $conn->prepare("
            INSERT INTO user_notification_devices (user_id, fcm_token, platform, is_active, last_seen_at, created_at, updated_at)
            VALUES (?, ?, ?, ?, NOW(), NOW(), NOW())
            ON DUPLICATE KEY UPDATE
                user_id = VALUES(user_id),
                platform = VALUES(platform),
                is_active = VALUES(is_active),
                last_seen_at = NOW(),
                updated_at = NOW()
        ");
        if (!$stmt) merchantSendJson(false, null, 'Database error', 500);
        $stmt->bind_param('sssi', $userId, $token, $platform, $activeInt);
        $stmt->execute();
        $stmt->close();
    }

    merchantSendJson(true, ['active' => $isActive], 'Presence notifikasi diperbarui');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
