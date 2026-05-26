<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function cateringSubscriberPayload(mysqli $conn, array $row): array {
    $orderId = (int)($row['order_id'] ?? 0);
    $productName = '';
    $productDescription = '';
    $totalAmount = (float)($row['total_harga'] ?? 0);

    if ($orderId > 0 && merchantTableExists($conn, 'order_items')) {
        $stmt = $conn->prepare("
            SELECT p.nama_produk, p.deskripsi, oi.qty, oi.harga
            FROM order_items oi
            LEFT JOIN products p ON p.id = oi.product_id
            WHERE oi.order_id = ?
            ORDER BY oi.id ASC
            LIMIT 1
        ");
        if ($stmt) {
            $stmt->bind_param('i', $orderId);
            $stmt->execute();
            $item = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            if ($item) {
                $productName = (string)($item['nama_produk'] ?? '');
                $productDescription = (string)($item['deskripsi'] ?? '');
            }
        }
    }

    $status = strtolower((string)($row['subscription_status'] ?? 'active'));
    if (!empty($row['subscription_end_date']) &&
        strtotime((string)$row['subscription_end_date']) < strtotime('today') &&
        $status === 'active') {
        $status = 'expired';
    }

    return [
        'id' => (string)($row['subscriber_id'] ?? $row['id'] ?? ''),
        'orderId' => (string)$orderId,
        'orderCode' => (string)($row['order_code'] ?? ''),
        'userId' => (string)($row['user_id'] ?? ''),
        'userName' => (string)($row['display_name'] ?? 'User'),
        'userPhone' => (string)($row['phone'] ?? ''),
        'merchantId' => (string)($row['merchant_id'] ?? ''),
        'merchantName' => (string)($row['business_name'] ?? ''),
        'packageType' => (string)($row['package_type'] ?? ''),
        'packageLabel' => str_contains((string)($row['package_type'] ?? ''), '20')
            ? 'Paket 20 Hari'
            : 'Paket 30 Hari',
        'productName' => $productName,
        'productDescription' => $productDescription,
        'startDate' => $row['start_date'] ?? $row['subscription_start_date'] ?? null,
        'endDate' => $row['end_date'] ?? $row['subscription_end_date'] ?? null,
        'subscriptionStatus' => $status,
        'totalAmount' => $totalAmount,
        'cancellationRequestedAt' => $row['cancellation_requested_at'] ?? null,
    ];
}

try {
    merchantEnsureSchema($conn);
    merchantExpireFinishedCateringSubscriptions($conn);

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        merchantSendJson(false, null, 'Only GET allowed', 405);
    }

    $payload = merchantRequireAuth();
    $role = (string)($payload['role'] ?? '');
    $userId = (string)($payload['sub'] ?? '');
    $filter = strtolower(trim($_GET['status'] ?? 'all'));

    if (!merchantTableExists($conn, 'catering_subscribers')) {
        merchantSendJson(true, [], 'Belum ada data pelanggan');
    }

    if ($role === 'merchant') {
        $merchant = merchantCurrent($conn, $payload);
        $merchantId = (string)$merchant['id'];
        $sql = "
            SELECT cs.id AS subscriber_id, cs.*, o.order_code, o.total_harga,
                   o.subscription_start_date, o.subscription_end_date,
                   u.display_name, u.phone, m.business_name
            FROM catering_subscribers cs
            INNER JOIN orders o ON o.id = cs.order_id
            INNER JOIN users u ON u.id = cs.user_id
            INNER JOIN merchants m ON m.id = cs.merchant_id
            WHERE cs.merchant_id = ?
        ";
        if ($filter === 'active') {
            $sql .= " AND cs.subscription_status IN ('active', 'cancel_requested') AND (cs.end_date IS NULL OR cs.end_date >= CURDATE())";
        } elseif ($filter === 'expired') {
            $sql .= " AND (cs.subscription_status = 'expired' OR (cs.end_date IS NOT NULL AND cs.end_date < CURDATE()))";
        }
        $sql .= ' ORDER BY cs.end_date DESC, cs.created_at DESC';
        $stmt = $conn->prepare($sql);
        $stmt->bind_param('s', $merchantId);
    } else {
        userSyncCateringSubscribersForUser($conn, $userId);
        $sql = "
            SELECT cs.id AS subscriber_id, cs.*, o.order_code, o.total_harga,
                   o.subscription_start_date, o.subscription_end_date,
                   u.display_name, u.phone, m.business_name
            FROM catering_subscribers cs
            INNER JOIN orders o ON o.id = cs.order_id
            INNER JOIN users u ON u.id = cs.user_id
            INNER JOIN merchants m ON m.id = cs.merchant_id
            WHERE cs.user_id = ?
        ";
        if ($filter === 'active') {
            $sql .= " AND cs.subscription_status IN ('active', 'cancel_requested') AND (cs.end_date IS NULL OR cs.end_date >= CURDATE())";
        } elseif ($filter === 'expired') {
            $sql .= " AND (cs.subscription_status = 'expired' OR (cs.end_date IS NOT NULL AND cs.end_date < CURDATE()))";
        }
        $sql .= ' ORDER BY cs.end_date DESC, cs.created_at DESC';
        $stmt = $conn->prepare($sql);
        $stmt->bind_param('s', $userId);
    }

    if (!$stmt) {
        merchantSendJson(false, null, 'Database error', 500);
    }
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $data = array_map(fn($row) => cateringSubscriberPayload($conn, $row), $rows);
    merchantSendJson(true, $data, 'Data pelanggan catering berhasil dimuat');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}
