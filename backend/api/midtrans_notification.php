<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/midtrans.php';
require_once __DIR__ . '/../utils/response.php';

midtransConfig();

// Fungsi untuk verifikasi signature Midtrans
function verifyMidtransSignature(array $notificationData, string $signatureKey): bool {
    $orderId = $notificationData['order_id'] ?? '';
    $statusCode = $notificationData['status_code'] ?? '';
    $grossAmount = $notificationData['gross_amount'] ?? '';
    $serverKey = MIDTRANS_SERVER_KEY;

    $input = $orderId . $statusCode . $grossAmount . $serverKey;
    $signature = hash('sha512', $input);

    return $signature === $signatureKey;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendError('Only POST method allowed', 405);
}

$body = json_decode(file_get_contents('php://input'), true);
if (!is_array($body)) {
    sendError('Invalid JSON request', 400);
}

// Verifikasi signature
$signatureKey = $_SERVER['HTTP_X_CALLBACK_SIGNATURE'] ?? $body['signature_key'] ?? '';
if (!verifyMidtransSignature($body, $signatureKey)) {
    error_log('Midtrans notification invalid signature: header=' . ($_SERVER['HTTP_X_CALLBACK_SIGNATURE'] ?? 'none') . ', body_signature=' . ($body['signature_key'] ?? 'none'));
    sendError('Invalid signature', 401);
}

$orderId = (string)($body['order_id'] ?? '');
$rawMidtransOrderId = $orderId;
if (strpos($orderId, 'PAY-') === 0) {
    $midtransOrderId = substr($orderId, 4);
    $lastDashPosition = strrpos($midtransOrderId, '-');
    if ($lastDashPosition !== false) {
        $orderId = substr($midtransOrderId, 0, $lastDashPosition);
    } else {
        $orderId = $midtransOrderId;
    }
}
$transactionStatus = $body['transaction_status'] ?? '';
$paymentType = $body['payment_type'] ?? '';
$fraudStatus = $body['fraud_status'] ?? '';

if ($orderId === '' || $transactionStatus === '') {
    sendError('Missing required fields: order_id or transaction_status', 400);
}

// Map status Midtrans ke status lokal
$statusMapping = [
    'capture' => 'paid',
    'settlement' => 'paid',
    'pending' => 'unpaid',
    'deny' => 'unpaid',
    'cancel' => 'unpaid',
    'expire' => 'unpaid',
    'failure' => 'unpaid',
];

$localStatus = $statusMapping[$transactionStatus] ?? 'unpaid';

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/merchant_helpers.php';

