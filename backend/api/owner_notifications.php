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

function ownerEnsureNotificationSchema(mysqli $conn): void {
    if (!merchantTableExists($conn, 'app_notifications')) {
        $conn->query("
            CREATE TABLE app_notifications (
                id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(64) NOT NULL,
                title VARCHAR(160) NOT NULL,
                message TEXT NOT NULL,
                type VARCHAR(30) DEFAULT NULL,
                status VARCHAR(30) DEFAULT 'baru',
                action_text VARCHAR(80) DEFAULT NULL,
                action_url VARCHAR(160) DEFAULT NULL,
                importance VARCHAR(20) DEFAULT 'normal',
                read_at TIMESTAMP NULL DEFAULT NULL,
                seen_in_app_at TIMESTAMP NULL DEFAULT NULL,
                delivered_push_at TIMESTAMP NULL DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                KEY idx_notifications_user_created (user_id, created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");
    }

    if (merchantTableExists($conn, 'app_notifications')) {
        merchantAddColumn($conn, 'app_notifications', 'type', "`type` VARCHAR(30) DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'status', "`status` VARCHAR(30) DEFAULT 'baru'");
        merchantAddColumn($conn, 'app_notifications', 'action_text', "`action_text` VARCHAR(80) DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'action_url', "`action_url` VARCHAR(160) DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'importance', "`importance` VARCHAR(20) DEFAULT 'normal'");
        merchantAddColumn($conn, 'app_notifications', 'read_at', "`read_at` TIMESTAMP NULL DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'seen_in_app_at', "`seen_in_app_at` TIMESTAMP NULL DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'delivered_push_at', "`delivered_push_at` TIMESTAMP NULL DEFAULT NULL");
        merchantAddColumn($conn, 'app_notifications', 'created_at', "`created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP");
        merchantAddColumn($conn, 'app_notifications', 'updated_at', "`updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP");
        merchantAddIndex($conn, 'app_notifications', 'idx_notifications_user_created', '`user_id`, `created_at`');
    }
}

function ownerNotificationCategory(?string $type, string $title, string $message): string {
    $type = strtolower(trim((string)$type));
    $text = strtolower($title . ' ' . $message);
    if ($type === 'payment' || str_contains($text, 'bayar') || str_contains($text, 'pembayaran')) {
        return 'pembayaran';
    }
    if ($type === 'booking' || str_contains($text, 'pengajuan') || str_contains($text, 'kamar')) {
        return 'penghuni';
    }
    return 'umum';
}

function ownerTimeLabel(?string $createdAt): string {
    $createdSecs = !empty($createdAt) ? strtotime($createdAt) : false;
    if ($createdSecs === false) {
        return 'Baru saja';
    }

    $diff = time() - $createdSecs;
    if ($diff < 60) return 'Baru saja';
    if ($diff < 3600) return floor($diff / 60) . ' menit lalu';
    if ($diff < 86400) return floor($diff / 3600) . ' jam lalu';
    return date('d M Y', $createdSecs);
}

try {
    ownerEnsureNotificationSchema($conn);
    $payload = merchantRequireAuth();
    $ownerId = (string)($payload['sub'] ?? '');
    $role = $payload['role'] ?? '';
    if (!in_array($role, ['owner', 'admin'], true)) {
        merchantSendJson(false, null, 'Forbidden: hanya owner yang bisa akses', 403);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        $body = merchantBody();
        $action = strtolower(trim((string)($body['action'] ?? '')));
        $rawId = trim((string)($body['id'] ?? ''));
        $id = preg_replace('/\D+/', '', $rawId);

        if ($action === 'mark_all_read' || $rawId === '' || $rawId === '0') {
            $stmt = $conn->prepare("
                UPDATE app_notifications
                SET read_at = COALESCE(read_at, NOW()), updated_at = NOW()
                WHERE user_id = ? AND read_at IS NULL
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Database error', 500);
            }
            $stmt->bind_param('s', $ownerId);
            $stmt->execute();
            $updated = $stmt->affected_rows;
            $stmt->close();
            merchantSendJson(true, ['updated' => $updated], 'Semua notifikasi ditandai sudah dibaca');
        }

        if ($id === '') {
            merchantSendJson(false, null, 'ID notifikasi tidak valid', 400);
        }

        $stmt = $conn->prepare("
            UPDATE app_notifications
            SET read_at = COALESCE(read_at, NOW()), updated_at = NOW()
            WHERE id = ? AND user_id = ?
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param('ss', $id, $ownerId);
        $stmt->execute();
        $updated = $stmt->affected_rows;
        $stmt->close();
        merchantSendJson(true, ['updated' => $updated], 'Notifikasi ditandai sudah dibaca');
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        merchantSendJson(false, null, 'Only GET or PUT method allowed', 405);
    }

    if (!empty($_GET['count'])) {
        $stmt = $conn->prepare("
            SELECT COUNT(*) AS total
            FROM app_notifications
            WHERE user_id = ?
              AND read_at IS NULL
              AND title NOT LIKE 'Tes Notifikasi%'
              AND title <> 'Tes Push Backend'
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param('s', $ownerId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        merchantSendJson(true, ['count' => (int)($row['total'] ?? 0)], 'Jumlah notifikasi berhasil dimuat');
    }

    $limit = isset($_GET['limit']) ? max(1, min(50, (int)$_GET['limit'])) : 50;
    $stmt = $conn->prepare("
        SELECT id, title, message, type, action_text, action_url, read_at, created_at
        FROM app_notifications
        WHERE user_id = ?
          AND title NOT LIKE 'Tes Notifikasi%'
          AND title <> 'Tes Push Backend'
        ORDER BY created_at DESC, id DESC
        LIMIT ?
    ");
    if (!$stmt) {
        merchantSendJson(false, null, 'Database error', 500);
    }
    $stmt->bind_param('si', $ownerId, $limit);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $notifications = [];
    foreach ($rows as $row) {
        $title = (string)($row['title'] ?? '');
        $message = (string)($row['message'] ?? '');
        $notifications[] = [
            'id' => (int)$row['id'],
            'title' => $title,
            'subtitle' => $message,
            'time' => ownerTimeLabel($row['created_at'] ?? null),
            'category' => ownerNotificationCategory($row['type'] ?? null, $title, $message),
            'type' => (string)($row['type'] ?? 'info'),
            'actionButtonText' => $row['action_text'] ?? null,
            'actionUrl' => $row['action_url'] ?? null,
            'isRead' => !empty($row['read_at']),
        ];
    }

    merchantSendJson(true, $notifications, 'Daftar notifikasi berhasil dimuat');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}
?>
