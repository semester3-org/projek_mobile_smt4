<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS');
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
    return sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}

function profilePayload(mysqli $conn, array $payload): array {
    $userId = $payload['sub'] ?? '';
    $base = [
        'id' => $userId,
        'email' => $payload['email'] ?? '',
        'displayName' => $payload['displayName'] ?? 'User',
        'role' => $payload['role'] ?? 'user',
        'photoUrl' => $payload['photoUrl'] ?? null,
        'kosName' => null,
        'kosAccessCode' => null,
        'roomNumber' => null,
        'roomType' => null,
    ];

    if (
        !$userId ||
        !tableExists($conn, 'users') ||
        !tableExists($conn, 'room_registrations') ||
        !tableExists($conn, 'kos_rooms') ||
        !tableExists($conn, 'kos_listings')
    ) {
        return $base;
    }

    $stmt = $conn->prepare("
        SELECT
            u.email,
            u.display_name,
            u.role,
            k.title AS kos_name,
            k.access_code,
            r.room_number,
            r.room_type
        FROM users u
        LEFT JOIN room_registrations rr
            ON rr.user_id = u.id
            AND rr.status IN ('active', 'approved', 'pending')
        LEFT JOIN kos_listings k ON k.id = rr.kos_id
        LEFT JOIN kos_rooms r ON r.id = rr.room_id
        WHERE u.id = ?
        ORDER BY rr.registered_at DESC
        LIMIT 1
    ");
    if (!$stmt) return $base;

    $stmt->bind_param('s', $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) return $base;

    return array_merge($base, [
        'email' => $row['email'] ?? $base['email'],
        'displayName' => $row['display_name'] ?? $base['displayName'],
        'role' => $row['role'] ?? $base['role'],
        'kosName' => $row['kos_name'] ?? null,
        'kosAccessCode' => $row['access_code'] ?? null,
        'roomNumber' => $row['room_number'] ?? null,
        'roomType' => $row['room_type'] ?? null,
    ]);
}

$payload = JWT::getPayloadFromRequest();
if (!$payload) {
    sendJson(false, null, 'Unauthorized', 401);
}

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    sendJson(true, profilePayload($conn, $payload), 'Profil berhasil dimuat');
}

$body = json_decode(file_get_contents('php://input'), true);
if (!is_array($body)) {
    sendJson(false, null, 'Invalid JSON request', 400);
}

$userId = $payload['sub'] ?? '';

if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $displayName = trim($body['displayName'] ?? '');

    if ($displayName === '') {
        sendJson(false, null, 'Nama wajib diisi', 400);
    }

    if (!tableExists($conn, 'users')) {
        sendJson(false, null, 'Tabel users belum tersedia', 500);
    }

    $stmt = $conn->prepare('UPDATE users SET display_name = ?, updated_at = NOW() WHERE id = ?');
    if (!$stmt) {
        sendJson(false, null, 'Database error', 500);
    }
    $stmt->bind_param('ss', $displayName, $userId);
    $stmt->execute();
    $stmt->close();

    $updatedPayload = array_merge($payload, [
        'displayName' => $displayName,
        'photoUrl' => trim($body['photoUrl'] ?? ''),
    ]);
    $data = profilePayload($conn, $updatedPayload);
    $data['phone'] = trim($body['phone'] ?? '');
    $data['address'] = trim($body['address'] ?? '');
    $data['photoUrl'] = trim($body['photoUrl'] ?? '');

    sendJson(true, $data, 'Profil berhasil diperbarui');
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJson(false, null, 'Only GET, POST, or PUT method allowed', 405);
}

$accessCode = strtoupper(trim($body['accessCode'] ?? ''));

if ($accessCode === '') {
    sendJson(false, null, 'Kode kos wajib diisi', 400);
}

if (!tableExists($conn, 'room_registrations') || !tableExists($conn, 'kos_rooms') || !tableExists($conn, 'kos_listings')) {
    sendJson(false, null, 'Tabel kos/kamar belum tersedia', 500);
}

$stmt = $conn->prepare("
    SELECT k.id AS kos_id, r.id AS room_id
    FROM kos_listings k
    JOIN kos_rooms r ON r.kos_id = k.id
    WHERE UPPER(k.access_code) = ?
    ORDER BY
        CASE WHEN r.status = 'available' THEN 0 ELSE 1 END,
        r.room_number ASC
    LIMIT 1
");
if (!$stmt) {
    sendJson(false, null, 'Database error', 500);
}

$stmt->bind_param('s', $accessCode);
$stmt->execute();
$room = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$room) {
    sendJson(false, null, 'Kode kos tidak ditemukan atau belum memiliki kamar', 404);
}

$check = $conn->prepare("SELECT id FROM room_registrations WHERE user_id = ? AND status IN ('active', 'approved', 'pending') LIMIT 1");
$check->bind_param('s', $userId);
$check->execute();
$existing = $check->get_result()->fetch_assoc();
$check->close();

if ($existing) {
    $upd = $conn->prepare("UPDATE room_registrations SET kos_id = ?, room_id = ?, status = 'active', updated_at = NOW() WHERE id = ?");
    $upd->bind_param('sss', $room['kos_id'], $room['room_id'], $existing['id']);
    $upd->execute();
    $upd->close();
} else {
    $id = uuid();
    $ins = $conn->prepare("
        INSERT INTO room_registrations
            (id, user_id, room_id, kos_id, status, start_date, registered_at, updated_at)
        VALUES (?, ?, ?, ?, 'active', CURDATE(), NOW(), NOW())
    ");
    $ins->bind_param('ssss', $id, $userId, $room['room_id'], $room['kos_id']);
    $ins->execute();
    $ins->close();
}

$mark = $conn->prepare("UPDATE kos_rooms SET status = 'occupied' WHERE id = ?");
$mark->bind_param('s', $room['room_id']);
$mark->execute();
$mark->close();

sendJson(true, profilePayload($conn, $payload), 'Kode kos berhasil disambungkan');
?>
