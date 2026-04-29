<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Only GET method allowed']);
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

function tenantPayload(array $row): array {
    return [
        'registrationId' => (string)$row['registration_id'],
        'userId' => (string)$row['user_id'],
        'name' => $row['display_name'] ?? 'User',
        'email' => $row['email'] ?? '',
        'kosId' => (string)$row['kos_id'],
        'kosName' => $row['kos_name'] ?? '',
        'kosAccessCode' => $row['access_code'] ?? '',
        'roomNumber' => $row['room_number'] ?? '',
        'roomType' => $row['room_type'] ?? '',
        'roomPrice' => (float)($row['price_per_month'] ?? 0),
        'status' => $row['status'] ?? 'active',
        'startDate' => $row['start_date'] ?? null,
        'endDate' => $row['end_date'] ?? null,
        'registeredAt' => $row['registered_at'] ?? null,
    ];
}

$payload = JWT::getPayloadFromRequest();
if (!$payload) {
    sendJson(false, null, 'Unauthorized', 401);
}

$ownerId = $payload['sub'] ?? '';
$role = $payload['role'] ?? '';
if (!in_array($role, ['owner', 'admin'], true)) {
    sendJson(false, null, 'Forbidden: hanya owner yang bisa akses', 403);
}

foreach (['users', 'room_registrations', 'kos_rooms', 'kos_listings'] as $table) {
    if (!tableExists($conn, $table)) {
        sendJson(true, [], 'Data penghuni belum tersedia');
    }
}

$status = trim($_GET['status'] ?? '');
$params = [$ownerId];
$types = 's';
$statusSql = '';

if ($status !== '' && in_array($status, ['active', 'approved', 'pending', 'rejected', 'ended'], true)) {
    $statusSql = ' AND rr.status = ?';
    $params[] = $status;
    $types .= 's';
}

$sql = "
    SELECT
        rr.id AS registration_id,
        rr.user_id,
        rr.kos_id,
        rr.status,
        rr.start_date,
        rr.end_date,
        rr.registered_at,
        u.display_name,
        u.email,
        k.title AS kos_name,
        k.access_code,
        r.room_number,
        r.room_type,
        r.price_per_month
    FROM room_registrations rr
    INNER JOIN users u ON u.id = rr.user_id
    INNER JOIN kos_listings k ON k.id = rr.kos_id
    INNER JOIN kos_rooms r ON r.id = rr.room_id
    WHERE k.owner_id = ?
    $statusSql
    ORDER BY rr.registered_at DESC, k.title ASC, r.room_number ASC
";

$stmt = $conn->prepare($sql);
if (!$stmt) {
    sendJson(false, null, 'Database error: ' . $conn->error, 500);
}

$stmt->bind_param($types, ...$params);
$stmt->execute();
$rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
$stmt->close();

sendJson(true, array_map('tenantPayload', $rows), 'Daftar penghuni berhasil dimuat');
?>
