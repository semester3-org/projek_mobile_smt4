<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/midtrans.php';
require_once __DIR__ . '/../utils/response.php';
require_once __DIR__ . '/../helpers/jwt.php';

midtransConfig();

$payload = JWT::getPayloadFromRequest();
$userId = $payload['sub'] ?? null;

if (!$userId) {
    sendError('Unauthorized', 401);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendError('Only POST method allowed', 405);
}

function textContains(string $haystack, string $needle): bool {
    return strpos($haystack, $needle) !== false;
}

function billingIdFromMidtransOrderId(string $midtransOrderId): string {
    if (strpos($midtransOrderId, 'PAY-') !== 0) {
        return $midtransOrderId;
    }

    $raw = substr($midtransOrderId, 4);
    $lastDashPosition = strrpos($raw, '-');
    if ($lastDashPosition === false) {
        return $raw;
    }

    return substr($raw, 0, $lastDashPosition);
}

function localPaymentStatus(string $transactionStatus): string {
    return in_array($transactionStatus, ['capture', 'settlement'], true) ? 'paid' : 'unpaid';
}

function localOrderPaymentStatus(string $transactionStatus): string {
    return match ($transactionStatus) {
        'capture', 'settlement' => 'paid',
        'pending' => 'waiting_payment',
        'deny', 'cancel', 'expire', 'failure' => 'cancelled',
        default => 'waiting_payment',
    };
}

function midtransEnabledPayments(string $paymentMethod): array {
    $normalizedMethod = strtolower($paymentMethod);
    if (textContains($normalizedMethod, 'cod') || textContains($normalizedMethod, 'cash')) {
        sendError('COD tidak diproses melalui Midtrans', 400);
    }
    if (textContains($normalizedMethod, 'bca')) {
        return ['bca_va'];
    }
    if (textContains($normalizedMethod, 'bni')) {
        return ['bni_va'];
    }
    if (textContains($normalizedMethod, 'mandiri') || textContains($normalizedMethod, 'echannel')) {
        return ['echannel'];
    }
    if (textContains($normalizedMethod, 'gopay')) {
        return ['gopay'];
    }
    if (textContains($normalizedMethod, 'shopeepay')) {
        return ['shopeepay'];
    }
    if (textContains($normalizedMethod, 'ovo') ||
        textContains($normalizedMethod, 'dana') ||
        textContains($normalizedMethod, 'qris') ||
        textContains($normalizedMethod, 'linkaja')) {
        return ['gopay', 'shopeepay'];
    }
    if (textContains($normalizedMethod, 'virtual account') ||
        textContains($normalizedMethod, 'bank') ||
        textContains($normalizedMethod, 'transfer')) {
        return ['bca_va', 'bni_va', 'echannel'];
    }
    if (textContains($normalizedMethod, 'e-wallet') ||
        textContains($normalizedMethod, 'ewallet')) {
        return ['gopay', 'shopeepay'];
    }
    if (textContains($normalizedMethod, 'credit') ||
        textContains($normalizedMethod, 'debit') ||
        textContains($normalizedMethod, 'kartu')) {
        return ['credit_card'];
    }
    sendError('Payment method tidak didukung: ' . $paymentMethod, 400);
}

function orderIdFromMidtransOrderId(string $midtransOrderId): ?int {
    if (strpos($midtransOrderId, 'ORD-') !== 0) {
        return null;
    }
    $raw = substr($midtransOrderId, 4);
    $dash = strpos($raw, '-');
    $id = $dash === false ? $raw : substr($raw, 0, $dash);
    return ctype_digit($id) ? (int)$id : null;
}

function tableExists(mysqli $conn, string $table): bool {
    $stmt = $conn->prepare(
        'SELECT COUNT(*) AS total FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?'
    );
    if (!$stmt) return false;
    $stmt->bind_param('s', $table);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return (int)($row['total'] ?? 0) > 0;
}

