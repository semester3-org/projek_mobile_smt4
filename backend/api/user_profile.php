<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
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

function dateFromPeriodKey(string $period, string $rentalType, ?string $startDate = null): DateTime {
    $defaultDay = 5;
    $dueDay = $defaultDay;

    if ($startDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $startDate)) {
        $dueDay = (int)substr($startDate, 8, 2);
        if ($dueDay < 1 || $dueDay > 31) $dueDay = $defaultDay;
    }

    if ($rentalType === 'daily') {
        $date = DateTime::createFromFormat('Y-m-d', $period);
        return $date ?: new DateTime(date('Y-m-d'));
    }

    if ($rentalType === 'yearly') {
        $monthDay = $startDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $startDate)
            ? substr($startDate, 5, 5)
            : '01-01';
        $date = DateTime::createFromFormat('Y-m-d', $period . '-' . $monthDay);
        return $date ?: new DateTime(date('Y-m-d'));
    }

    $date = DateTime::createFromFormat('Y-m-d', $period . '-01');
    if (!$date) {
        return new DateTime(date('Y-m-d'));
    }

    $daysInMonth = (int)$date->format('t');
    if ($dueDay > $daysInMonth) $dueDay = $daysInMonth;

    return DateTime::createFromFormat('Y-m-d', $period . '-' . sprintf('%02d', $dueDay))
        ?: new DateTime(date('Y-m-d'));
}

function dueDateForPeriod(string $period, ?string $startDate = null, string $rentalType = 'monthly'): string {
    $date = dateFromPeriodKey($period, $rentalType, $startDate);
    $date->modify(match ($rentalType) {
        'daily' => '+1 day',
        'yearly' => '+1 year',
        default => '+1 month',
    });
    return $date->format('Y-m-d');
}

function addRentalPeriods(DateTime $date, string $rentalType, int $periods): DateTime {
    if ($periods <= 0) {
        return $date;
    }

    $date->modify(match ($rentalType) {
        'daily' => '+' . $periods . ' day',
        'yearly' => '+' . $periods . ' year',
        default => '+' . $periods . ' month',
    });
    return $date;
}

function getActiveUntil(mysqli $conn, string $userId): ?string {
    if (!tableExists($conn, 'payment_history') ||
        !tableExists($conn, 'room_registrations') ||
        !tableExists($conn, 'kos_rooms')) {
        return null;
    }

    $stmt = $conn->prepare("
        SELECT
            rr.id AS registration_id,
            rr.start_date,
            r.rental_type,
            COUNT(ph.id) AS paid_periods
        FROM room_registrations rr
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        INNER JOIN payment_history ph
            ON ph.registration_id = rr.id
            AND ph.payment_status = 'paid'
        WHERE rr.user_id = ?
          AND rr.status IN ('active', 'approved')
        GROUP BY rr.id, rr.start_date, r.rental_type
        ORDER BY rr.registered_at DESC
        LIMIT 1
    ");
    if (!$stmt) return null;
    $stmt->bind_param('s', $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) return null;
    $paidPeriods = (int)($row['paid_periods'] ?? 0);
    if ($paidPeriods <= 0) return null;

    $today = new DateTime(date('Y-m-d'));
    $startDate = $row['start_date'] ?? null;
    $base = $startDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $startDate)
        ? new DateTime($startDate)
        : new DateTime(date('Y-m-d'));
    if ($base < $today) {
        $base = $today;
    }

    return addRentalPeriods(
        $base,
        $row['rental_type'] ?? 'monthly',
        $paidPeriods
    )->format('Y-m-d');
}

