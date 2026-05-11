<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';

function sendJson(bool $success, $data = null, string $message = '', int $code = 200): void {
    http_response_code($code);
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data' => $data,
    ], JSON_UNESCAPED_UNICODE);
    exit();
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

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJson(false, null, 'Only POST method allowed', 405);
}

$payload = JWT::getPayloadFromRequest();
$userId = $payload['sub'] ?? null;
if (!$userId) {
    sendJson(false, null, 'Unauthorized', 401);
}

$body = json_decode(file_get_contents('php://input'), true);
if (!is_array($body)) {
    sendJson(false, null, 'Invalid JSON request', 400);
}

$billingId = trim((string)($body['billingId'] ?? ''));
$paymentMethod = trim((string)($body['paymentMethod'] ?? ''));

if ($billingId === '' || $paymentMethod === '') {
    sendJson(false, null, 'ID tagihan dan metode pembayaran wajib diisi', 400);
}

if (!tableExists($conn, 'payment_history')) {
    sendJson(false, null, 'Tabel pembayaran belum tersedia', 500);
}

if (str_starts_with($billingId, 'generated-')) {
    $withoutPrefix = substr($billingId, strlen('generated-'));
    $period = substr($withoutPrefix, -7);
    $registrationId = substr($withoutPrefix, 0, -8);

    if ($registrationId === '' || !preg_match('/^\d{4}-\d{2}$/', $period)) {
        sendJson(false, null, 'Format tagihan tidak valid', 400);
    }

    $roomStmt = $conn->prepare("
        SELECT rr.id, r.price_per_month
        FROM room_registrations rr
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        WHERE rr.id = ? AND rr.user_id = ?
        LIMIT 1
    ");
    if (!$roomStmt) {
        sendJson(false, null, 'Database error', 500);
    }
    $roomStmt->bind_param('ss', $registrationId, $userId);
    $roomStmt->execute();
    $room = $roomStmt->get_result()->fetch_assoc();
    $roomStmt->close();

    if (!$room) {
        sendJson(false, null, 'Tagihan tidak ditemukan', 404);
    }

    $amount = (int)$room['price_per_month'];
    $insert = $conn->prepare("
        INSERT INTO payment_history
            (registration_id, amount, period_month, payment_status, payment_method, paid_at, created_at)
        VALUES (?, ?, ?, 'unpaid', ?, NULL, NOW())
    ");
    if (!$insert) {
        sendJson(false, null, 'Database error: ' . $conn->error, 500);
    }
    $insert->bind_param('siss', $registrationId, $amount, $period, $paymentMethod);
    $insert->execute();
    $newId = $conn->insert_id;
    $insert->close();

    sendJson(true, [
        'id' => (string)$newId,
        'status' => 'pending',
        'paymentMethod' => $paymentMethod,
    ], 'Pembayaran dikirim dan menunggu persetujuan owner');
}

$stmt = $conn->prepare("
    UPDATE payment_history ph
    INNER JOIN room_registrations rr ON rr.id = ph.registration_id
    SET ph.payment_method = ?, ph.payment_status = 'unpaid', ph.paid_at = NULL
    WHERE ph.id = ? AND rr.user_id = ? AND ph.payment_status <> 'paid'
");
if (!$stmt) {
    sendJson(false, null, 'Database error: ' . $conn->error, 500);
}
$stmt->bind_param('sis', $paymentMethod, $billingId, $userId);
$stmt->execute();
$affected = $stmt->affected_rows;
$stmt->close();

if ($affected <= 0) {
    sendJson(false, null, 'Tagihan tidak ditemukan atau sudah berhasil dibayar', 404);
}

sendJson(true, [
    'id' => $billingId,
    'status' => 'pending',
    'paymentMethod' => $paymentMethod,
], 'Pembayaran dikirim dan menunggu persetujuan owner');
?>
