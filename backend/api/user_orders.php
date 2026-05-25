<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function userOrderPayload(mysqli $conn, array $row): array {
    $order = merchantOrderPayload($conn, $row);
    return [
        'id' => $order['code'],
        'databaseId' => $order['id'],
        'merchantName' => $row['business_name'] ?? 'Merchant',
        'service' => $order['serviceType'],
        'orderDate' => $order['createdAt'],
        'deliveryDate' => null,
        'totalAmount' => $order['totalAmount'],
        'status' => match ($order['status']) {
            'accepted' => 'confirmed',
            'processing', 'delivered' => 'in_progress',
            'done' => 'completed',
            default => 'pending',
        },
        'items' => array_map(fn($item) => [
            'name' => $item['name'],
            'quantity' => $item['quantity'],
            'price' => $item['price'],
            'subtotal' => $item['subtotal'],
        ], $order['items']),
        'notes' => $order['notes'],
        'paymentMethod' => $order['paymentMethod'],
        'paymentStatus' => $order['paymentStatus'],
        'paymentStatusLabel' => $order['paymentStatusLabel'],
        'deliveryAddress' => $order['deliveryAddress'],
        'estimatedTime' => $order['estimatedTime'],
        'canCancel' => $order['serviceType'] !== 'catering' || $order['status'] === 'pending',
    ];
}

function userOrderInitialPaymentStatus(string $paymentMethod): string {
    $method = strtolower(trim($paymentMethod));
    if (str_contains($method, 'cod') || str_contains($method, 'cash')) {
        return 'cod';
    }
    return 'waiting_payment';
}