function endRegistrationAndFreeRoom(mysqli $conn, string $registrationId, string $roomId, string $endDate): void {
    $endRegistration = $conn->prepare("
        UPDATE room_registrations
        SET status = 'cancelled', end_date = ?, updated_at = NOW()
        WHERE id = ? AND status IN ('active', 'approved')
    ");
    if (!$endRegistration) {
        throw new Exception($conn->error);
    }
    $endRegistration->bind_param('ss', $endDate, $registrationId);
    $endRegistration->execute();
    $endRegistration->close();

    $freeRoom = $conn->prepare("
        UPDATE kos_rooms
        SET status = 'available'
        WHERE id = ?
          AND NOT EXISTS (
              SELECT 1
              FROM room_registrations
              WHERE room_id = ?
                AND status IN ('active', 'approved', 'pending')
                AND id <> ?
          )
    ");
    if (!$freeRoom) {
        throw new Exception($conn->error);
    }
    $freeRoom->bind_param('sss', $roomId, $roomId, $registrationId);
    $freeRoom->execute();
    $freeRoom->close();
}

function expireScheduledEndDates(mysqli $conn, string $userId): void {
    if (!tableExists($conn, 'room_registrations') ||
        !tableExists($conn, 'kos_rooms')) {
        return;
    }

    $today = date('Y-m-d');
    $stmt = $conn->prepare("
        SELECT id, room_id, end_date
        FROM room_registrations
        WHERE user_id = ?
          AND status IN ('active', 'approved')
          AND end_date IS NOT NULL
          AND end_date < ?
    ");
    if (!$stmt) return;
    $stmt->bind_param('ss', $userId, $today);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    foreach ($rows as $row) {
        $conn->begin_transaction();
        try {
            endRegistrationAndFreeRoom(
                $conn,
                (string)$row['id'],
                (string)$row['room_id'],
                (string)$row['end_date']
            );
            $conn->commit();
        } catch (Exception $e) {
            $conn->rollback();
            error_log('Failed to expire scheduled registration ' . ($row['id'] ?? '') . ': ' . $e->getMessage());
        }
    }
}

function profilePayload(mysqli $conn, array $payload): array {
    $userId = $payload['sub'] ?? '';
    $base = [
        'id' => $userId,
        'email' => $payload['email'] ?? '',
        'displayName' => $payload['displayName'] ?? 'User',
        'role' => $payload['role'] ?? 'user',
        'photoUrl' => null,
        'kosName' => null,
        'kosAccessCode' => null,
        'roomNumber' => null,
        'roomType' => null,
        'activeUntil' => null,
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
        'activeUntil' => getActiveUntil($conn, $userId),
    ]);
}

$payload = JWT::getPayloadFromRequest();
if (!$payload) {
    sendJson(false, null, 'Unauthorized', 401);
}

$userId = $payload['sub'] ?? '';
if ($userId !== '') {
    expireScheduledEndDates($conn, $userId);
}

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    sendJson(true, profilePayload($conn, $payload), 'Profil berhasil dimuat');
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJson(false, null, 'Only GET or POST method allowed', 405);
}

$body = json_decode(file_get_contents('php://input'), true);
if (!is_array($body)) {
    sendJson(false, null, 'Invalid JSON request', 400);
}

$accessCode = strtoupper(trim($body['accessCode'] ?? ''));
$roomNumber = strtoupper(trim($body['roomNumber'] ?? ''));
$userId = $payload['sub'] ?? '';

if ($accessCode === '') {
    sendJson(false, null, 'Kode kos wajib diisi', 400);
}

if ($roomNumber === '') {
    sendJson(false, null, 'Kode unik kamar wajib diisi', 400);
}

if (!tableExists($conn, 'room_registrations') || !tableExists($conn, 'kos_rooms') || !tableExists($conn, 'kos_listings')) {
    sendJson(false, null, 'Tabel kos/kamar belum tersedia', 500);
}

$stmt = $conn->prepare("
        SELECT k.id AS kos_id, r.id AS room_id
        FROM kos_listings k
        JOIN kos_rooms r ON r.kos_id = k.id
        WHERE UPPER(k.access_code) = ?
          AND UPPER(r.room_number) = ?
          AND r.status = 'available'
        LIMIT 1
    ");
    if (!$stmt) {
        sendJson(false, null, 'Database error', 500);
    }
    $stmt->bind_param('ss', $accessCode, $roomNumber);

$stmt->execute();
$room = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$room) {
    if ($roomNumber !== '') {
        sendJson(false, null, 'Kode kos atau kode kamar tidak ditemukan / kamar tidak tersedia', 404);
    }
    sendJson(false, null, 'Kode kos tidak ditemukan atau belum memiliki kamar', 404);
}

$check = $conn->prepare("SELECT id FROM room_registrations WHERE user_id = ? AND status IN ('active', 'approved', 'pending') LIMIT 1");
$check->bind_param('s', $userId);
$check->execute();
$existing = $check->get_result()->fetch_assoc();
$check->close();

if ($existing) {
    $upd = $conn->prepare("UPDATE room_registrations SET kos_id = ?, room_id = ?, status = 'pending', start_date = NULL, updated_at = NOW() WHERE id = ?");
    $upd->bind_param('sss', $room['kos_id'], $room['room_id'], $existing['id']);
    $upd->execute();
    $upd->close();
} else {
    $id = uuid();
    $ins = $conn->prepare("
        INSERT INTO room_registrations
            (id, user_id, room_id, kos_id, status, start_date, registered_at, updated_at)
        VALUES (?, ?, ?, ?, 'pending', NULL, NOW(), NOW())
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
