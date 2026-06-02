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
    return in_array($dataType, ['char', 'varchar', 'text'], true);
}

function nextPaymentHistoryNumericId(mysqli $conn): int {
    $result = $conn->query("SELECT COALESCE(MAX(CAST(id AS UNSIGNED)), 0) + 1 AS next_id FROM payment_history");
    if (!$result) {
        sendJson(false, null, 'Database error: ' . $conn->error, 500);
    }
    $row = $result->fetch_assoc();
    return max(1, (int)($row['next_id'] ?? 1));
}

function createPaymentHistory(
    mysqli $conn,
    string $registrationId,
    int $amount,
    string $period,
    string $paymentMethod
): string {
    if (!paymentHistoryUsesAutoIncrementId($conn)) {
        $usesStringId = paymentHistoryUsesStringId($conn);
        $newId = $usesStringId ? uuid() : nextPaymentHistoryNumericId($conn);
        $insert = $conn->prepare("
            INSERT INTO payment_history
                (id, registration_id, amount, period_month, payment_status, payment_method, paid_at, created_at)
            VALUES (?, ?, ?, 'unpaid', ?, NULL, NOW())
        ");
        if (!$insert) {
            sendJson(false, null, 'Database error: ' . $conn->error, 500);
        }
        if ($usesStringId) {
            $insert->bind_param('ssis', $newId, $registrationId, $amount, $paymentMethod);
        } else {
            $insert->bind_param('isis', $newId, $registrationId, $amount, $paymentMethod);
        }
        if (!$insert->execute()) {
            $error = $insert->error;
            $insert->close();
            sendJson(false, null, 'Gagal membuat tagihan pembayaran: ' . $error, 500);
        }
        $insert->close();
        return (string)$newId;
    }

    $insert = $conn->prepare("
        INSERT INTO payment_history
            (registration_id, amount, period_month, payment_status, payment_method, paid_at, created_at)
        VALUES (?, ?, ?, 'unpaid', ?, NULL, NOW())
    ");
    if (!$insert) {
        sendJson(false, null, 'Database error: ' . $conn->error, 500);
    }
    $insert->bind_param('siss', $registrationId, $amount, $period, $paymentMethod);
    if (!$insert->execute()) {
        $error = $insert->error;
        $insert->close();
        sendJson(false, null, 'Gagal membuat tagihan pembayaran: ' . $error, 500);
    }
    $newId = (string)$conn->insert_id;
    $insert->close();
    return $newId;
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
    $newId = createPaymentHistory($conn, $registrationId, $amount, $period, $paymentMethod);

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
