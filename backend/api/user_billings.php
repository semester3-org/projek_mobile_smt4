<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
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

function monthName(string $period): string {
    $months = [
        '01' => 'Januari',
        '02' => 'Februari',
        '03' => 'Maret',
        '04' => 'April',
        '05' => 'Mei',
        '06' => 'Juni',
        '07' => 'Juli',
        '08' => 'Agustus',
        '09' => 'September',
        '10' => 'Oktober',
        '11' => 'November',
        '12' => 'Desember',
    ];
    [$year, $month] = explode('-', $period . '-');
    return ($months[$month] ?? $period) . ' ' . $year;
}

function currentMonthPeriod(): string {
    return date('Y-m');
}

function billPayload(
    string $id,
    string $period,
    float $amount,
    string $status,
    ?string $paymentMethod,
    ?string $paymentDate,
    array $room
): array {
    return [
        'id' => $id,
        'itemDescription' => 'Sewa ' . ($room['kos_name'] ?? 'Kos') . ' - ' . monthName($period),
        'amount' => $amount,
        'dueDate' => $period . '-05',
        'status' => $status,
        'paymentMethod' => $paymentMethod,
        'paymentDate' => $paymentDate,
        'kosName' => $room['kos_name'] ?? '',
        'kosAccessCode' => $room['access_code'] ?? '',
        'roomNumber' => $room['room_number'] ?? '',
        'roomType' => $room['room_type'] ?? '',
    ];
}

function activeRoomForUser(mysqli $conn, string $userId): ?array {
    if (!tableExists($conn, 'room_registrations') ||
        !tableExists($conn, 'kos_rooms') ||
        !tableExists($conn, 'kos_listings')) {
        return null;
    }

    $stmt = $conn->prepare("
        SELECT
            rr.id AS registration_id,
            k.title AS kos_name,
            k.access_code,
            r.room_number,
            r.room_type,
            r.price_per_month
        FROM room_registrations rr
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        WHERE rr.user_id = ? AND rr.status IN ('active', 'approved', 'pending')
        ORDER BY rr.registered_at DESC
        LIMIT 1
    ");
    if (!$stmt) return null;
    $stmt->bind_param('s', $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

function generatedCurrentBill(mysqli $conn, string $userId): array {
    $room = activeRoomForUser($conn, $userId);
    if (!$room) return [];

    $period = currentMonthPeriod();
    return [
        billPayload(
            'generated-' . $room['registration_id'] . '-' . $period,
            $period,
            (float)$room['price_per_month'],
            'belum_bayar',
            null,
            null,
            $room
        ),
    ];
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendJson(false, null, 'Only GET method allowed', 405);
}

$payload = JWT::getPayloadFromRequest();
$userId = $payload['sub'] ?? null;

if (!$userId) {
    sendJson(false, null, 'Unauthorized', 401);
}

if (!tableExists($conn, 'room_registrations') ||
    !tableExists($conn, 'kos_rooms') ||
    !tableExists($conn, 'kos_listings')) {
    sendJson(true, [], 'User belum tersambung dengan kos/kamar');
}

if (!tableExists($conn, 'payment_history')) {
    sendJson(true, generatedCurrentBill($conn, $userId), 'Tagihan kamar aktif berhasil dimuat');
}

$sql = "
    SELECT
        ph.id,
        ph.amount,
        ph.period_month,
        ph.payment_status,
        ph.payment_method,
        ph.paid_at,
        k.title AS kos_name,
        k.access_code,
        r.room_number,
        r.room_type,
        r.price_per_month,
        rr.id AS registration_id
    FROM payment_history ph
    INNER JOIN room_registrations rr ON rr.id = ph.registration_id
    INNER JOIN kos_listings k ON k.id = rr.kos_id
    INNER JOIN kos_rooms r ON r.id = rr.room_id
    WHERE rr.user_id = ?
    ORDER BY ph.period_month DESC
";

$stmt = $conn->prepare($sql);
if (!$stmt) {
    sendJson(false, null, 'Database error: ' . $conn->error, 500);
}

$stmt->bind_param('s', $userId);
$stmt->execute();
$result = $stmt->get_result();
$rows = [];

while ($r = $result->fetch_assoc()) {
    $status = 'belum_bayar';
    if ($r['payment_status'] === 'paid') {
        $status = 'lunas';
    } elseif (!empty($r['payment_method'])) {
        $status = 'pending';
    }
    $rows[] = billPayload(
        (string)$r['id'],
        $r['period_month'],
        (float)($r['amount'] ?? $r['price_per_month']),
        $status,
        $r['payment_method'],
        $r['paid_at'],
        $r
    );
}
$stmt->close();

sendJson(true, count($rows) > 0 ? $rows : generatedCurrentBill($conn, $userId), 'Tagihan berhasil dimuat');
?>
