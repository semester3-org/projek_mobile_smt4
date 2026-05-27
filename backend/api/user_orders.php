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

function userOrderPaymentMethodLabel(?string $method): string {
    $key = strtolower(trim((string)$method));
  return match ($key) {
        'bca' => 'Transfer Bank BCA',
        'mandiri' => 'Transfer Bank Mandiri',
        'bni' => 'Transfer Bank BNI',
        'cimb' => 'Transfer Bank CIMB Niaga',
        'gopay' => 'GoPay',
        'ovo' => 'OVO',
        'dana' => 'DANA',
        'shopeepay' => 'ShopeePay',
        'linkaja' => 'LinkAja',
        'qris' => 'QRIS',
        'cod', 'cash' => 'Bayar di Tempat (COD)',
        default => $method !== '' ? ucwords(str_replace('_', ' ', $key)) : 'Metode pembayaran',
    };
}

function userOrderLaundryServiceEstimate(mysqli $conn, int $productId, string $fallback = ''): string {
    if ($productId <= 0) {
        return $fallback;
    }
    $stmt = $conn->prepare('SELECT category, merchant_id FROM products WHERE id = ? LIMIT 1');
    if (!$stmt) {
        return $fallback;
    }
    $stmt->bind_param('i', $productId);
    $stmt->execute();
    $product = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$product) {
        return $fallback;
    }
    $category = trim((string)($product['category'] ?? ''));
    if ($category === '') {
        return $fallback;
    }
    if (merchantTableExists($conn, 'laundry_service_estimates')) {
        $merchantId = (string)($product['merchant_id'] ?? '');
        $est = $conn->prepare("
            SELECT min_hours, max_hours, estimate_label
            FROM laundry_service_estimates
            WHERE merchant_id = ? AND service_name = ? AND is_active = 1
            LIMIT 1
        ");
        if ($est) {
            $est->bind_param('ss', $merchantId, $category);
            $est->execute();
            $row = $est->get_result()->fetch_assoc();
            $est->close();
            if ($row) {
                $label = trim((string)($row['estimate_label'] ?? ''));
                if ($label !== '') {
                    return $label;
                }
                $min = (int)($row['min_hours'] ?? 0);
                $max = (int)($row['max_hours'] ?? 0);
                if ($min > 0 && $max > 0) {
                    return $category . ' (' . $min . '-' . $max . ' jam)';
                }
            }
        }
    }
    return $category;
}

function userOrderLaundryDisplayStatus(array $order): string {
    if (($order['serviceType'] ?? '') !== 'laundry') {
        return '';
    }
    $payment = strtolower((string)($order['paymentStatus'] ?? ''));
    $total = (float)($order['totalAmount'] ?? 0);
    if ($payment === 'awaiting_weighing') {
        return 'Menunggu penimbangan';
    }
    if (in_array($payment, ['waiting_payment', 'unpaid'], true) && $total > 0) {
        return 'Siap dibayar';
    }
    if ($payment === 'payment_submitted') {
        return 'Menunggu konfirmasi pembayaran';
    }
    if ($payment === 'paid' || $payment === 'cod') {
        return match ($order['status'] ?? 'pending') {
            'accepted' => 'Diterima merchant',
            'processing', 'delivered' => 'Sedang diproses',
            'done' => 'Selesai',
            default => 'Menunggu konfirmasi merchant',
        };
    }
    return 'Menunggu penimbangan';
}

