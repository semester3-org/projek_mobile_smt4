<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Session-Id');

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

function columnExists(mysqli $conn, string $table, string $column): bool {
    $stmt = $conn->prepare(
        'SELECT COUNT(*) AS total FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?'
    );
    if (!$stmt) return false;
    $stmt->bind_param('ss', $table, $column);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return (int)($row['total'] ?? 0) > 0;
}

function ensureUserProfileColumns(mysqli $conn): void {
    if (!tableExists($conn, 'users')) return;

    $columns = [
        'phone' => "ALTER TABLE users ADD COLUMN phone varchar(25) DEFAULT NULL AFTER display_name",
        'address' => "ALTER TABLE users ADD COLUMN address text DEFAULT NULL AFTER phone",
        'latitude' => "ALTER TABLE users ADD COLUMN latitude decimal(10,8) DEFAULT NULL AFTER address",
        'longitude' => "ALTER TABLE users ADD COLUMN longitude decimal(11,8) DEFAULT NULL AFTER latitude",
        'photo_url' => "ALTER TABLE users ADD COLUMN photo_url longtext DEFAULT NULL AFTER longitude",
    ];

    foreach ($columns as $column => $sql) {
        if (!columnExists($conn, 'users', $column)) {
            if (!$conn->query($sql)) {
                throw new Exception('Gagal menyiapkan kolom profil: ' . $conn->error);
            }
        }
    }

    $conn->query('ALTER TABLE users MODIFY address text DEFAULT NULL');
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
        ORDER BY
            CASE WHEN rr.end_date IS NULL THEN 0 ELSE 1 END,
            rr.registered_at DESC
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

    $startDate = $row['start_date'] ?? null;
    $base = $startDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $startDate)
        ? new DateTime($startDate)
        : new DateTime(date('Y-m-d'));

    return addRentalPeriods(
        $base,
        $row['rental_type'] ?? 'monthly',
        $paidPeriods
    )->format('Y-m-d');
}

