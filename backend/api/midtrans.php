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

function ensurePaymentPeriodColumn(mysqli $conn): void {
    if (!tableExists($conn, 'payment_history')) return;
    $conn->query("
        ALTER TABLE payment_history
        MODIFY period_month VARCHAR(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
    ");
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

        $insert = $conn->prepare("
            INSERT INTO payment_history
                (registration_id, amount, period_month, payment_status, payment_method, created_at)
            VALUES (?, ?, ?, 'unpaid', 'MIDTRANS', NOW())
        ");
        if (!$insert) {
            sendError('Database error: ' . $conn->error, 500);
        }
        $insert->bind_param('sis', $registrationId, $amount, $period);
        $insert->execute();
        $billingId = (string)$conn->insert_id;
        $insert->close();

        if ($billingId === '' || $billingId === '0') {
            sendError('Gagal membuat tagihan pembayaran', 500);
        }

        return $billingId;
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
$paymentMethod = trim((string)($body['payment_method'] ?? 'QRIS'));
$items = $body['items'] ?? [];

if ($orderId === '' || $amount <= 0) {
    sendError('order_id dan amount wajib diisi', 400);
}

$amount = (int)round($amount);

require_once __DIR__ . '/../config/db.php';
ensurePaymentPeriodColumn($conn);
$billingId = resolveBillingIdForPayment($conn, $orderId, (string)$userId, $amount);

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

$normalizedMethod = strtolower($paymentMethod);
$enabledPayments = [];

if (textContains($normalizedMethod, 'shopeepay')) {
    $enabledPayments = ['shopeepay', 'qris'];
} elseif (textContains($normalizedMethod, 'bca') || textContains($normalizedMethod, 'mandiri') || textContains($normalizedMethod, 'virtual account') || textContains($normalizedMethod, 'bank')) {
    $enabledPayments = ['bank_transfer'];
} elseif (textContains($normalizedMethod, 'qris') || textContains($normalizedMethod, 'gopay') || textContains($normalizedMethod, 'ovo') || textContains($normalizedMethod, 'dana')) {
    $enabledPayments = ['gopay', 'qris'];
} elseif (textContains($normalizedMethod, 'credit') || textContains($normalizedMethod, 'debit') || textContains($normalizedMethod, 'kartu')) {
    $enabledPayments = ['credit_card'];
} else {
    sendError('Payment method tidak didukung: ' . $paymentMethod, 400);
}

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