function userOrderPayload(mysqli $conn, array $row): array {
    $order = merchantOrderPayload($conn, $row);
    $isCatering = ($order['serviceType'] ?? '') === 'catering';
    $subscriptionStatus = strtolower((string)($order['subscriptionStatus'] ?? ''));
    $subscriptionEnd = $order['subscriptionEndDate'] ?? null;
    $subscriptionEndDate = $subscriptionEnd ? date('Y-m-d', strtotime($subscriptionEnd)) : null;
    $subscriptionStillRunning = $subscriptionEndDate === null || $subscriptionEndDate >= date('Y-m-d');
    $canCancel = false;
    if ($isCatering) {
        $canCancel = ($order['subscriptionDays'] ?? null) !== null &&
            $subscriptionStillRunning &&
            !in_array($subscriptionStatus, ['cancel_requested', 'ended', 'expired'], true);
    } else {
        $windowUntil = $row['cancellation_window_until'] ?? null;
        $paymentCancelled = strtolower((string)($order['paymentStatus'] ?? '')) === 'cancelled';
        $canCancel = !$paymentCancelled &&
            ($order['status'] ?? '') === 'pending' &&
            $windowUntil !== null &&
            strtotime((string)$windowUntil) > time();
    }

    return [
        'id' => $order['code'],
        'databaseId' => $order['id'],
        'merchantName' => $row['business_name'] ?? 'Merchant',
        'service' => $order['serviceType'],
        'orderDate' => $order['createdAt'],
        'deliveryDate' => null,
        'totalAmount' => $order['totalAmount'],
        'subtotalAmount' => (float)($row['subtotal_amount'] ?? $order['totalAmount'] ?? 0),
        'promoDiscountAmount' => (float)($row['promo_discount_amount'] ?? 0),
        'promoName' => $row['promo_name'] ?? null,
        'hasPromo' => (float)($row['promo_discount_amount'] ?? 0) > 0,
        'status' => strtolower((string)($order['paymentStatus'] ?? '')) === 'cancelled'
            ? 'cancelled'
            : match ($order['status']) {
                'accepted' => 'confirmed',
                'processing', 'delivered' => 'in_progress',
                'done' => 'completed',
                default => 'pending',
            },
        'items' => array_map(fn($item) => [
            'name' => $item['name'],
            'description' => $item['description'] ?? '',
            'quantity' => $item['quantity'],
            'price' => $item['price'],
            'subtotal' => $item['subtotal'],
        ], $order['items']),
        'notes' => $order['notes'],
        'paymentMethod' => $order['paymentMethod'],
        'paymentStatus' => $order['paymentStatus'],
        'paymentStatusLabel' => $order['paymentStatusLabel'],
        'deliveryAddress' => $order['deliveryAddress'],
        'deliveryLatitude' => $order['deliveryLatitude'],
        'deliveryLongitude' => $order['deliveryLongitude'],
        'estimatedTime' => $order['estimatedTime'],
        'midtransOrderId' => $order['midtransOrderId'],
        'subscriptionDays' => $order['subscriptionDays'],
        'subscriptionStartDate' => $order['subscriptionStartDate'],
        'subscriptionEndDate' => $order['subscriptionEndDate'],
        'subscriptionStatus' => $order['subscriptionStatus'],
        'cancellationRequestedAt' => $order['cancellationRequestedAt'],
        'canCancel' => $canCancel,
        'merchantStatus' => $order['status'],
        'awaitingWeighing' => ($order['serviceType'] ?? '') === 'laundry' &&
            (float)($order['totalAmount'] ?? 0) <= 0 &&
            strtolower((string)($order['paymentStatus'] ?? '')) === 'awaiting_weighing',
        'readyToPay' => ($order['serviceType'] ?? '') === 'laundry' &&
            (float)($order['totalAmount'] ?? 0) > 0 &&
            in_array(strtolower((string)($order['paymentStatus'] ?? '')), ['waiting_payment', 'unpaid'], true),
        'displayStatusLabel' => ($order['serviceType'] ?? '') === 'laundry'
            ? userOrderLaundryDisplayStatus($order)
            : null,
        'paymentMethodLabel' => userOrderPaymentMethodLabel($order['paymentMethod'] ?? ''),
        'serviceEstimateLabel' => ($order['serviceType'] ?? '') === 'laundry'
            ? (string)($order['estimatedTime'] ?? '')
            : null,
    ];
}

function userOrderInitialPaymentStatus(string $paymentMethod): string {
    $method = strtolower(trim($paymentMethod));
    if (str_contains($method, 'cod') || str_contains($method, 'cash')) {
        return 'cod';
    }
    return 'waiting_payment';
}

function userOrderIsCod(string $paymentMethod): bool {
    $method = strtolower(trim($paymentMethod));
    return str_contains($method, 'cod') || str_contains($method, 'cash');
}

function userOrderPaymentAllowed(string $merchantType, string $paymentMethod): bool {
    if ($merchantType === 'catering' && userOrderIsCod($paymentMethod)) {
        return false;
    }
    return true;
}

function userOrderSubscriptionDays(string $service, array $body): ?int {
    if ($service !== 'catering') return null;
    $days = (int)($body['subscriptionDays'] ?? 0);
    if ($days <= 0) {
        $estimated = (string)($body['estimatedTime'] ?? '');
        if (preg_match('/(\d+)\s*hari/i', $estimated, $matches)) {
            $days = (int)$matches[1];
        }
    }
    if (!in_array($days, [20, 30], true)) {
        $days = 30;
    }
    return $days;
}