function uuid(): string {
    $data = random_bytes(16);
    $data[6] = chr((ord($data[6]) & 0x0f) | 0x40);
    $data[8] = chr((ord($data[8]) & 0x3f) | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
}

function paymentHistoryIdColumn(mysqli $conn): ?array {
    $stmt = $conn->prepare("
        SELECT DATA_TYPE AS data_type, EXTRA AS extra
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'payment_history'
          AND column_name = 'id'
        LIMIT 1
    ");
    if (!$stmt) return null;
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

function paymentHistoryUsesAutoIncrementId(mysqli $conn): bool {
    $column = paymentHistoryIdColumn($conn);
    if (!$column) return false;

    $extra = strtolower((string)($column['extra'] ?? ''));
    return strpos($extra, 'auto_increment') !== false;
}

function paymentHistoryUsesStringId(mysqli $conn): bool {
    $column = paymentHistoryIdColumn($conn);
    if (!$column) return false;

    $dataType = strtolower((string)($column['data_type'] ?? ''));
    $isStringType = in_array($dataType, ['char', 'varchar', 'text'], true);
    return $isStringType;
}

function nextPaymentHistoryNumericId(mysqli $conn): int {
    $result = $conn->query("SELECT COALESCE(MAX(CAST(id AS UNSIGNED)), 0) + 1 AS next_id FROM payment_history");
    if (!$result) {
        sendError('Database error: ' . $conn->error, 500);
    }
    $row = $result->fetch_assoc();
    return max(1, (int)($row['next_id'] ?? 1));
}

function latestPaymentHistoryId(mysqli $conn, string $registrationId, string $period): string {
    $stmt = $conn->prepare("
        SELECT id
        FROM payment_history
        WHERE registration_id = ? AND period_month = ?
        ORDER BY created_at DESC
        LIMIT 1
    ");
    if (!$stmt) return '';
    $stmt->bind_param('ss', $registrationId, $period);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return isset($row['id']) ? (string)$row['id'] : '';
}

function createPaymentHistoryForGeneratedBill(
    mysqli $conn,
    string $registrationId,
    int $amount,
    string $period
): string {
    if (!paymentHistoryUsesAutoIncrementId($conn)) {
        $usesStringId = paymentHistoryUsesStringId($conn);
        $billingId = $usesStringId ? uuid() : nextPaymentHistoryNumericId($conn);
        $insert = $conn->prepare("
            INSERT INTO payment_history
                (id, registration_id, amount, period_month, payment_status, payment_method, created_at)
            VALUES (?, ?, ?, ?, 'unpaid', 'MIDTRANS', NOW())
        ");
        if (!$insert) {
            sendError('Database error: ' . $conn->error, 500);
        }
        if ($usesStringId) {
            $insert->bind_param('ssis', $billingId, $registrationId, $amount, $period);
        } else {
            $insert->bind_param('isis', $billingId, $registrationId, $amount, $period);
        }
        if (!$insert->execute()) {
            $error = $insert->error;
            $insert->close();
            sendError('Gagal membuat tagihan pembayaran: ' . $error, 500);
        }
        $insert->close();
        return (string)$billingId;
    }

    $insert = $conn->prepare("
        INSERT INTO payment_history
            (registration_id, amount, period_month, payment_status, payment_method, created_at)
        VALUES (?, ?, ?, 'unpaid', 'MIDTRANS', NOW())
    ");
    if (!$insert) {
        sendError('Database error: ' . $conn->error, 500);
    }
    $insert->bind_param('sis', $registrationId, $amount, $period);
    if (!$insert->execute()) {
        $error = $insert->error;
        $insert->close();
        sendError('Gagal membuat tagihan pembayaran: ' . $error, 500);
    }
    $insert->close();

    $billingId = (string)$conn->insert_id;
    if ($billingId !== '' && $billingId !== '0') {
        return $billingId;
    }

    $fallbackId = latestPaymentHistoryId($conn, $registrationId, $period);
    if ($fallbackId !== '') {
        return $fallbackId;
    }

    sendError('Tagihan dibuat, tetapi ID pembayaran tidak bisa dibaca dari database', 500);
}

function ensurePaymentPeriodColumn(mysqli $conn): void {
    if (!tableExists($conn, 'payment_history')) return;
    $conn->query("
        ALTER TABLE payment_history
        MODIFY period_month VARCHAR(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
    ");
}

function billingPaymentContext(mysqli $conn, string $billingId, ?string $userId = null): ?array {
    $userSql = $userId !== null && $userId !== '' ? ' AND rr.user_id = ?' : '';
    $stmt = $conn->prepare("
        SELECT
            ph.id,
            ph.amount,
            ph.payment_status,
            ph.period_month,
            rr.user_id,
            k.owner_id,
            k.title AS kos_title,
            r.room_number,
            u.display_name,
            u.email
        FROM payment_history ph
        INNER JOIN room_registrations rr ON rr.id = ph.registration_id
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        INNER JOIN users u ON u.id = rr.user_id
        WHERE ph.id = ?
          AND rr.status IN ('active', 'approved')
          $userSql
        LIMIT 1
    ");
    if (!$stmt) return null;
    if ($userSql !== '') {
        $stmt->bind_param('ss', $billingId, $userId);
    } else {
        $stmt->bind_param('s', $billingId);
    }
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

function notifyBillingPaymentPaid(mysqli $conn, array $context): void {
    try {
        require_once __DIR__ . '/merchant_helpers.php';
        merchantEnsureSchema($conn);

        $billingId = (string)($context['id'] ?? '');
        $amount = (int)round((float)($context['amount'] ?? 0));
        $kosTitle = (string)($context['kos_title'] ?? 'kos');
        $roomNumber = (string)($context['room_number'] ?? '-');
        $tenantName = (string)($context['display_name'] ?? 'Penyewa');
        $amountLabel = 'Rp ' . number_format($amount, 0, ',', '.');

        if (!empty($context['owner_id'])) {
            merchantCreateNotification(
                $conn,
                (string)$context['owner_id'],
                'Pembayaran sewa masuk',
                'Pembayaran ' . $tenantName . ' untuk kamar ' . $roomNumber . ' di ' . $kosTitle . ' sebesar ' . $amountLabel . ' sudah diterima.',
                'payment',
                'Lihat Keuangan',
                'owner:finance',
                'important'
            );
        }

        if (!empty($context['user_id'])) {
            merchantCreateNotification(
                $conn,
                (string)$context['user_id'],
                'Pembayaran sewa berhasil',
                'Pembayaran kamar ' . $roomNumber . ' di ' . $kosTitle . ' sudah diterima. Masa sewa Anda diperbarui otomatis.',
                'payment',
                'Lihat Tagihan',
                'billing:' . $billingId,
                'important'
            );
        }
    } catch (Throwable $e) {
        error_log('Failed to notify billing payment paid: ' . $e->getMessage());
    }
}

function resolveBillingIdForPayment(mysqli $conn, string $requestedOrderId, string $userId, int $amount): string {
    if (preg_match('/^generated-(.+)-(\d{4}(?:-\d{2})?(?:-\d{2})?)$/', $requestedOrderId, $matches)) {
        $registrationId = $matches[1];
        $period = $matches[2];

        $registration = $conn->prepare("
            SELECT id
            FROM room_registrations
            WHERE id = ?
              AND user_id = ?
              AND status IN ('active', 'approved')
            LIMIT 1
        ");
        if (!$registration) {
            sendError('Database error: ' . $conn->error, 500);
        }
        $registration->bind_param('ss', $registrationId, $userId);
        $registration->execute();
        $registrationRow = $registration->get_result()->fetch_assoc();
        $registration->close();

        if (!$registrationRow) {
            sendError('Registrasi kamar tidak aktif atau tidak ditemukan', 404);
        }

        $existing = $conn->prepare("
            SELECT id, payment_status, payment_method
            FROM payment_history
            WHERE registration_id = ? AND period_month = ?
            ORDER BY created_at DESC
            LIMIT 1
        ");
        if (!$existing) {
            sendError('Database error: ' . $conn->error, 500);
        }
        $existing->bind_param('ss', $registrationId, $period);
        $existing->execute();
        $existingRow = $existing->get_result()->fetch_assoc();
        $existing->close();

        if ($existingRow) {
            if (($existingRow['payment_status'] ?? '') === 'paid') {
                sendError('Tagihan sudah dibayar', 400);
            }
            if (($existingRow['payment_status'] ?? '') === 'cancelled') {
                sendError('Tagihan sudah dibatalkan', 400);
            }
            return (string)$existingRow['id'];
        }

        return createPaymentHistoryForGeneratedBill($conn, $registrationId, $amount, $period);
    }

    $billingId = preg_replace('/[^A-Za-z0-9\-_]/', '-', $requestedOrderId);
    if ($billingId === '') {
        sendError('order_id tidak valid', 400);
    }

    $existing = $conn->prepare("
        SELECT ph.payment_status, ph.payment_method
        FROM payment_history ph
        INNER JOIN room_registrations rr ON rr.id = ph.registration_id
        WHERE ph.id = ? AND rr.user_id = ? AND rr.status IN ('active', 'approved')
        LIMIT 1
    ");
    if (!$existing) {
        sendError('Database error: ' . $conn->error, 500);
    }
    $existing->bind_param('ss', $billingId, $userId);
    $existing->execute();
    $existingRow = $existing->get_result()->fetch_assoc();
    $existing->close();

    if (!$existingRow) {
        sendError('Tagihan tidak ditemukan', 404);
    }
    if (($existingRow['payment_status'] ?? '') === 'paid') {
        sendError('Tagihan sudah dibayar', 400);
    }
    if (($existingRow['payment_status'] ?? '') === 'cancelled') {
        sendError('Tagihan sudah dibatalkan', 400);
    }

    $markPending = $conn->prepare("
        UPDATE payment_history
        SET payment_status = 'unpaid', payment_method = 'MIDTRANS'
        WHERE id = ? AND payment_status NOT IN ('paid', 'cancelled')
    ");
    if (!$markPending) {
        sendError('Database error: ' . $conn->error, 500);
    }
    $markPending->bind_param('s', $billingId);
    $markPending->execute();
    $markPending->close();

    return $billingId;
}

$body = json_decode(file_get_contents('php://input'), true);
if (!is_array($body)) {
    sendError('Invalid JSON request', 400);
}

$action = trim((string)($body['action'] ?? 'create'));
if ($action === 'create_order_payment') {
    $orderInput = trim((string)($body['order_id'] ?? $body['orderId'] ?? ''));
    $paymentMethodInput = trim((string)($body['payment_method'] ?? $body['paymentMethod'] ?? ''));
    if ($orderInput === '') {
        sendError('order_id wajib diisi', 400);
    }

    require_once __DIR__ . '/../config/db.php';
    require_once __DIR__ . '/merchant_helpers.php';
    merchantEnsureSchema($conn);

    $stmt = $conn->prepare("
        SELECT o.*, m.business_name, m.user_id AS merchant_user_id, m.merchant_type,
               u.email, u.display_name
        FROM orders o
        INNER JOIN merchants m ON m.id = o.merchant_id
        INNER JOIN users u ON u.id = o.user_id
        WHERE (CAST(o.id AS CHAR) = ? OR o.order_code = ?)
          AND o.user_id = ?
        LIMIT 1
    ");
    if (!$stmt) {
        sendError('Database error: ' . $conn->error, 500);
    }
    $stmt->bind_param('sss', $orderInput, $orderInput, $userId);
    $stmt->execute();
    $order = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$order) {
        sendError('Pesanan tidak ditemukan', 404);
    }

    $currentPaymentStatus = strtolower((string)($order['payment_status'] ?? ''));
    $currentOrderStatus = strtolower((string)($order['status'] ?? ''));
    if ($currentPaymentStatus === 'paid') {
        sendError('Pembayaran pesanan sudah tercatat', 400);
    }
    if (in_array($currentPaymentStatus, ['cancelled'], true) ||
        in_array($currentOrderStatus, ['done', 'completed', 'cancelled'], true)) {
        sendError('Pesanan sudah selesai atau tidak dapat dibayar', 400);
    }

    $serviceType = strtolower((string)($order['service_type'] ?? $order['merchant_type'] ?? ''));
    if ($serviceType === 'catering' && strtolower((string)($order['status'] ?? '')) !== 'accepted') {
        sendError('Pesanan catering perlu disetujui merchant sebelum dibayar', 400);
    }
    $paymentMethod = $paymentMethodInput !== '' ? $paymentMethodInput : (string)($order['payment_method'] ?? '');
    if ($paymentMethod === '') {
        $paymentMethod = 'bca';
    }
    if ($serviceType === 'catering' &&
        (textContains(strtolower($paymentMethod), 'cod') || textContains(strtolower($paymentMethod), 'cash'))) {
        sendError('Catering tidak mendukung pembayaran COD', 400);
    }

    $enabledPayments = midtransEnabledPayments($paymentMethod);
    $amount = (int)round((float)($order['total_harga'] ?? 0));
    if ($amount <= 0) {
        sendError($serviceType === 'laundry'
            ? 'Total laundry belum ditentukan merchant'
            : 'Total pesanan tidak valid', 400);
    }

    $orderIdInt = (int)$order['id'];
    $items = [];
    $itemsStmt = $conn->prepare("
        SELECT oi.product_id, oi.qty, oi.harga, p.nama_produk
        FROM order_items oi
        LEFT JOIN products p ON p.id = oi.product_id
        WHERE oi.order_id = ?
        ORDER BY oi.id ASC
    ");
    if ($itemsStmt) {
        $itemsStmt->bind_param('i', $orderIdInt);
        $itemsStmt->execute();
        $rows = $itemsStmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $itemsStmt->close();
        foreach ($rows as $index => $item) {
            $price = (int)round((float)($item['harga'] ?? 0));
            $quantity = (int)($item['qty'] ?? 1);
            if ($price <= 0 || $quantity <= 0) continue;
            $items[] = [
                'id' => (string)($item['product_id'] ?? ('item-' . ($index + 1))),
                'price' => $price,
                'quantity' => $quantity,
                'name' => substr((string)($item['nama_produk'] ?? 'Item Pesanan'), 0, 50),
            ];
        }
    }
    $itemsTotal = array_reduce($items, fn($sum, $item) => $sum + ($item['price'] * $item['quantity']), 0);
    if (empty($items) || $itemsTotal !== $amount) {
        $items = [[
            'id' => 'order-' . $orderIdInt,
            'price' => $amount,
            'quantity' => 1,
            'name' => substr((string)($order['order_code'] ?? 'Pembayaran Pesanan'), 0, 50),
        ]];
    }

    $orderSuffix = date('His') . mt_rand(100, 999);
    $midtransOrderId = 'ORD-' . $orderIdInt . '-' . $orderSuffix;
    $customerName = trim((string)($order['customer_name'] ?? ''));
    if ($customerName === '') {
        $customerName = (string)($order['display_name'] ?? 'User');
    }

    $transactionParams = [
        'transaction_details' => [
            'order_id' => $midtransOrderId,
            'gross_amount' => $amount,
        ],
        'customer_details' => [
            'first_name' => $customerName,
            'email' => (string)($order['email'] ?? ''),
        ],
        'item_details' => $items,
        'enabled_payments' => $enabledPayments,
        'callbacks' => midtransCallbackUrls(),
    ];

    try {
        $paymentUrl = \Midtrans\Snap::getSnapUrl($transactionParams);
        $update = $conn->prepare("
            UPDATE orders
            SET payment_method = ?,
                payment_status = 'waiting_payment',
                midtrans_order_id = ?,
                updated_at = NOW()
            WHERE id = ? AND user_id = ?
        ");
        if (!$update) {
            sendError('Database error: ' . $conn->error, 500);
        }
        $update->bind_param('ssis', $paymentMethod, $midtransOrderId, $orderIdInt, $userId);
        $update->execute();
        $update->close();

        sendSuccess([
            'payment_url' => $paymentUrl,
            'midtrans_order_id' => $midtransOrderId,
            'order_id' => (string)$orderIdInt,
            'payment_method' => $paymentMethod,
            'enabled_payments' => $enabledPayments,
            'midtrans_config' => midtransSandboxInfo(),
        ], 'Midtrans pembayaran pesanan berhasil dibuat');
    } catch (Exception $e) {
        sendError('Gagal membuat transaksi Midtrans: ' . $e->getMessage(), 500);
    }
}

if ($action === 'sync_order_status') {
    $midtransOrderId = trim((string)($body['midtrans_order_id'] ?? ''));
    if ($midtransOrderId === '') {
        sendError('midtrans_order_id wajib diisi', 400);
    }

    try {
        $statusResponse = \Midtrans\Transaction::status($midtransOrderId);
        $transactionStatus = (string)($statusResponse->transaction_status ?? '');
        $paymentType = (string)($statusResponse->payment_type ?? '');
        $localStatus = localOrderPaymentStatus($transactionStatus);
        $orderId = orderIdFromMidtransOrderId($midtransOrderId);

        require_once __DIR__ . '/../config/db.php';
        require_once __DIR__ . '/merchant_helpers.php';
        merchantEnsureSchema($conn);

        $existingOrder = null;
        $lookup = $conn->prepare("
            SELECT o.id, o.order_code, o.payment_status, o.service_type,
                   m.user_id AS merchant_user_id
            FROM orders o
            INNER JOIN merchants m ON m.id = o.merchant_id
            WHERE (o.midtrans_order_id = ? OR o.id = ?)
              AND o.user_id = ?
            LIMIT 1
        ");
        if ($lookup) {
            $orderIdForLookup = $orderId ?? 0;
            $lookup->bind_param('sis', $midtransOrderId, $orderIdForLookup, $userId);
            $lookup->execute();
            $existingOrder = $lookup->get_result()->fetch_assoc();
            $lookup->close();
        }
        if (!$existingOrder) {
            sendError('Pesanan Midtrans tidak ditemukan', 404);
        }

        $stmt = $conn->prepare("
            UPDATE orders
            SET payment_status = ?,
                payment_method = IF(? = '' OR ? = 'bank_transfer', payment_method, ?),
                paid_at = IF(? = 'paid', COALESCE(paid_at, NOW()), paid_at),
                subscription_status = IF(
                    service_type = 'catering'
                    AND ? = 'paid'
                    AND COALESCE(subscription_status, '') NOT IN ('cancel_requested', 'ended'),
                    'active',
                    subscription_status
                ),
                updated_at = NOW()
            WHERE (midtrans_order_id = ? OR id = ?)
              AND user_id = ?
        ");
        if (!$stmt) {
            sendError('Database error: ' . $conn->error, 500);
        }
        $orderIdForBind = $orderId ?? 0;
        $stmt->bind_param('sssssssis', $localStatus, $paymentType, $paymentType, $paymentType, $localStatus, $localStatus, $midtransOrderId, $orderIdForBind, $userId);
        $stmt->execute();
        $affectedRows = $stmt->affected_rows;
        $stmt->close();

        $wasAlreadyPaid = strtolower((string)($existingOrder['payment_status'] ?? '')) === 'paid';
        if ($localStatus === 'paid' && !$wasAlreadyPaid) {
            if ($orderIdForBind > 0) {
                merchantActivateCateringSubscription($conn, $orderIdForBind);
            }
            $merchantUserId = $existingOrder['merchant_user_id'] ?? null;
            $orderCode = $existingOrder['order_code'] ?? ('#' . $orderIdForBind);
            if ($merchantUserId) {
                merchantCreateNotification(
                    $conn,
                    (string)$merchantUserId,
                    'Pembayaran pesanan berhasil',
                    'Pembayaran Midtrans untuk ' . $orderCode . ' sudah diterima.',
                    'payment',
                    'Lihat Pesanan',
                    'order:' . (string)$orderIdForBind,
                    'important'
                );
            }
            merchantCreateNotification(
                $conn,
                (string)$userId,
                'Pembayaran berhasil',
                'Pembayaran ' . $orderCode . ' berhasil diterima. Pesanan akan dilanjutkan merchant.',
                'payment',
                'Lihat Pesanan',
                'order:' . (string)$orderIdForBind,
                'important'
            );
        } elseif ($localStatus === 'paid') {
            if ($orderIdForBind > 0) {
                merchantActivateCateringSubscription($conn, $orderIdForBind);
            }
        }

        sendSuccess([
            'order_id' => $orderId !== null ? (string)$orderId : null,
            'midtrans_order_id' => $midtransOrderId,
            'transaction_status' => $transactionStatus,
            'payment_status' => $localStatus,
            'payment_type' => $paymentType,
            'updated' => $affectedRows > 0,
        ], 'Status Midtrans pesanan berhasil disinkronkan');
    } catch (Exception $e) {
        sendError('Gagal cek status Midtrans pesanan: ' . $e->getMessage(), 500);
    }
}

if ($action === 'sync_status') {
    $midtransOrderId = trim((string)($body['midtrans_order_id'] ?? ''));
    if ($midtransOrderId === '') {
        sendError('midtrans_order_id wajib diisi', 400);
    }

    try {
        $statusResponse = \Midtrans\Transaction::status($midtransOrderId);
        $transactionStatus = (string)($statusResponse->transaction_status ?? '');
        $paymentType = (string)($statusResponse->payment_type ?? '');
        $billingId = billingIdFromMidtransOrderId($midtransOrderId);
        $localStatus = localPaymentStatus($transactionStatus);

        require_once __DIR__ . '/../config/db.php';
        $paymentContext = billingPaymentContext($conn, $billingId, (string)$userId);
        $wasAlreadyPaid = strtolower((string)($paymentContext['payment_status'] ?? '')) === 'paid';
        $stmt = $conn->prepare("
            UPDATE payment_history ph
            INNER JOIN room_registrations rr ON rr.id = ph.registration_id
            SET ph.payment_status = ?,
                ph.payment_method = NULLIF(?, ''),
                ph.paid_at = IF(? = 'paid', COALESCE(ph.paid_at, NOW()), ph.paid_at),
                rr.end_date = IF(? = 'paid', NULL, rr.end_date)
            WHERE ph.id = ?
              AND rr.user_id = ?
              AND rr.status IN ('active', 'approved')
              AND ph.payment_status <> 'cancelled'
        ");
        if (!$stmt) {
            sendError('Database error: ' . $conn->error, 500);
        }
        $stmt->bind_param('ssssss', $localStatus, $paymentType, $localStatus, $localStatus, $billingId, $userId);
        $stmt->execute();
        $affectedRows = $stmt->affected_rows;
        $stmt->close();

        if ($localStatus === 'paid' && !$wasAlreadyPaid && $paymentContext) {
            notifyBillingPaymentPaid($conn, $paymentContext);
        }

        sendSuccess([
            'billing_id' => $billingId,
            'midtrans_order_id' => $midtransOrderId,
            'transaction_status' => $transactionStatus,
            'payment_status' => $localStatus,
            'payment_type' => $paymentType,
            'updated' => $affectedRows > 0,
        ], 'Status Midtrans berhasil disinkronkan');
    } catch (Exception $e) {
        sendError('Gagal cek status Midtrans: ' . $e->getMessage(), 500);
    }
}

$orderId = trim((string)($body['order_id'] ?? ''));
$amount = isset($body['amount']) ? (float)$body['amount'] : 0;
$customerName = trim((string)($body['customer_name'] ?? ''));
$customerEmail = trim((string)($body['customer_email'] ?? ''));
$paymentMethod = trim((string)($body['payment_method'] ?? 'bca'));
$items = $body['items'] ?? [];

if ($orderId === '' || $amount <= 0) {
    sendError('order_id dan amount wajib diisi', 400);
}

$amount = (int)round($amount);

require_once __DIR__ . '/../config/db.php';
ensurePaymentPeriodColumn($conn);
$billingId = resolveBillingIdForPayment($conn, $orderId, (string)$userId, $amount);

$billingContext = billingPaymentContext($conn, $billingId, (string)$userId);
if ($billingContext) {
    if ($customerName === '' || strtolower($customerName) === 'pelanggan kos') {
        $customerName = (string)($billingContext['display_name'] ?? $customerName);
    }
    if ($customerEmail === '' || strtolower($customerEmail) === 'customer@example.com') {
        $customerEmail = (string)($billingContext['email'] ?? $customerEmail);
    }
}
if ($customerName === '') {
    $customerName = 'Penyewa Kos';
}
if ($customerEmail === '') {
    $customerEmail = 'customer@example.com';
}

// Midtrans order_id must be unique and max 50 characters.
$orderSuffix = date('His') . mt_rand(100, 999);
$maxBillingIdLength = 50 - strlen('PAY--') - strlen($orderSuffix);
if (strlen($billingId) > $maxBillingIdLength) {
    $billingId = substr($billingId, 0, $maxBillingIdLength);
}
$orderId = 'PAY-' . $billingId . '-' . $orderSuffix;

if (!is_array($items) || count($items) === 0) {
    $items = [];
}

$normalizedItems = [];
foreach ($items as $index => $item) {
    if (!is_array($item)) {
        continue;
    }

    $price = (int)round((float)($item['price'] ?? 0));
    $quantity = (int)($item['quantity'] ?? 1);
    if ($price <= 0 || $quantity <= 0) {
        continue;
    }

    $normalizedItems[] = [
        'id' => (string)($item['id'] ?? ('item-' . ($index + 1))),
        'price' => $price,
        'quantity' => $quantity,
        'name' => substr((string)($item['name'] ?? 'Pembayaran Tagihan'), 0, 50),
    ];
}

if (count($normalizedItems) === 0) {
    $items = [
        [
            'id' => 'item-1',
            'price' => $amount,
            'quantity' => 1,
            'name' => 'Pembayaran Tagihan',
        ],
    ];
} else {
    $items = $normalizedItems;
}

$enabledPayments = midtransEnabledPayments($paymentMethod);

$transactionParams = [
    'transaction_details' => [
        'order_id' => $orderId,
        'gross_amount' => $amount,
    ],
    'customer_details' => [
        'first_name' => $customerName,
        'email' => $customerEmail,
    ],
    'item_details' => $items,
    'enabled_payments' => $enabledPayments,
    'callbacks' => midtransCallbackUrls(),
];

try {
    $paymentUrl = \Midtrans\Snap::getSnapUrl($transactionParams);

    sendSuccess([
        'payment_url' => $paymentUrl,
        'order_id' => $orderId,
        'billing_id' => $billingId,
        'payment_method' => $paymentMethod,
        'enabled_payments' => $enabledPayments,
        'midtrans_config' => midtransSandboxInfo(),
    ], 'Midtrans pembayaran berhasil dibuat');
} catch (Exception $e) {
    sendError('Gagal membuat transaksi Midtrans: ' . $e->getMessage(), 500);
}
