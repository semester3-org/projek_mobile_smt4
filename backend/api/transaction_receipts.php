<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function receiptOrderData(mysqli $conn, int $orderId, string $userId): ?array {
    $stmt = $conn->prepare("
        SELECT o.*, m.business_name, m.address AS merchant_address, u.display_name, u.email
        FROM orders o
        INNER JOIN merchants m ON m.id = o.merchant_id
        INNER JOIN users u ON u.id = o.user_id
        WHERE o.id = ? AND o.user_id = ?
        LIMIT 1
    ");
    if (!$stmt) {
        return null;
    }
    $stmt->bind_param('is', $orderId, $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) {
        return null;
    }

    $items = merchantOrderItems($conn, $orderId);
    return [
        'orderId' => (string)$orderId,
        'orderCode' => (string)($row['order_code'] ?? ('#' . $orderId)),
        'merchantName' => (string)($row['business_name'] ?? ''),
        'merchantAddress' => (string)($row['merchant_address'] ?? ''),
        'customerName' => (string)($row['customer_name'] ?? $row['display_name'] ?? ''),
        'customerEmail' => (string)($row['email'] ?? ''),
        'serviceType' => (string)($row['service_type'] ?? ''),
        'paymentMethod' => (string)($row['payment_method'] ?? ''),
        'paymentStatus' => (string)($row['payment_status'] ?? ''),
        'orderStatus' => (string)($row['status'] ?? ''),
        'totalAmount' => (float)($row['total_harga'] ?? 0),
        'createdAt' => date('d/m/Y H:i', strtotime($row['created_at'] ?? 'now')),
        'items' => $items,
        'deliveryAddress' => (string)($row['delivery_address'] ?? ''),
    ];
}

function receiptCanGenerate(array $data): bool {
    $total = (float)($data['totalAmount'] ?? 0);
    if ($total <= 0) {
        return false;
    }
    $payment = strtolower(trim((string)($data['paymentStatus'] ?? '')));
    if ($payment === 'paid') {
        return true;
    }
    $method = strtolower(trim((string)($data['paymentMethod'] ?? '')));
    $status = strtolower(trim((string)($data['orderStatus'] ?? '')));
    $isCod = str_contains($method, 'cod') || str_contains($method, 'cash');
    return $isCod && in_array($status, ['done', 'completed'], true);
}

try {
    merchantEnsureSchema($conn);
    $payload = merchantRequireAuth();
    $userId = (string)($payload['sub'] ?? '');

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $orderId = (int)($_GET['orderId'] ?? 0);
        if ($orderId <= 0) {
            merchantSendJson(false, null, 'orderId wajib diisi', 400);
        }
        $data = receiptOrderData($conn, $orderId, $userId);
        if (!$data) {
            merchantSendJson(false, null, 'Pesanan tidak ditemukan', 404);
        }
        if (!receiptCanGenerate($data)) {
            merchantSendJson(false, null, 'Struk tersedia setelah pembayaran selesai', 409);
        }
        merchantSendJson(true, $data, 'Data struk berhasil dimuat');
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $body = merchantBody();
        $orderId = (int)($body['orderId'] ?? 0);
        if ($orderId <= 0) {
            merchantSendJson(false, null, 'orderId wajib diisi', 400);
        }
        $data = receiptOrderData($conn, $orderId, $userId);
        if (!$data) {
            merchantSendJson(false, null, 'Pesanan tidak ditemukan', 404);
        }
        if (!receiptCanGenerate($data)) {
            merchantSendJson(false, null, 'Struk tersedia setelah pembayaran selesai', 409);
        }

        if (merchantTableExists($conn, 'transaction_receipts')) {
            $receiptId = merchantUuid();
            $stmt = $conn->prepare("
                INSERT INTO transaction_receipts (id, order_id, receipt_url, receipt_type, generated_at)
                VALUES (?, ?, ?, 'json', NOW())
                ON DUPLICATE KEY UPDATE receipt_url = VALUES(receipt_url), generated_at = NOW()
            ");
            if ($stmt) {
                $url = 'receipt://order/' . $orderId;
                $stmt->bind_param('sis', $receiptId, $orderId, $url);
                $stmt->execute();
                $stmt->close();
            }
        }

        merchantSendJson(true, $data, 'Struk siap diunduh');
    }

    merchantSendJson(false, null, 'Method tidak didukung', 405);
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}
