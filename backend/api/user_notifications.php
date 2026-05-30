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
    merchantEnsureSchema($conn);
    $payload = merchantRequireAuth();
    $userId = (string)($payload['sub'] ?? '');

    if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        if (!merchantTableExists($conn, 'app_notifications')) {
            merchantSendJson(true, ['updated' => 0], 'Notifikasi belum tersedia');
        }

        $body = merchantBody();
        $action = strtolower(trim((string)($body['action'] ?? '')));
        $id = trim((string)($body['id'] ?? ''));

        if ($action === 'mark_all_read') {
            $stmt = $conn->prepare("
                UPDATE app_notifications
                SET read_at = COALESCE(read_at, NOW()), updated_at = NOW()
                WHERE user_id = ? AND read_at IS NULL
            ");
            if (!$stmt) merchantSendJson(false, null, 'Database error', 500);
            $stmt->bind_param('s', $userId);
            $stmt->execute();
            $updated = $stmt->affected_rows;
            $stmt->close();
            merchantSendJson(true, ['updated' => $updated], 'Semua notifikasi ditandai sudah dibaca');
        }

        if ($action === 'mark_read' && $id !== '') {
            $numericId = preg_replace('/\D+/', '', $id);
            $stmt = $conn->prepare("
                UPDATE app_notifications
                SET read_at = COALESCE(read_at, NOW()), updated_at = NOW()
                WHERE id = ? AND user_id = ?
            ");
            if (!$stmt) merchantSendJson(false, null, 'Database error', 500);
            $stmt->bind_param('ss', $numericId, $userId);
            $stmt->execute();
            $updated = $stmt->affected_rows;
            $stmt->close();
            merchantSendJson(true, ['updated' => $updated], 'Notifikasi ditandai sudah dibaca');
        }

        merchantSendJson(false, null, 'Aksi notifikasi tidak valid', 400);
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        merchantSendJson(false, null, 'Only GET or PUT method allowed', 405);
    }

    $items = [];
    if (merchantTableExists($conn, 'app_notifications')) {
        if (!empty($_GET['count'])) {
            $stmt = $conn->prepare("
                SELECT COUNT(*) AS total
                FROM app_notifications
                WHERE user_id = ? AND read_at IS NULL
            ");
            if (!$stmt) merchantSendJson(false, null, 'Database error', 500);
            $stmt->bind_param('s', $userId);
            $stmt->execute();
            $row = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            merchantSendJson(true, ['count' => (int)($row['total'] ?? 0)], 'Jumlah notifikasi belum dibaca berhasil dimuat');
        }

        $limit = isset($_GET['limit']) ? max(1, min(50, (int)$_GET['limit'])) : 30;
        $hasType = merchantColumnExists($conn, 'app_notifications', 'type');
        $hasAction = merchantColumnExists($conn, 'app_notifications', 'action_text');
        $hasActionUrl = merchantColumnExists($conn, 'app_notifications', 'action_url');
        $stmt = $conn->prepare("
            SELECT id, title, message, read_at, created_at,
                   " . ($hasType ? "type" : "NULL") . " AS type,
                   " . ($hasAction ? "action_text" : "NULL") . " AS action_text,
                   " . ($hasActionUrl ? "action_url" : "NULL") . " AS action_url
            FROM app_notifications
            WHERE user_id = ?
            ORDER BY created_at DESC, id DESC
            LIMIT ?
        ");
        if ($stmt) {
            $stmt->bind_param('si', $userId, $limit);
            $stmt->execute();
            $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            $stmt->close();
            foreach ($rows as $row) {
                $title = (string)$row['title'];
                $type = $row['type'] ?: (stripos($title, 'promo') !== false ? 'promo' : (stripos($title, 'bayar') !== false ? 'payment' : 'order'));
                $items[] = [
                    'id' => 'notif-' . (string)$row['id'],
                    'title' => $title,
                    'message' => $row['message'],
                    'type' => $type,
                    'status' => empty($row['read_at']) ? 'baru' : 'dibaca',
                    'createdAt' => date(DATE_ATOM, strtotime($row['created_at'] ?? 'now')),
                    'hasAction' => !empty($row['action_text']),
                    'actionButtonText' => $row['action_text'],
                    'actionUrl' => $row['action_url'],
                ];
            }
        }
    }

    merchantSendJson(true, $items, 'Notifikasi user berhasil dimuat');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