function notificationBillingPaymentContext(mysqli $conn, string $billingId): ?array {
    $stmt = $conn->prepare("
        SELECT
            ph.id,
            ph.amount,
            ph.payment_status,
            rr.user_id,
            k.owner_id,
            k.title AS kos_title,
            r.room_number,
            u.display_name
        FROM payment_history ph
        INNER JOIN room_registrations rr ON rr.id = ph.registration_id
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        INNER JOIN users u ON u.id = rr.user_id
        WHERE ph.id = ?
          AND rr.status IN ('active', 'approved')
        LIMIT 1
    ");
    if (!$stmt) return null;
    $stmt->bind_param('s', $billingId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

function notificationCreateOwnerBillingPaymentNotification(mysqli $conn, string $ownerId, string $title, string $message): void {
    $notificationId = merchantCreateNotification(
        $conn,
        $ownerId,
        $title,
        $message,
        'payment',
        'Lihat Keuangan',
        'owner:finance',
        'important',
        false
    );

    if ($notificationId > 0) {
        merchantDispatchNotificationPush(
            $conn,
            $notificationId,
            $ownerId,
            $title,
            $message,
            'payment',
            'owner:finance',
            true
        );
    }
}

function notificationNotifyBillingPaid(mysqli $conn, array $context): void {
    try {
        merchantEnsureSchema($conn);

        $billingId = (string)($context['id'] ?? '');
        $amount = (int)round((float)($context['amount'] ?? 0));
        $kosTitle = (string)($context['kos_title'] ?? 'kos');
        $roomNumber = (string)($context['room_number'] ?? '-');
        $tenantName = (string)($context['display_name'] ?? 'Penyewa');
        $amountLabel = 'Rp ' . number_format($amount, 0, ',', '.');

        if (!empty($context['owner_id'])) {
            notificationCreateOwnerBillingPaymentNotification(
                $conn,
                (string)$context['owner_id'],
                'Pembayaran sewa masuk',
                'Pembayaran ' . $tenantName . ' untuk kamar ' . $roomNumber . ' di ' . $kosTitle . ' sebesar ' . $amountLabel . ' sudah diterima.'
            );
        } else {
            error_log('Midtrans billing paid without owner_id for billing: ' . $billingId);
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
        error_log('Failed to notify Midtrans billing paid: ' . $e->getMessage());
    }
}

if (strpos($rawMidtransOrderId, 'ORD-') === 0) {
    require_once __DIR__ . '/merchant_helpers.php';
    merchantEnsureSchema($conn);

    $rawOrder = substr($rawMidtransOrderId, 4);
    $dashPosition = strpos($rawOrder, '-');
    $orderIdForOrder = $dashPosition === false ? $rawOrder : substr($rawOrder, 0, $dashPosition);
    if (!ctype_digit($orderIdForOrder)) {
        sendError('Invalid order id', 400);
    }

    $orderPaymentStatus = in_array($transactionStatus, ['capture', 'settlement'], true)
        ? 'paid'
        : ($transactionStatus === 'pending' ? 'waiting_payment' : 'cancelled');
    $orderInt = (int)$orderIdForOrder;

    $existingOrder = null;
    $lookup = $conn->prepare("
        SELECT o.id, o.order_code, o.user_id, o.payment_status,
               m.user_id AS merchant_user_id
        FROM orders o
        INNER JOIN merchants m ON m.id = o.merchant_id
        WHERE o.id = ? OR o.midtrans_order_id = ?
        LIMIT 1
    ");
    if ($lookup) {
        $lookup->bind_param('is', $orderInt, $rawMidtransOrderId);
        $lookup->execute();
        $existingOrder = $lookup->get_result()->fetch_assoc();
        $lookup->close();
    }

    $stmt = $conn->prepare("
        UPDATE orders
        SET payment_status = ?,
            payment_method = IF(? = '', payment_method, ?),
            paid_at = IF(? = 'paid', COALESCE(paid_at, NOW()), paid_at),
            subscription_status = IF(
                service_type = 'catering'
                AND ? = 'paid'
                AND COALESCE(subscription_status, '') NOT IN ('cancel_requested', 'ended'),
                'active',
                subscription_status
            ),
            updated_at = NOW()
        WHERE id = ? OR midtrans_order_id = ?
    ");
    if (!$stmt) {
        sendError('Database error: ' . $conn->error, 500);
    }
    $stmt->bind_param('sssssis', $orderPaymentStatus, $paymentType, $paymentType, $orderPaymentStatus, $orderPaymentStatus, $orderInt, $rawMidtransOrderId);
    $success = $stmt->execute();
    $stmt->close();

    if (!$success) {
        sendError('Failed to update order payment status', 500);
    }

    if ($orderPaymentStatus === 'paid') {
        merchantActivateCateringSubscription($conn, $orderInt);
        $wasAlreadyPaid = strtolower((string)($existingOrder['payment_status'] ?? '')) === 'paid';
        if (!$wasAlreadyPaid && $existingOrder) {
            $orderCode = (string)($existingOrder['order_code'] ?? ('#' . $orderInt));
            $merchantUserId = (string)($existingOrder['merchant_user_id'] ?? '');
            $orderUserId = (string)($existingOrder['user_id'] ?? '');
            if ($merchantUserId !== '') {
                merchantCreateNotification(
                    $conn,
                    $merchantUserId,
                    'Pembayaran pesanan berhasil',
                    'Pembayaran Midtrans untuk ' . $orderCode . ' sudah diterima.',
                    'payment',
                    'Lihat Pesanan',
                    'order:' . (string)$orderInt,
                    'important'
                );
            }
            if ($orderUserId !== '') {
                merchantCreateNotification(
                    $conn,
                    $orderUserId,
                    'Pembayaran berhasil',
                    'Pembayaran ' . $orderCode . ' berhasil diterima. Pesanan akan dilanjutkan merchant.',
                    'payment',
                    'Lihat Pesanan',
                    'order:' . (string)$orderInt,
                    'important'
                );
            }
        }
    }

    error_log("Midtrans order notification: Order ID $orderIdForOrder, Status $transactionStatus -> $orderPaymentStatus");
    sendSuccess(null, 'Order notification processed successfully');
}

// Update payment_history berdasarkan order_id
$paymentContext = notificationBillingPaymentContext($conn, $orderId);
$wasAlreadyPaid = strtolower((string)($paymentContext['payment_status'] ?? '')) === 'paid';
$stmt = $conn->prepare("
    UPDATE payment_history ph
    INNER JOIN room_registrations rr ON rr.id = ph.registration_id
    SET ph.payment_status = ?,
        ph.payment_method = ?,
        ph.paid_at = IF(? = 'paid', COALESCE(ph.paid_at, NOW()), ph.paid_at),
        rr.end_date = IF(? = 'paid', NULL, rr.end_date)
    WHERE ph.id = ?
      AND rr.status IN ('active', 'approved')
      AND ph.payment_status <> 'cancelled'
");
if (!$stmt) {
    sendError('Database error: ' . $conn->error, 500);
}

$stmt->bind_param('sssss', $localStatus, $paymentType, $localStatus, $localStatus, $orderId);
$success = $stmt->execute();
$stmt->close();

if (!$success) {
    sendError('Failed to update payment status', 500);
}

if ($localStatus === 'paid' && !$wasAlreadyPaid && $paymentContext) {
    notificationNotifyBillingPaid($conn, $paymentContext);
}

// Log notifikasi untuk debugging
error_log("Midtrans notification: Order ID $orderId, Status $transactionStatus -> $localStatus");

sendSuccess(null, 'Notification processed successfully');
