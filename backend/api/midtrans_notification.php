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

    error_log("Midtrans order notification: Order ID $orderIdForOrder, Status $transactionStatus -> $orderPaymentStatus");
    sendSuccess(null, 'Order notification processed successfully');
}

// Update payment_history berdasarkan order_id
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

// Log notifikasi untuk debugging
error_log("Midtrans notification: Order ID $orderId, Status $transactionStatus -> $localStatus");

sendSuccess(null, 'Notification processed successfully');