try {
    merchantEnsureSchema($conn);
    merchantExpireFinishedCateringSubscriptions($conn);
    $payload = merchantRequireAuth();
    $userId = (string)($payload['sub'] ?? '');
    if ($userId === '') {
        merchantSendJson(false, null, 'Unauthorized', 401);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $orderId = trim($_GET['id'] ?? '');
        if ($orderId !== '') {
            $stmt = $conn->prepare("
                SELECT o.*, m.business_name, m.merchant_type
                FROM orders o
                INNER JOIN merchants m ON m.id = o.merchant_id
                WHERE o.user_id = ?
                  AND (CAST(o.id AS CHAR) = ? OR o.order_code = ?)
                LIMIT 1
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Database error', 500);
            }
            $stmt->bind_param('sss', $userId, $orderId, $orderId);
            $stmt->execute();
            $row = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            if (!$row) {
                merchantSendJson(false, null, 'Pesanan tidak ditemukan', 404);
            }
            merchantSendJson(true, userOrderPayload($conn, $row), 'Detail pesanan berhasil dimuat');
        }

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

        if ($id === '' || !in_array($action, ['confirm_payment', 'cancel_subscription', 'cancel_order'], true)) {
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

        if ($action === 'cancel_order') {
            $serviceType = strtolower((string)($row['service_type'] ?? ''));
            if ($serviceType === 'catering') {
                merchantSendJson(false, null, 'Gunakan menu batalkan langganan untuk catering', 400);
            }
            if (($row['status'] ?? '') !== 'pending') {
                merchantSendJson(false, null, 'Pesanan tidak bisa dibatalkan', 400);
            }
            $windowUntil = $row['cancellation_window_until'] ?? null;
            if ($windowUntil === null || strtotime((string)$windowUntil) < time()) {
                merchantSendJson(false, null, 'Waktu pembatalan (5 detik) sudah habis', 400);
            }
            $orderIdInt = (int)$row['id'];
            $stmt = $conn->prepare("
                UPDATE orders
                SET payment_status = 'cancelled',
                    notes = CONCAT(COALESCE(notes, ''), '\n[Dibatalkan user]'),
                    updated_at = NOW()
                WHERE id = ? AND user_id = ?
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Database error', 500);
            }
            $stmt->bind_param('is', $orderIdInt, $userId);
            $stmt->execute();
            $stmt->close();

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
            merchantSendJson(true, userOrderPayload($conn, $updated), 'Pesanan berhasil dibatalkan');
        }

        if ($action === 'cancel_subscription') {
            $serviceType = strtolower((string)($row['service_type'] ?? $row['merchant_type'] ?? ''));
            if ($serviceType !== 'catering') {
                merchantSendJson(false, null, 'Hanya langganan catering yang bisa dibatalkan dari menu ini', 400);
            }
            $subscriptionStatus = strtolower((string)($row['subscription_status'] ?? ''));
            if (in_array($subscriptionStatus, ['cancel_requested', 'ended'], true)) {
                merchantSendJson(false, null, 'Langganan sudah dibatalkan atau selesai', 400);
            }

            $orderIdInt = (int)$row['id'];
            $stmt = $conn->prepare("
                UPDATE orders
                SET subscription_status = 'cancel_requested',
                    cancellation_requested_at = NOW(),
                    updated_at = NOW()
                WHERE id = ? AND user_id = ?
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Database error', 500);
            }
            $stmt->bind_param('is', $orderIdInt, $userId);
            $stmt->execute();
            $stmt->close();
            merchantSyncCateringSubscriber($conn, $orderIdInt);

            merchantCreateNotification(
                $conn,
                (string)$row['merchant_user_id'],
                'Langganan catering dibatalkan',
                ($row['order_code'] ?? ('#' . $row['id'])) . ' tetap aktif sampai masa langganan selesai.',
                'catering',
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

            merchantSendJson(true, userOrderPayload($conn, $updated), 'Langganan akan berhenti saat periode selesai');
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
    $deliveryLatitude = isset($body['deliveryLatitude']) && $body['deliveryLatitude'] !== '' && $body['deliveryLatitude'] !== null
        ? (float)$body['deliveryLatitude']
        : null;
    $deliveryLongitude = isset($body['deliveryLongitude']) && $body['deliveryLongitude'] !== '' && $body['deliveryLongitude'] !== null
        ? (float)$body['deliveryLongitude']
        : null;
    $estimatedTime = trim((string)($body['estimatedTime'] ?? ''));
    $paymentMethod = trim((string)($body['paymentMethod'] ?? ''));
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
    $merchantType = (string)($merchantType ?: $service);
    if ($paymentMethod === '') {
        $paymentMethod = $merchantType === 'catering' ? 'GoPay/QRIS' : 'Cash on Delivery';
    }
    if (!userOrderPaymentAllowed($merchantType, $paymentMethod)) {
        merchantSendJson(false, null, 'Catering tidak mendukung pembayaran COD. Pilih e-wallet, QRIS, atau transfer bank.', 400);
    }
    $paymentStatus = userOrderInitialPaymentStatus($paymentMethod);
    $subscriptionDays = userOrderSubscriptionDays($service, $body);
    $subscriptionStartDate = null;
    $subscriptionEndDate = null;
    $subscriptionStatus = null;
    if ($subscriptionDays !== null) {
        $subscriptionStartDate = null;
        $subscriptionEndDate = null;
        $subscriptionStatus = 'pending_payment';
    }

    $isLaundryRequest = $service === 'laundry';
    $subtotal = 0.0;
    $total = 0.0;
    $promoDiscountAmount = 0.0;
    $promoId = null;
    $promoName = null;
    $normalizedItems = [];
    foreach ($items as $item) {
        if (!is_array($item)) continue;
        $name = trim((string)($item['name'] ?? 'Item Pesanan'));
        $qty = $isLaundryRequest ? 1 : max(1, (int)($item['quantity'] ?? 1));
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

        $itemSubtotal = $isLaundryRequest ? 0.0 : ($qty * $price);
        if (!$isLaundryRequest) {
            $subtotal += $itemSubtotal;
        }
        $normalizedItems[] = [
            'productId' => $productId,
            'name' => $name,
            'qty' => $qty,
            'price' => $price,
        ];
    }

    if (empty($normalizedItems)) {
        merchantSendJson(false, null, 'Item pesanan tidak valid', 400);
    }
    if (!$isLaundryRequest && $subtotal <= 0) {
        merchantSendJson(false, null, 'Item pesanan tidak valid', 400);
    }
    if ($isLaundryRequest) {
        $total = 0.0;
        $paymentStatus = 'awaiting_weighing';
        $firstProductId = (int)($normalizedItems[0]['productId'] ?? 0);
        $estimatedTime = userOrderLaundryServiceEstimate($conn, $firstProductId, $estimatedTime);
    } else {
        $total = $subtotal;
    }

    $conn->begin_transaction();
    try {
        if (!$isLaundryRequest) {
            $bestPromo = merchantBestPromoForCheckout($conn, $merchantId, $userId, $subtotal, $normalizedItems);
            if ($bestPromo !== null) {
                $promoId = (int)$bestPromo['promo']['id'];
                $promoName = (string)($bestPromo['promo']['name'] ?? '');
                $promoDiscountAmount = (float)$bestPromo['discount'];
                $total = max(0, (float)$bestPromo['total']);
            }
        }

        if ($promoId !== null) {
            $lock = $conn->prepare('SELECT id, usage_limit, used_count FROM merchant_promos WHERE id = ? FOR UPDATE');
            if (!$lock) throw new Exception($conn->error);
            $lock->bind_param('i', $promoId);
            $lock->execute();
            $lockedPromo = $lock->get_result()->fetch_assoc();
            $lock->close();
            if (!$lockedPromo || ((int)($lockedPromo['usage_limit'] ?? 0) > 0 &&
                (int)($lockedPromo['used_count'] ?? 0) >= (int)($lockedPromo['usage_limit'] ?? 0))) {
                $promoId = null;
                $promoName = null;
                $promoDiscountAmount = 0.0;
                $total = $subtotal;
            }
        }

        $stmt = $conn->prepare("
            INSERT INTO orders
                (user_id, merchant_id, total_harga, status, service_type, delivery_address,
                 delivery_latitude, delivery_longitude, estimated_time, payment_method,
                 payment_status, customer_name, customer_phone, notes, subscription_days,
                 subscription_start_date, subscription_end_date, subscription_status,
                 promo_id, promo_name, promo_discount_amount, subtotal_amount,
                 cancellation_window_until, created_at, updated_at)
            VALUES (?, ?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?,
                    DATE_ADD(NOW(), INTERVAL 5 SECOND), NOW(), NOW())
        ");
        if (!$stmt) throw new Exception($conn->error);
        $stmt->bind_param(
            'ssdssddssssssisssissd',
            $userId,
            $merchantId,
            $total,
            $service,
            $deliveryAddress,
            $deliveryLatitude,
            $deliveryLongitude,
            $estimatedTime,
            $paymentMethod,
            $paymentStatus,
            $customerName,
            $customerPhone,
            $notes,
            $subscriptionDays,
            $subscriptionStartDate,
            $subscriptionEndDate,
            $subscriptionStatus,
            $promoId,
            $promoName,
            $promoDiscountAmount,
            $subtotal
        );
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

        if ($promoId !== null) {
            $stmt = $conn->prepare("
                INSERT INTO promo_usages (promo_id, user_id, order_id, created_at)
                VALUES (?, ?, ?, NOW())
            ");
            if (!$stmt) throw new Exception($conn->error);
            $stmt->bind_param('isi', $promoId, $userId, $orderId);
            $stmt->execute();
            $stmt->close();

            $stmt = $conn->prepare("
                UPDATE merchant_promos
                SET used_count = used_count + 1,
                    updated_at = NOW()
                WHERE id = ?
            ");
            if (!$stmt) throw new Exception($conn->error);
            $stmt->bind_param('i', $promoId);
            $stmt->execute();
            $stmt->close();
        }

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

        if ($service === 'catering') {
            merchantSyncCateringSubscriber($conn, $orderId);
        }

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