try {
    merchantEnsureSchema($conn);
    $payload = merchantRequireAuth();
    $userId = (string)($payload['sub'] ?? '');
    if ($userId === '') {
        merchantSendJson(false, null, 'Unauthorized', 401);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $stmt = $conn->prepare("
            SELECT o.*, m.business_name, m.merchant_type
            FROM orders o
            INNER JOIN merchants m ON m.id = o.merchant_id
            WHERE o.user_id = ?
            ORDER BY o.created_at DESC, o.id DESC
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param('s', $userId);
        $stmt->execute();
        $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();

        $data = array_map(fn($row) => userOrderPayload($conn, $row), $rows);
        merchantSendJson(true, $data, 'Pesanan user berhasil dimuat');
    }

    if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        $body = merchantBody();
        $id = trim((string)($body['id'] ?? ''));
        $action = strtolower(trim((string)($body['action'] ?? '')));

        if ($id === '' || $action !== 'confirm_payment') {
            merchantSendJson(false, null, 'Aksi pesanan tidak valid', 400);
        }

        $stmt = $conn->prepare("
            SELECT o.*, m.business_name, m.merchant_type, m.user_id AS merchant_user_id
            FROM orders o
            INNER JOIN merchants m ON m.id = o.merchant_id
            WHERE (CAST(o.id AS CHAR) = ? OR o.order_code = ?)
              AND o.user_id = ?
            LIMIT 1
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param('sss', $id, $id, $userId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$row) {
            merchantSendJson(false, null, 'Pesanan tidak ditemukan', 404);
        }

        $paymentMethod = (string)($row['payment_method'] ?? '');
        $method = strtolower($paymentMethod);
        if (str_contains($method, 'cod') || str_contains($method, 'cash')) {
            merchantSendJson(false, null, 'Pesanan COD tidak perlu konfirmasi pembayaran di awal', 400);
        }

        $stmt = $conn->prepare("
            UPDATE orders
            SET payment_status = 'payment_submitted',
                updated_at = NOW()
            WHERE id = ? AND user_id = ?
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $orderIdInt = (int)$row['id'];
        $stmt->bind_param('is', $orderIdInt, $userId);
        $stmt->execute();
        $stmt->close();

        merchantCreateNotification(
            $conn,
            (string)$row['merchant_user_id'],
            'Pembayaran pesanan masuk',
            ($row['order_code'] ?? ('#' . $row['id'])) . ' sudah dikonfirmasi user. Silakan cek dan approve pesanan.',
            'payment',
            'Lihat Pesanan',
            'order:' . (string)$row['id']
        );

        $stmt = $conn->prepare("
            SELECT o.*, m.business_name, m.merchant_type
            FROM orders o
            INNER JOIN merchants m ON m.id = o.merchant_id
            WHERE o.id = ?
            LIMIT 1
        ");
        $stmt->bind_param('i', $orderIdInt);
        $stmt->execute();
        $updated = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        merchantSendJson(true, userOrderPayload($conn, $updated), 'Pembayaran dikirim ke merchant');
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        merchantSendJson(false, null, 'Only GET, POST, or PUT method allowed', 405);
    }

    $body = merchantBody();
    $merchantInput = trim((string)($body['merchantId'] ?? ''));
    $merchantId = merchantResolveMerchantId($conn, $merchantInput);
    $service = strtolower(trim((string)($body['service'] ?? '')));
    $deliveryAddress = trim((string)($body['deliveryAddress'] ?? ''));
    $estimatedTime = trim((string)($body['estimatedTime'] ?? ''));
    $paymentMethod = trim((string)($body['paymentMethod'] ?? 'GOPAY'));
    $paymentStatus = userOrderInitialPaymentStatus($paymentMethod);
    $customerName = trim((string)($body['customerName'] ?? ''));
    $customerPhone = trim((string)($body['customerPhone'] ?? ''));
    $notes = trim((string)($body['notes'] ?? ''));
    $items = $body['items'] ?? [];

    if (!$merchantId) {
        merchantSendJson(false, null, 'Merchant tidak ditemukan', 404);
    }
    if (!is_array($items) || empty($items)) {
        merchantSendJson(false, null, 'Item pesanan wajib diisi', 400);
    }
    if ($deliveryAddress === '') {
        merchantSendJson(false, null, 'Alamat tujuan wajib diisi', 400);
    }

    $merchantType = merchantQueryValue($conn, 'SELECT merchant_type FROM merchants WHERE id = ? LIMIT 1', 's', [$merchantId]);
    if ($service === '') {
        $service = (string)($merchantType ?: 'laundry');
    }

    $total = 0.0;
    $normalizedItems = [];
    foreach ($items as $item) {
        if (!is_array($item)) continue;
        $name = trim((string)($item['name'] ?? 'Item Pesanan'));
        $qty = max(1, (int)($item['quantity'] ?? 1));
        $price = (float)($item['price'] ?? 0);
        $productIdRaw = trim((string)($item['productId'] ?? $item['id'] ?? ''));
        if ($price <= 0) continue;

        $productId = ctype_digit($productIdRaw) ? (int)$productIdRaw : null;
        if ($productId !== null) {
            $valid = merchantQueryValue(
                $conn,
                'SELECT id FROM products WHERE id = ? AND merchant_id = ? LIMIT 1',
                'is',
                [$productId, $merchantId]
            );
            if (!$valid) $productId = null;
        }
        if ($productId === null) {
            $productId = merchantFallbackProductId($conn, $merchantId, $name, $price);
        }
        if ($productId === null) continue;

        $subtotal = $qty * $price;
        $total += $subtotal;
        $normalizedItems[] = [
            'productId' => $productId,
            'name' => $name,
            'qty' => $qty,
            'price' => $price,
        ];
    }

    if (empty($normalizedItems) || $total <= 0) {
        merchantSendJson(false, null, 'Item pesanan tidak valid', 400);
    }

    $conn->begin_transaction();
    try {
        $stmt = $conn->prepare("
            INSERT INTO orders
                (user_id, merchant_id, total_harga, status, service_type, delivery_address, estimated_time, payment_method, payment_status, customer_name, customer_phone, notes, created_at, updated_at)
            VALUES (?, ?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
        ");
        if (!$stmt) throw new Exception($conn->error);
        $stmt->bind_param('ssdssssssss', $userId, $merchantId, $total, $service, $deliveryAddress, $estimatedTime, $paymentMethod, $paymentStatus, $customerName, $customerPhone, $notes);
        $stmt->execute();
        $orderId = (int)$conn->insert_id;
        $stmt->close();

        $orderCode = 'SR-' . strtoupper($service) . '-' . str_pad((string)$orderId, 6, '0', STR_PAD_LEFT);
        $stmt = $conn->prepare("UPDATE orders SET order_code = ? WHERE id = ?");
        if (!$stmt) throw new Exception($conn->error);
        $stmt->bind_param('si', $orderCode, $orderId);
        $stmt->execute();
        $stmt->close();

        $stmt = $conn->prepare("
            INSERT INTO order_items (order_id, product_id, qty, harga, created_at, updated_at)
            VALUES (?, ?, ?, ?, NOW(), NOW())
        ");
        if (!$stmt) throw new Exception($conn->error);
        foreach ($normalizedItems as $item) {
            $stmt->bind_param('iiid', $orderId, $item['productId'], $item['qty'], $item['price']);
            $stmt->execute();
        }
        $stmt->close();

        $merchantUserId = merchantQueryValue($conn, 'SELECT user_id FROM merchants WHERE id = ? LIMIT 1', 's', [$merchantId]);
        if ($merchantUserId) {
            merchantCreateNotification(
                $conn,
                (string)$merchantUserId,
                'Pesanan baru masuk',
                $orderCode . ' menunggu diproses. Total Rp ' . number_format($total, 0, ',', '.'),
                $paymentStatus === 'cod' ? 'order' : 'payment',
                'Lihat Pesanan',
                'order:' . (string)$orderId
            );
        }
        merchantCreateNotification(
            $conn,
            $userId,
            'Pesanan berhasil dibuat',
            $orderCode . ' sudah dikirim ke merchant dan menunggu konfirmasi.',
            'order',
            'Lihat Detail',
            'order:' . (string)$orderId
        );

        $conn->commit();
    } catch (Throwable $e) {
        $conn->rollback();
        merchantSendJson(false, null, 'Gagal membuat pesanan: ' . $e->getMessage(), 500);
    }

    $stmt = $conn->prepare("
        SELECT o.*, m.business_name, m.merchant_type
        FROM orders o
        INNER JOIN merchants m ON m.id = o.merchant_id
        WHERE o.id = ?
        LIMIT 1
    ");
    $stmt->bind_param('i', $orderId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    merchantSendJson(true, userOrderPayload($conn, $row), 'Pesanan berhasil dibuat', 201);
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
