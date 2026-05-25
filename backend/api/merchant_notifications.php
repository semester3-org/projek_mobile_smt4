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
    $merchantId = (string)$merchant['id'];
    $userId = (string)$merchant['user_id'];

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
    $seenOrderIds = [];

    if (merchantTableExists($conn, 'app_notifications')) {
        $hasType = merchantColumnExists($conn, 'app_notifications', 'type');
        $hasAction = merchantColumnExists($conn, 'app_notifications', 'action_text');
        $hasActionUrl = merchantColumnExists($conn, 'app_notifications', 'action_url');
        $stmt = $conn->prepare("
            SELECT id, title, message, read_at, created_at,
                   " . ($hasType ? "type" : "'info'") . " AS type,
                   " . ($hasAction ? "action_text" : "NULL") . " AS action_text,
                   " . ($hasActionUrl ? "action_url" : "NULL") . " AS action_url
            FROM app_notifications
            WHERE user_id = ?
            ORDER BY created_at DESC, id DESC
            LIMIT 20
        ");
        if ($stmt) {
            $stmt->bind_param('s', $userId);
            $stmt->execute();
            $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            $stmt->close();
            foreach ($rows as $row) {
                $items[] = [
                    'id' => 'notif-' . (string)$row['id'],
                    'title' => $row['title'],
                    'message' => $row['message'],
                    'type' => $row['type'] ?: 'info',
                    'status' => empty($row['read_at']) ? 'baru' : 'dibaca',
                    'createdAt' => date(DATE_ATOM, strtotime($row['created_at'] ?? 'now')),
                    'actionButtonText' => $row['action_text'],
                    'actionUrl' => $row['action_url'],
                ];
                if (!empty($row['action_url']) && str_starts_with((string)$row['action_url'], 'order:')) {
                    $seenOrderIds[] = substr((string)$row['action_url'], 6);
                }
            }
        }
    }

    $orders = merchantOrderQuery($conn, $merchantId, null, null, null, 5);
    foreach ($orders as $order) {
        if (in_array((string)$order['id'], $seenOrderIds, true)) {
            continue;
        }
        $items[] = [
            'id' => 'order-' . $order['id'],
            'title' => $order['status'] === 'pending' ? 'Pesanan baru menunggu diproses' : 'Update pesanan ' . $order['statusLabel'],
            'message' => $order['code'] . ' dari ' . $order['customerName'] . ' senilai Rp ' . number_format($order['totalAmount'], 0, ',', '.'),
            'type' => $order['status'] === 'pending' ? 'payment' : 'order',
            'status' => $order['status'] === 'pending' ? 'baru' : 'dibaca',
            'createdAt' => $order['createdAt'],
            'actionButtonText' => 'Lihat Pesanan',
            'actionUrl' => 'order:' . $order['id'],
        ];
    }

    usort($items, fn($a, $b) => strtotime($b['createdAt']) <=> strtotime($a['createdAt']));
    merchantSendJson(true, array_slice($items, 0, 30), 'Notifikasi merchant berhasil dimuat');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