function activeRentHistory(mysqli $conn, string $userId): array {
    if (!tableExists($conn, 'room_registrations') ||
        !tableExists($conn, 'kos_rooms') ||
        !tableExists($conn, 'kos_listings')) {
        return [];
    }

    $hasPayments = tableExists($conn, 'payment_history');
    $stmt = $conn->prepare("
        SELECT
            rr.id AS registration_id,
            rr.start_date,
            rr.end_date,
            rr.registered_at,
            rr.status,
            k.title AS kos_name,
            k.access_code,
            r.room_number,
            r.room_type,
            r.rental_type,
            " . ($hasPayments ? "COUNT(ph.id)" : "0") . " AS paid_periods
        FROM room_registrations rr
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        " . ($hasPayments ? "LEFT JOIN payment_history ph
            ON ph.registration_id = rr.id
            AND ph.payment_status = 'paid'" : "") . "
        WHERE rr.user_id = ?
          AND rr.status IN ('active', 'approved', 'pending', 'cancelled')
        GROUP BY
            rr.id, rr.start_date, rr.end_date, rr.registered_at, rr.status,
            k.title, k.access_code, r.room_number, r.room_type, r.rental_type
        ORDER BY rr.registered_at DESC
        LIMIT 10
    ");
    if (!$stmt) return [];
    $stmt->bind_param('s', $userId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $items = [];
    $today = date('Y-m-d');
    foreach ($rows as $row) {
        $paidPeriods = (int)($row['paid_periods'] ?? 0);
        $activeUntil = $paidPeriods > 0
            ? addRentalPeriods(
                $row['start_date'] && preg_match('/^\d{4}-\d{2}-\d{2}$/', $row['start_date'])
                ? new DateTime($row['start_date'])
                : new DateTime(date('Y-m-d')),
                $row['rental_type'] ?? 'monthly',
                $paidPeriods
            )->format('Y-m-d')
            : null;

        if (($row['status'] ?? '') !== 'pending' &&
            $activeUntil === null &&
            empty($row['end_date'])) {
            continue;
        }

        if (($row['status'] ?? '') === 'cancelled' &&
            $activeUntil !== null &&
            $activeUntil < $today) {
            continue;
        }

        $items[] = [
            'registrationId' => $row['registration_id'],
            'kosName' => $row['kos_name'],
            'kosAccessCode' => $row['access_code'],
            'roomNumber' => $row['room_number'],
            'roomType' => $row['room_type'],
            'rentalType' => $row['rental_type'],
            'startDate' => $row['start_date'],
            'endDate' => $row['end_date'],
            'activeUntil' => $activeUntil,
            'paidPeriods' => $paidPeriods,
            'status' => $row['status'],
        ];
    }

    return $items;
}

function currentActiveRegistration(mysqli $conn, string $userId): ?array {
    if (!tableExists($conn, 'room_registrations') ||
        !tableExists($conn, 'kos_rooms') ||
        !tableExists($conn, 'kos_listings')) {
        return null;
    }

    $stmt = $conn->prepare("
        SELECT
            rr.id,
            rr.room_id,
            rr.kos_id,
            rr.status,
            rr.start_date,
            rr.end_date,
            k.access_code,
            r.room_number,
            r.rental_type
        FROM room_registrations rr
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        WHERE rr.user_id = ?
          AND rr.status IN ('active', 'approved', 'pending')
        ORDER BY
            CASE WHEN rr.status IN ('active', 'approved') THEN 0 ELSE 1 END,
            CASE WHEN rr.end_date IS NULL THEN 0 ELSE 1 END,
            rr.registered_at DESC
        LIMIT 1
    ");
    if (!$stmt) return null;
    $stmt->bind_param('s', $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

function activeRentSlotCount(mysqli $conn, string $userId): int {
    if (!tableExists($conn, 'room_registrations') ||
        !tableExists($conn, 'kos_rooms')) {
        return 0;
    }

    $hasPayments = tableExists($conn, 'payment_history');
    $stmt = $conn->prepare("
        SELECT
            rr.id,
            rr.status,
            rr.start_date,
            r.rental_type,
            " . ($hasPayments ? "COUNT(ph.id)" : "0") . " AS paid_periods
        FROM room_registrations rr
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        " . ($hasPayments ? "LEFT JOIN payment_history ph
            ON ph.registration_id = rr.id
            AND ph.payment_status = 'paid'" : "") . "
        WHERE rr.user_id = ?
          AND rr.status IN ('active', 'approved', 'pending')
        GROUP BY rr.id, rr.status, rr.start_date, r.rental_type
    ");
    if (!$stmt) return 0;
    $stmt->bind_param('s', $userId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $today = date('Y-m-d');
    $total = 0;
    foreach ($rows as $row) {
        if (($row['status'] ?? '') === 'pending') {
            $total++;
            continue;
        }

        $paidPeriods = (int)($row['paid_periods'] ?? 0);
        if ($paidPeriods <= 0) {
            continue;
        }

        $startDate = $row['start_date'] ?? null;
        $activeUntil = addRentalPeriods(
            $startDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $startDate)
                ? new DateTime($startDate)
                : new DateTime(date('Y-m-d')),
            $row['rental_type'] ?? 'monthly',
            $paidPeriods
        )->format('Y-m-d');

        if ($activeUntil >= $today) {
            $total++;
        }
    }

    return $total;
}

function activeUntilForRegistrationRow(array $row): ?string {
    $paidPeriods = (int)($row['paid_periods'] ?? 0);
    if ($paidPeriods <= 0) {
        return null;
    }

    $startDate = $row['start_date'] ?? null;
    return addRentalPeriods(
        $startDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $startDate)
            ? new DateTime($startDate)
            : new DateTime(date('Y-m-d')),
        $row['rental_type'] ?? 'monthly',
        $paidPeriods
    )->format('Y-m-d');
}

function roomHeldByOtherUser(mysqli $conn, string $roomId, string $userId): bool {
    if (!tableExists($conn, 'room_registrations') ||
        !tableExists($conn, 'kos_rooms')) {
        return false;
    }

    $hasPayments = tableExists($conn, 'payment_history');
    $stmt = $conn->prepare("
        SELECT
            rr.id,
            rr.status,
            rr.start_date,
            rr.end_date,
            r.rental_type,
            " . ($hasPayments ? "COUNT(ph.id)" : "0") . " AS paid_periods
        FROM room_registrations rr
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        " . ($hasPayments ? "LEFT JOIN payment_history ph
            ON ph.registration_id = rr.id
            AND ph.payment_status = 'paid'" : "") . "
        WHERE rr.room_id = ?
          AND rr.user_id <> ?
          AND rr.status IN ('active', 'approved', 'pending', 'cancelled')
        GROUP BY rr.id, rr.status, rr.start_date, rr.end_date, r.rental_type
    ");
    if (!$stmt) return false;
    $stmt->bind_param('ss', $roomId, $userId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $today = date('Y-m-d');
    foreach ($rows as $row) {
        if (($row['status'] ?? '') === 'pending') {
            return true;
        }

        $activeUntil = activeUntilForRegistrationRow($row);
        if ($activeUntil !== null && $activeUntil >= $today) {
            return true;
        }

        $endDate = $row['end_date'] ?? null;
        if ($endDate !== null && $endDate !== '' && $endDate >= $today) {
            return true;
        }
    }

    return false;
}

function activeRegistrationForTargetRoom(mysqli $conn, string $userId, string $roomId): ?array {
    if (!tableExists($conn, 'room_registrations') ||
        !tableExists($conn, 'kos_rooms')) {
        return null;
    }

    $hasPayments = tableExists($conn, 'payment_history');
    $stmt = $conn->prepare("
        SELECT
            rr.id,
            rr.room_id,
            rr.kos_id,
            rr.status,
            rr.start_date,
            rr.end_date,
            r.rental_type,
            " . ($hasPayments ? "COUNT(ph.id)" : "0") . " AS paid_periods
        FROM room_registrations rr
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        " . ($hasPayments ? "LEFT JOIN payment_history ph
            ON ph.registration_id = rr.id
            AND ph.payment_status = 'paid'" : "") . "
        WHERE rr.user_id = ?
          AND rr.room_id = ?
          AND rr.status IN ('active', 'approved')
        GROUP BY rr.id, rr.room_id, rr.kos_id, rr.status, rr.start_date, rr.end_date, r.rental_type
        ORDER BY
            CASE WHEN rr.end_date IS NULL AND rr.status IN ('active', 'approved') THEN 0 ELSE 1 END,
            rr.registered_at DESC
        LIMIT 1
    ");
    if (!$stmt) return null;
    $stmt->bind_param('ss', $userId, $roomId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) return null;
    $activeUntil = activeUntilForRegistrationRow($row);
    return $activeUntil !== null && $activeUntil >= date('Y-m-d')
        ? array_merge($row, ['active_until' => $activeUntil])
        : null;
}

function cancelOpenBillsForRegistration(mysqli $conn, string $registrationId): void {
    if (!tableExists($conn, 'payment_history')) return;
    $stmt = $conn->prepare("
        UPDATE payment_history
        SET payment_status = 'cancelled',
            payment_method = NULL,
            paid_at = NULL
        WHERE registration_id = ?
          AND payment_status NOT IN ('paid', 'cancelled')
    ");
    if (!$stmt) {
        throw new Exception($conn->error);
    }
    $stmt->bind_param('s', $registrationId);
    if (!$stmt->execute()) {
        $error = $stmt->error ?: 'Gagal memperbarui profil';
        $stmt->close();
        sendJson(false, null, 'Database error: ' . $error, 500);
    }
    $stmt->close();
}

function cancelPendingRegistrationsForRoom(mysqli $conn, string $userId, string $roomId, ?string $exceptRegistrationId = null): void {
    $sql = "
        UPDATE room_registrations
        SET status = 'cancelled', end_date = CURDATE(), updated_at = NOW()
        WHERE user_id = ?
          AND room_id = ?
          AND status = 'pending'
    ";
    if ($exceptRegistrationId !== null && $exceptRegistrationId !== '') {
        $sql .= " AND id <> ?";
    }

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception($conn->error);
    }
    if ($exceptRegistrationId !== null && $exceptRegistrationId !== '') {
        $stmt->bind_param('sss', $userId, $roomId, $exceptRegistrationId);
    } else {
        $stmt->bind_param('ss', $userId, $roomId);
    }
    $stmt->execute();
    $stmt->close();
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
        'phone' => null,
        'address' => null,
        'latitude' => null,
        'longitude' => null,
        'role' => $payload['role'] ?? 'user',
        'photoUrl' => $payload['photoUrl'] ?? null,
        'kosName' => null,
        'kosAccessCode' => null,
        'roomNumber' => null,
        'roomType' => null,
        'activeUntil' => null,
        'activeRentHistory' => [],
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
            u.phone,
            u.address,
            u.latitude,
            u.longitude,
            u.photo_url,
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
        ORDER BY
            CASE WHEN rr.end_date IS NULL AND rr.status IN ('active', 'approved') THEN 0 ELSE 1 END,
            rr.registered_at DESC
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
        'phone' => $row['phone'] ?? null,
        'address' => $row['address'] ?? null,
        'latitude' => $row['latitude'] !== null ? (float)$row['latitude'] : null,
        'longitude' => $row['longitude'] !== null ? (float)$row['longitude'] : null,
        'role' => $row['role'] ?? $base['role'],
        'photoUrl' => $row['photo_url'] ?? null,
        'kosName' => $row['kos_name'] ?? null,
        'kosAccessCode' => $row['access_code'] ?? null,
        'roomNumber' => $row['room_number'] ?? null,
        'roomType' => $row['room_type'] ?? null,
        'activeUntil' => getActiveUntil($conn, $userId),
        'activeRentHistory' => activeRentHistory($conn, $userId),
    ]);
}

$payload = JWT::getPayloadFromRequest();
if (!$payload) {
    sendJson(false, null, 'Unauthorized', 401);
}

$userId = $payload['sub'] ?? '';
try {
    ensureUserProfileColumns($conn);
} catch (Exception $e) {
    sendJson(false, null, $e->getMessage(), 500);
}

if ($userId !== '') {
    expireScheduledEndDates($conn, $userId);
}

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    sendJson(true, profilePayload($conn, $payload), 'Profil berhasil dimuat');
}

$body = json_decode(file_get_contents('php://input'), true);
if (!is_array($body)) {
    sendJson(false, null, 'Invalid JSON request', 400);
}

$accessCode = strtoupper(trim($body['accessCode'] ?? ''));
$roomNumber = strtoupper(trim($body['roomNumber'] ?? ''));
$userId = $payload['sub'] ?? '';

if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $displayName = trim($body['displayName'] ?? '');
    $phone = trim($body['phone'] ?? '');
    $address = trim($body['address'] ?? '');
    $latitude = isset($body['latitude']) && $body['latitude'] !== null && $body['latitude'] !== ''
        ? (float)$body['latitude']
        : null;
    $longitude = isset($body['longitude']) && $body['longitude'] !== null && $body['longitude'] !== ''
        ? (float)$body['longitude']
        : null;
    $photoUrl = trim($body['photoUrl'] ?? '');

    if ($displayName === '') {
        sendJson(false, null, 'Nama wajib diisi', 400);
    }

    if (!tableExists($conn, 'users')) {
        sendJson(false, null, 'Tabel users belum tersedia', 500);
    }

    $stmt = $conn->prepare('
        UPDATE users
        SET display_name = ?,
            phone = NULLIF(?, \'\'),
            address = NULLIF(?, \'\'),
            latitude = ?,
            longitude = ?,
            photo_url = NULLIF(?, \'\'),
            updated_at = NOW()
        WHERE id = ?
    ');
    if (!$stmt) {
        sendJson(false, null, 'Database error', 500);
    }
    $stmt->bind_param(
        'sssddss',
        $displayName,
        $phone,
        $address,
        $latitude,
        $longitude,
        $photoUrl,
        $userId
    );
    $stmt->execute();
    $stmt->close();

    $updatedPayload = array_merge($payload, [
        'displayName' => $displayName,
    ]);
    $data = profilePayload($conn, $updatedPayload);

    sendJson(true, $data, 'Profil berhasil diperbarui');
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJson(false, null, 'Only GET, POST, or PUT method allowed', 405);
}

$accessCode = strtoupper(trim($body['accessCode'] ?? ''));
$confirmStopPreviousRent = !empty($body['confirmStopPreviousRent']);

if ($accessCode === '') {
    sendJson(false, null, 'Kode kos wajib diisi', 400);
}

if ($roomNumber === '') {
    sendJson(false, null, 'Kode unik kamar wajib diisi', 400);
}

if (!tableExists($conn, 'room_registrations') || !tableExists($conn, 'kos_rooms') || !tableExists($conn, 'kos_listings')) {
    sendJson(false, null, 'Tabel kos/kamar belum tersedia', 500);
}

$currentRegistration = currentActiveRegistration($conn, $userId);
if ($currentRegistration &&
    strtoupper((string)$currentRegistration['access_code']) === $accessCode &&
    strtoupper((string)$currentRegistration['room_number']) === $roomNumber) {
    sendJson(true, profilePayload($conn, $payload), 'Kode kos dan kamar sudah tersambung');
}

$isChangingCurrentRoom = $currentRegistration &&
    (strtoupper((string)$currentRegistration['access_code']) !== $accessCode ||
        strtoupper((string)$currentRegistration['room_number']) !== $roomNumber);
$isMovingRoom = $currentRegistration &&
    in_array($currentRegistration['status'], ['active', 'approved'], true);

if ($currentRegistration && in_array($currentRegistration['status'], ['active', 'approved'], true)) {
    $currentActiveUntil = getActiveUntil($conn, $userId);
    $today = date('Y-m-d');

    if ($currentActiveUntil !== null && $currentActiveUntil <= $today) {
        $conn->begin_transaction();
        try {
            cancelOpenBillsForRegistration($conn, (string)$currentRegistration['id']);
            endRegistrationAndFreeRoom(
                $conn,
                (string)$currentRegistration['id'],
                (string)$currentRegistration['room_id'],
                $currentActiveUntil
            );
            $conn->commit();
            $currentRegistration = null;
            $paidPeriods = 0;
        } catch (Exception $e) {
            $conn->rollback();
            sendJson(false, null, 'Gagal mengakhiri masa sewa sebelumnya', 500);
        }
    } elseif (!$confirmStopPreviousRent) {
        sendJson(false, [
            'requiresStopPreviousRentConfirmation' => true,
            'activeUntil' => $currentActiveUntil,
        ], 'Konfirmasi bahwa sewa kamar sebelumnya tidak akan diperpanjang diperlukan', 409);
    }
}

$stmt = $conn->prepare("
        SELECT
            k.id AS kos_id,
            r.id AS room_id,
            r.status AS room_status
        FROM kos_listings k
        JOIN kos_rooms r ON r.kos_id = k.id
        WHERE UPPER(k.access_code) = ?
          AND UPPER(r.room_number) = ?
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

if (roomHeldByOtherUser($conn, (string)$room['room_id'], $userId)) {
    sendJson(false, null, 'Kamar masih memiliki masa sewa aktif atau pengajuan dari penghuni lain', 409);
}

$ownedActiveTarget = activeRegistrationForTargetRoom($conn, $userId, (string)$room['room_id']);
if ($ownedActiveTarget !== null) {
    if ($currentRegistration &&
        (string)$currentRegistration['id'] !== (string)$ownedActiveTarget['id'] &&
        in_array($currentRegistration['status'], ['active', 'approved'], true)) {
        $activeUntil = getActiveUntil($conn, $userId);
        $conn->begin_transaction();
        try {
            cancelOpenBillsForRegistration($conn, (string)$currentRegistration['id']);
            if ($activeUntil !== null && $activeUntil > date('Y-m-d')) {
                $scheduleEnd = $conn->prepare("
                    UPDATE room_registrations
                    SET end_date = ?, updated_at = NOW()
                    WHERE id = ? AND status IN ('active', 'approved')
                ");
                if (!$scheduleEnd) {
                    throw new Exception($conn->error);
                }
                $scheduleEnd->bind_param('ss', $activeUntil, $currentRegistration['id']);
                $scheduleEnd->execute();
                $scheduleEnd->close();
            }
            cancelPendingRegistrationsForRoom(
                $conn,
                $userId,
                (string)$room['room_id'],
                (string)$ownedActiveTarget['id']
            );
            $restoreTarget = $conn->prepare("
                UPDATE room_registrations
                SET end_date = NULL, updated_at = NOW()
                WHERE id = ? AND user_id = ? AND status IN ('active', 'approved')
            ");
            if (!$restoreTarget) {
                throw new Exception($conn->error);
            }
            $restoreTarget->bind_param('ss', $ownedActiveTarget['id'], $userId);
            $restoreTarget->execute();
            $restoreTarget->close();
            $conn->commit();
        } catch (Exception $e) {
            $conn->rollback();
            sendJson(false, null, 'Gagal kembali ke kamar lama', 500);
        }
    } else {
        $conn->begin_transaction();
        try {
            cancelPendingRegistrationsForRoom(
                $conn,
                $userId,
                (string)$room['room_id'],
                (string)$ownedActiveTarget['id']
            );
            $restoreTarget = $conn->prepare("
                UPDATE room_registrations
                SET end_date = NULL, updated_at = NOW()
                WHERE id = ? AND user_id = ? AND status IN ('active', 'approved')
            ");
            if (!$restoreTarget) {
                throw new Exception($conn->error);
            }
            $restoreTarget->bind_param('ss', $ownedActiveTarget['id'], $userId);
            $restoreTarget->execute();
            $restoreTarget->close();
            $conn->commit();
        } catch (Exception $e) {
            $conn->rollback();
            sendJson(false, null, 'Gagal membersihkan pengajuan kamar lama', 500);
        }
    }

    sendJson(true, profilePayload($conn, $payload), 'Kamar ini masih memiliki masa sewa aktif Anda');
}

if ($isChangingCurrentRoom && activeRentSlotCount($conn, $userId) >= 3) {
    sendJson(false, [
        'activeRentLimitReached' => true,
        'maxActiveRents' => 3,
    ], 'Masa sewa aktif sudah mencapai batas maksimal 3 kos/kamar. Tunggu salah satu masa sewa selesai sebelum pindah lagi.', 400);
}

$check = $conn->prepare("SELECT id FROM room_registrations WHERE user_id = ? AND status IN ('active', 'approved', 'pending') LIMIT 1");
$check->bind_param('s', $userId);
$check->execute();
$existing = $check->get_result()->fetch_assoc();
$check->close();

if ($currentRegistration && in_array($currentRegistration['status'], ['active', 'approved'], true)) {
    $activeUntil = getActiveUntil($conn, $userId);
    $conn->begin_transaction();
    try {
        cancelOpenBillsForRegistration($conn, (string)$currentRegistration['id']);
        if ($activeUntil !== null && $activeUntil > date('Y-m-d')) {
            $scheduleEnd = $conn->prepare("
                UPDATE room_registrations
                SET end_date = ?, updated_at = NOW()
                WHERE id = ? AND status IN ('active', 'approved')
            ");
            if (!$scheduleEnd) {
                throw new Exception($conn->error);
            }
            $scheduleEnd->bind_param('ss', $activeUntil, $currentRegistration['id']);
            $scheduleEnd->execute();
            $scheduleEnd->close();
        } else {
            endRegistrationAndFreeRoom(
                $conn,
                (string)$currentRegistration['id'],
                (string)$currentRegistration['room_id'],
                date('Y-m-d')
            );
        }

        $id = uuid();
        $ins = $conn->prepare("
            INSERT INTO room_registrations
                (id, user_id, room_id, kos_id, status, start_date, registered_at, updated_at)
            VALUES (?, ?, ?, ?, 'pending', NULL, NOW(), NOW())
        ");
        if (!$ins) {
            throw new Exception($conn->error);
        }
        $ins->bind_param('ssss', $id, $userId, $room['room_id'], $room['kos_id']);
        $ins->execute();
        $ins->close();

        $mark = $conn->prepare("UPDATE kos_rooms SET status = 'occupied' WHERE id = ?");
        if (!$mark) {
            throw new Exception($conn->error);
        }
        $mark->bind_param('s', $room['room_id']);
        $mark->execute();
        $mark->close();

        $conn->commit();
    } catch (Exception $e) {
        $conn->rollback();
        sendJson(false, null, 'Gagal mengajukan perpindahan kamar/kos', 500);
    }
} elseif ($existing) {
    $upd = $conn->prepare("UPDATE room_registrations SET kos_id = ?, room_id = ?, status = 'pending', start_date = NULL, updated_at = NOW() WHERE id = ?");
    $upd->bind_param('sss', $room['kos_id'], $room['room_id'], $existing['id']);
    $upd->execute();
    $upd->close();

    $mark = $conn->prepare("UPDATE kos_rooms SET status = 'occupied' WHERE id = ?");
    $mark->bind_param('s', $room['room_id']);
    $mark->execute();
    $mark->close();
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

    $mark = $conn->prepare("UPDATE kos_rooms SET status = 'occupied' WHERE id = ?");
    $mark->bind_param('s', $room['room_id']);
    $mark->execute();
    $mark->close();
}

sendJson(true, profilePayload($conn, $payload), 'Pengajuan kamar berhasil dikirim dan menunggu persetujuan owner');
?>
