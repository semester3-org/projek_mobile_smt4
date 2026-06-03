<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';

$payload = JWT::getPayloadFromRequest();
if (!$payload) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit();
}

$ownerId   = $payload['sub'];
$ownerRole = $payload['role'];

if ($ownerRole !== 'owner' && $ownerRole !== 'admin') {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Forbidden: hanya owner yang bisa akses']);
    exit();
}

$method = $_SERVER['REQUEST_METHOD'];
$kosId  = $_GET['kos_id'] ?? null;
$roomId = $_GET['id'] ?? null;

try {
    switch ($method) {
        case 'GET':
            handleGet($conn, $ownerId, $kosId, $roomId);
            break;
        case 'POST':
            handlePost($conn, $ownerId);
            break;
        case 'PUT':
            if (!$roomId) throw new Exception('Parameter id wajib diisi', 400);
            handlePut($conn, $ownerId, $roomId);
            break;
        case 'DELETE':
            if (!$roomId) throw new Exception('Parameter id wajib diisi', 400);
            handleDelete($conn, $ownerId, $roomId);
            break;
        default:
            throw new Exception('Method not allowed', 405);
    }
} catch (Exception $e) {
    http_response_code($e->getCode() ?: 500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}

function handleGet(mysqli $conn, string $ownerId, ?string $kosId, ?string $roomId): void {
    if (!$kosId) throw new Exception('Parameter kos_id wajib diisi', 400);

    validateKosOwnership($conn, $kosId, $ownerId);

    if ($roomId) {
        $history = $_GET['history'] ?? null;
        if ($history === 'tenants') {
            echo json_encode([
                'success' => true,
                'data' => getTenantHistory($conn, $kosId, $roomId),
            ]);
            return;
        }
        if ($history === 'payments') {
            echo json_encode([
                'success' => true,
                'data' => getPaymentHistory($conn, $kosId, $roomId),
            ]);
            return;
        }

        $stmt = $conn->prepare("
            SELECT r.*, k.title AS kos_title
            FROM kos_rooms r
            JOIN kos_listings k ON k.id = r.kos_id
            WHERE r.id = ? AND r.kos_id = ?
        ");
        $stmt->bind_param("ss", $roomId, $kosId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$row) throw new Exception('Kamar tidak ditemukan', 404);

        echo json_encode(['success' => true, 'data' => formatRoom($conn, $row)]);
        return;
    }

    $status = $_GET['status'] ?? null;
    $sql = "
        SELECT r.*, k.title AS kos_title
        FROM kos_rooms r
        JOIN kos_listings k ON k.id = r.kos_id
        WHERE r.kos_id = ?
    ";
    $params = [$kosId];
    $types  = 's';

    if ($status && in_array($status, ['available', 'occupied', 'maintenance'])) {
        $sql     .= " AND r.status = ?";
        $params[] = $status;
        $types   .= 's';
    }

    $sql .= " ORDER BY r.room_number ASC";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    echo json_encode([
        'success' => true,
        'data'    => array_map(fn($r) => formatRoom($conn, $r), $rows),
        'total'   => count($rows),
    ]);
}

function handlePost(mysqli $conn, string $ownerId): void {
    $body = getJsonBody();

    $kosId        = trim($body['kos_id'] ?? '');
    $roomNumber   = trim($body['room_number'] ?? '');
    $roomType     = trim($body['room_type'] ?? '');
    $price        = (int)($body['price_per_month'] ?? 0);
    $maxOccupant  = (int)($body['max_occupant'] ?? 1);
    $status       = $body['status'] ?? 'available';
    $rentalType   = $body['rental_type'] ?? 'monthly';
    $description  = trim($body['description'] ?? '');
    $facilityIds  = normalizeFacilityIds($body['facility_ids'] ?? []);

    if (empty($kosId) || empty($roomNumber) || empty($roomType) || $price <= 0) {
        throw new Exception('kos_id, room_number, room_type, dan price_per_month wajib diisi', 400);
    }
    if (!in_array($status, ['available', 'occupied', 'maintenance'])) {
        throw new Exception('Status tidak valid. Gunakan: available, occupied, maintenance', 400);
    }
    if ($status === 'occupied') {
        throw new Exception('Kamar baru belum bisa langsung berstatus terisi. Approve penyewa terlebih dahulu agar data penyewa terhubung.', 400);
    }
    if (!in_array($rentalType, ['daily', 'monthly', 'yearly'])) {
        throw new Exception('rental_type tidak valid. Gunakan: daily, monthly, yearly', 400);
    }

    validateKosOwnership($conn, $kosId, $ownerId);
    validateFacilityIds($conn, $facilityIds);

    $check = $conn->prepare("SELECT id FROM kos_rooms WHERE kos_id = ? AND room_number = ?");
    $check->bind_param("ss", $kosId, $roomNumber);
    $check->execute();
    if ($check->get_result()->num_rows > 0) {
        $check->close();
        throw new Exception("Nomor kamar '$roomNumber' sudah ada di kos ini", 409);
    }
    $check->close();

    $id   = generateUuid();
    $desc = $description ?: null;

    $stmt = $conn->prepare("
        INSERT INTO kos_rooms (id, kos_id, room_number, room_type, price_per_month, status, max_occupant, rental_type, description)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->bind_param("ssssisiss", $id, $kosId, $roomNumber, $roomType, $price, $status, $maxOccupant, $rentalType, $desc);
    $stmt->execute();
    $stmt->close();

    syncRoomFacilities($conn, $id, $facilityIds);

    $sel = $conn->prepare("
        SELECT r.*, k.title AS kos_title
        FROM kos_rooms r
        JOIN kos_listings k ON k.id = r.kos_id
        WHERE r.id = ?
        LIMIT 1
    ");
    $sel->bind_param("s", $id);
    $sel->execute();
    $row = $sel->get_result()->fetch_assoc();
    $sel->close();

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'message' => 'Kamar berhasil ditambahkan',
        'data'    => formatRoom($conn, $row),
    ]);
}

function handlePut(mysqli $conn, string $ownerId, string $roomId): void {
    $body = getJsonBody();

    $existing = $conn->query("
        SELECT r.*, k.owner_id
        FROM kos_rooms r
        JOIN kos_listings k ON k.id = r.kos_id
        WHERE r.id = '" . $conn->real_escape_string($roomId) . "'
    ")->fetch_assoc();

    if (!$existing) throw new Exception('Kamar tidak ditemukan', 404);
    if ($existing['owner_id'] !== $ownerId) throw new Exception('Forbidden', 403);
    if (($existing['status'] ?? '') === 'occupied' || hasStrictActiveTenant($conn, $roomId)) {
        throw new Exception('Kamar terisi hanya bisa diubah setelah data penyewa aktif selesai atau dikosongkan dari data penyewa.', 400);
    }

    $fields  = [];
    $values  = [];
    $types   = '';

    if (isset($body['room_number'])) {
        $roomNumber = trim($body['room_number']);
        $check = $conn->prepare("SELECT id FROM kos_rooms WHERE kos_id = ? AND room_number = ? AND id != ?");
        $check->bind_param("sss", $existing['kos_id'], $roomNumber, $roomId);
        $check->execute();
        if ($check->get_result()->num_rows > 0) {
            $check->close();
            throw new Exception("Nomor kamar '$roomNumber' sudah ada", 409);
        }
        $check->close();
        $fields[] = 'room_number = ?';
        $values[] = $roomNumber;
        $types   .= 's';
    }
    if (isset($body['room_type'])) {
        $fields[] = 'room_type = ?';
        $values[] = trim($body['room_type']);
        $types   .= 's';
    }
    if (isset($body['price_per_month'])) {
        $fields[] = 'price_per_month = ?';
        $values[] = (int)$body['price_per_month'];
        $types   .= 'i';
    }
    if (isset($body['max_occupant'])) {
        $fields[] = 'max_occupant = ?';
        $values[] = (int)$body['max_occupant'];
        $types   .= 'i';
    }
    if (isset($body['status'])) {
        if (!in_array($body['status'], ['available', 'occupied', 'maintenance'])) {
            throw new Exception('Status tidak valid', 400);
        }
        if ($body['status'] === 'occupied' && !hasStrictActiveTenant($conn, $roomId)) {
            throw new Exception('Status terisi membutuhkan penyewa aktif. Approve pengajuan penyewa terlebih dahulu.', 400);
        }
        $fields[] = 'status = ?';
        $values[] = $body['status'];
        $types   .= 's';
    }
    if (isset($body['rental_type'])) {
        if (!in_array($body['rental_type'], ['daily', 'monthly', 'yearly'])) {
            throw new Exception('rental_type tidak valid', 400);
        }
        $fields[] = 'rental_type = ?';
        $values[] = $body['rental_type'];
        $types   .= 's';
    }
    if (array_key_exists('description', $body)) {
        $fields[] = 'description = ?';
        $values[] = $body['description'] ?: null;
        $types   .= 's';
    }

    if (!empty($fields)) {
        $values[] = $roomId;
        $types   .= 's';
        $sql  = "UPDATE kos_rooms SET " . implode(', ', $fields) . " WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param($types, ...$values);
        $stmt->execute();
        $stmt->close();
    }

    if (array_key_exists('facility_ids', $body)) {
        $facilityIds = normalizeFacilityIds($body['facility_ids']);
        validateFacilityIds($conn, $facilityIds);
        syncRoomFacilities($conn, $roomId, $facilityIds);
    }

    if (empty($fields) && !array_key_exists('facility_ids', $body)) {
        throw new Exception('Tidak ada field yang diupdate', 400);
    }

    $sel = $conn->prepare("
        SELECT r.*, k.title AS kos_title
        FROM kos_rooms r
        JOIN kos_listings k ON k.id = r.kos_id
        WHERE r.id = ?
        LIMIT 1
    ");
    $sel->bind_param("s", $roomId);
    $sel->execute();
    $row = $sel->get_result()->fetch_assoc();
    $sel->close();

    echo json_encode([
        'success' => true,
        'message' => 'Kamar berhasil diperbarui',
        'data'    => formatRoom($conn, $row),
    ]);
}

function handleDelete(mysqli $conn, string $ownerId, string $roomId): void {
    $existing = $conn->query("
        SELECT r.id, r.status, k.owner_id
        FROM kos_rooms r
        JOIN kos_listings k ON k.id = r.kos_id
        WHERE r.id = '" . $conn->real_escape_string($roomId) . "'
    ")->fetch_assoc();

    if (!$existing) throw new Exception('Kamar tidak ditemukan', 404);
    if ($existing['owner_id'] !== $ownerId) throw new Exception('Forbidden', 403);
    if (($existing['status'] ?? '') === 'occupied' || hasStrictActiveTenant($conn, $roomId)) {
        throw new Exception('Kamar terisi tidak bisa dihapus karena masih memiliki penghuni aktif.', 400);
    }

    $stmt = $conn->prepare("DELETE FROM kos_rooms WHERE id = ?");
    $stmt->bind_param("s", $roomId);
    $stmt->execute();
    $stmt->close();

    echo json_encode(['success' => true, 'message' => 'Kamar berhasil dihapus']);
}

function validateKosOwnership(mysqli $conn, string $kosId, string $ownerId): void {
    $stmt = $conn->prepare("SELECT id FROM kos_listings WHERE id = ? AND owner_id = ?");
    $stmt->bind_param("ss", $kosId, $ownerId);
    $stmt->execute();
    $found = $stmt->get_result()->num_rows > 0;
    $stmt->close();
    if (!$found) throw new Exception('Kos tidak ditemukan atau bukan milik Anda', 403);
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

function getJsonBody(): array {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) throw new Exception('Invalid JSON request', 400);
    return $data;
}

function normalizeFacilityIds($raw): array {
    if (!is_array($raw)) return [];
    $ids = [];
    foreach ($raw as $id) {
        $n = (int)$id;
        if ($n > 0) $ids[] = $n;
    }
    return array_values(array_unique($ids));
}

function validateFacilityIds(mysqli $conn, array $facilityIds): void {
    if (empty($facilityIds)) return;
    $placeholders = implode(',', array_fill(0, count($facilityIds), '?'));
    $types = str_repeat('i', count($facilityIds));

    $stmt = $conn->prepare("SELECT COUNT(*) AS cnt FROM facilities WHERE id IN ($placeholders)");
    $stmt->bind_param($types, ...$facilityIds);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if ((int)$row['cnt'] !== count($facilityIds)) {
        throw new Exception('Ada facility_ids yang tidak valid', 400);
    }
}

function syncRoomFacilities(mysqli $conn, string $roomId, array $facilityIds): void {
    $del = $conn->prepare("DELETE FROM room_facilities WHERE room_id = ?");
    if (!$del) return;
    $del->bind_param("s", $roomId);
    $del->execute();
    $del->close();

    if (empty($facilityIds)) return;

    $ins = $conn->prepare("INSERT INTO room_facilities (room_id, facility_id) VALUES (?, ?)");
    foreach ($facilityIds as $facilityId) {
        $ins->bind_param("si", $roomId, $facilityId);
        $ins->execute();
    }
    $ins->close();
}

function getRoomFacilities(mysqli $conn, string $roomId): array {
    $stmt = $conn->prepare("
        SELECT f.id, f.name
        FROM room_facilities rf
        JOIN facilities f ON f.id = rf.facility_id
        WHERE rf.room_id = ?
        ORDER BY f.name ASC
    ");
    if (!$stmt) return [];
    $stmt->bind_param("s", $roomId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return array_map(
        fn($r) => ['id' => (int)$r['id'], 'name' => $r['name']],
        $rows
    );
}

function getActiveTenant(mysqli $conn, string $roomId, string $roomStatus = ''): ?array {
    $phoneSelect = columnExists($conn, 'users', 'phone') ? 'u.phone' : 'NULL AS phone';
    $stmt = $conn->prepare("
        SELECT
            rr.id AS registration_id,
            rr.user_id,
            rr.status,
            rr.start_date,
            rr.end_date,
            rr.registered_at,
            u.display_name,
            u.email,
            $phoneSelect
        FROM room_registrations rr
        INNER JOIN users u ON u.id = rr.user_id
        WHERE rr.room_id = ?
          AND rr.status IN ('approved', 'active')
          AND (rr.end_date IS NULL OR rr.end_date >= CURDATE())
        ORDER BY
          CASE WHEN rr.end_date IS NULL THEN 0 ELSE 1 END,
          rr.start_date DESC,
          rr.registered_at DESC
        LIMIT 1
    ");
    if (!$stmt) return null;
    $stmt->bind_param("s", $roomId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if ($row) return tenantSummaryPayload($row);

    if ($roomStatus !== 'occupied') return null;

    $fallbackStmt = $conn->prepare("
        SELECT
            rr.id AS registration_id,
            rr.user_id,
            rr.status,
            rr.start_date,
            rr.end_date,
            rr.registered_at,
            u.display_name,
            u.email,
            $phoneSelect
        FROM room_registrations rr
        INNER JOIN users u ON u.id = rr.user_id
        WHERE rr.room_id = ?
          AND rr.status NOT IN ('rejected', 'cancelled')
        ORDER BY
          CASE WHEN rr.status IN ('approved', 'active') THEN 0 ELSE 1 END,
          rr.start_date DESC,
          rr.registered_at DESC
        LIMIT 1
    ");
    if (!$fallbackStmt) return null;
    $fallbackStmt->bind_param("s", $roomId);
    $fallbackStmt->execute();
    $fallback = $fallbackStmt->get_result()->fetch_assoc();
    $fallbackStmt->close();

    return $fallback ? tenantSummaryPayload($fallback) : null;
}

function hasStrictActiveTenant(mysqli $conn, string $roomId): bool {
    $stmt = $conn->prepare("
        SELECT COUNT(*) AS total
        FROM room_registrations
        WHERE room_id = ?
          AND status IN ('approved', 'active')
          AND (end_date IS NULL OR end_date >= CURDATE())
    ");
    if (!$stmt) return false;
    $stmt->bind_param("s", $roomId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return (int)($row['total'] ?? 0) > 0;
}

function getTenantHistory(mysqli $conn, string $kosId, string $roomId): array {
    $hasPhone = columnExists($conn, 'users', 'phone');
    $phoneSelect = $hasPhone ? 'u.phone' : 'NULL AS phone';
    $phoneGroup = $hasPhone ? 'u.phone' : 'NULL';
    $stmt = $conn->prepare("
        SELECT
            rr.id AS registration_id,
            rr.user_id,
            rr.status,
            rr.start_date,
            rr.end_date,
            rr.registered_at,
            rr.reject_reason,
            u.display_name,
            u.email,
            $phoneSelect,
            COUNT(ph.id) AS payment_count,
            SUM(CASE WHEN ph.payment_status = 'paid' THEN ph.amount ELSE 0 END) AS total_paid
        FROM room_registrations rr
        INNER JOIN users u ON u.id = rr.user_id
        LEFT JOIN payment_history ph ON ph.registration_id = rr.id
        WHERE rr.kos_id = ? AND rr.room_id = ?
        GROUP BY
            rr.id, rr.user_id, rr.status, rr.start_date, rr.end_date,
            rr.registered_at, rr.reject_reason, u.display_name, u.email, $phoneGroup
        ORDER BY
            CASE WHEN rr.status IN ('approved', 'active') AND (rr.end_date IS NULL OR rr.end_date >= CURDATE()) THEN 0 ELSE 1 END,
            rr.registered_at DESC
    ");
    if (!$stmt) return [];
    $stmt->bind_param("ss", $kosId, $roomId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return array_map('tenantHistoryPayload', $rows);
}

function getPaymentHistory(mysqli $conn, string $kosId, string $roomId): array {
    $stmt = $conn->prepare("
        SELECT
            ph.id,
            ph.registration_id,
            ph.amount,
            ph.period_month,
            ph.payment_status,
            ph.payment_method,
            ph.proof_url,
            ph.paid_at,
            ph.created_at,
            rr.status AS registration_status,
            u.display_name,
            u.email
        FROM payment_history ph
        INNER JOIN room_registrations rr ON rr.id = ph.registration_id
        INNER JOIN users u ON u.id = rr.user_id
        WHERE rr.kos_id = ? AND rr.room_id = ?
        ORDER BY ph.created_at DESC, ph.id DESC
    ");
    if (!$stmt) return [];
    $stmt->bind_param("ss", $kosId, $roomId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return array_map('paymentHistoryPayload', $rows);
}

function tenantSummaryPayload(array $row): array {
    return [
        'registrationId' => (string)$row['registration_id'],
        'userId' => (string)$row['user_id'],
        'name' => $row['display_name'] ?? 'User',
        'email' => $row['email'] ?? '',
        'phone' => $row['phone'] ?? '',
        'status' => $row['status'] ?? '',
        'startDate' => $row['start_date'] ?? null,
        'endDate' => $row['end_date'] ?? null,
        'registeredAt' => $row['registered_at'] ?? null,
    ];
}

function tenantHistoryPayload(array $row): array {
    return array_merge(tenantSummaryPayload($row), [
        'rejectReason' => $row['reject_reason'] ?? null,
        'paymentCount' => (int)($row['payment_count'] ?? 0),
        'totalPaid' => (int)($row['total_paid'] ?? 0),
    ]);
}

function paymentHistoryPayload(array $row): array {
    return [
        'id' => (int)$row['id'],
        'registrationId' => (string)$row['registration_id'],
        'tenantName' => $row['display_name'] ?? 'User',
        'tenantEmail' => $row['email'] ?? '',
        'amount' => (int)($row['amount'] ?? 0),
        'periodMonth' => $row['period_month'] ?? '',
        'paymentStatus' => $row['payment_status'] ?? '',
        'paymentMethod' => $row['payment_method'] ?? '',
        'proofUrl' => $row['proof_url'] ?? null,
        'paidAt' => $row['paid_at'] ?? null,
        'createdAt' => $row['created_at'] ?? null,
        'registrationStatus' => $row['registration_status'] ?? '',
    ];
}

function formatRoom(mysqli $conn, array $row): array {
    $activeTenant = getActiveTenant($conn, $row['id'], $row['status'] ?? '');

    return [
        'id'            => $row['id'],
        'kosId'         => $row['kos_id'],
        'kosTitle'      => $row['kos_title'] ?? '',
        'roomNumber'    => $row['room_number'],
        'roomType'      => $row['room_type'],
        'pricePerMonth' => (int)$row['price_per_month'],
        'status'        => $row['status'],
        'maxOccupant'   => (int)$row['max_occupant'],
        'rental_type'   => $row['rental_type'] ?? 'monthly',
        'facilities'    => getRoomFacilities($conn, $row['id']),
        'activeTenant'  => $activeTenant,
        'tenantDataStatus' => $activeTenant
            ? 'linked'
            : (($row['status'] ?? '') === 'occupied' ? 'missing_registration' : 'none'),
        'description'   => $row['description'],
        'createdAt'     => $row['created_at'],
        'updatedAt'     => $row['updated_at'],
    ];
}

function generateUuid(): string {
    return sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}
?>
