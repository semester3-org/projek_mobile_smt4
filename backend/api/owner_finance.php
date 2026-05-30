<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, PUT, OPTIONS');
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

$payload = JWT::getPayloadFromRequest();
if (!$payload) {
    sendJson(false, null, 'Unauthorized', 401);
}

$ownerId = $payload['sub'] ?? '';
$role = $payload['role'] ?? '';
if (!in_array($role, ['owner', 'admin'], true)) {
    sendJson(false, null, 'Forbidden: hanya owner yang bisa akses', 403);
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'PUT') {
    handlePut($conn, $ownerId);
} else if ($method === 'GET') {
    handleGet($conn, $ownerId);
} else {
    sendJson(false, null, 'Method not allowed', 405);
}

function handleGet(mysqli $conn, string $ownerId): void {
    // 1. Total Pendapatan Lunas (paid)
    $totalStmt = $conn->prepare("
        SELECT SUM(ph.amount) as total_paid
        FROM payment_history ph
        INNER JOIN room_registrations rr ON rr.id = ph.registration_id
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        WHERE k.owner_id = ? AND ph.payment_status = 'paid'
    ");
    $totalStmt->bind_param('s', $ownerId);
    $totalStmt->execute();
    $totalRes = $totalStmt->get_result()->fetch_assoc();
    $totalStmt->close();
    
    $totalPaid = (int)($totalRes['total_paid'] ?? 0);

    // 2. Penghitungan Jumlah Transaksi per Status
    $statusStmt = $conn->prepare("
        SELECT 
            SUM(CASE WHEN ph.payment_status = 'paid' THEN 1 ELSE 0 END) as paid_count,
            SUM(CASE WHEN ph.payment_status = 'unpaid' THEN 1 ELSE 0 END) as unpaid_count,
            SUM(CASE WHEN ph.payment_status = 'overdue' THEN 1 ELSE 0 END) as overdue_count
        FROM payment_history ph
        INNER JOIN room_registrations rr ON rr.id = ph.registration_id
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        WHERE k.owner_id = ?
    ");
    $statusStmt->bind_param('s', $ownerId);
    $statusStmt->execute();
    $statusRes = $statusStmt->get_result()->fetch_assoc();
    $statusStmt->close();

    $paidCount = (int)($statusRes['paid_count'] ?? 0);
    $unpaidCount = (int)($statusRes['unpaid_count'] ?? 0);
    $overdueCount = (int)($statusRes['overdue_count'] ?? 0);

    // 3. Efisiensi Hunian (Occupancy Rate)
    $occStmt = $conn->prepare("
        SELECT 
            COUNT(r.id) as total_rooms,
            SUM(CASE WHEN r.status = 'occupied' THEN 1 ELSE 0 END) as occupied_rooms
        FROM kos_rooms r
        INNER JOIN kos_listings k ON k.id = r.kos_id
        WHERE k.owner_id = ?
    ");
    $occStmt->bind_param('s', $ownerId);
    $occStmt->execute();
    $occRes = $occStmt->get_result()->fetch_assoc();
    $occStmt->close();

    $totalRooms = (int)($occRes['total_rooms'] ?? 0);
    $occupiedRooms = (int)($occRes['occupied_rooms'] ?? 0);
    $efficiencyPercent = $totalRooms > 0 ? (int)(($occupiedRooms / $totalRooms) * 100) : 0;

    // 4. Data Chart
    // a. Harian (7 hari terakhir)
    $daily = [];
    for ($i = 6; $i >= 0; $i--) {
        $date = date('Y-m-d', strtotime("-$i days"));
        $dayLabel = date('D', strtotime($date));
        
        $chartStmt = $conn->prepare("
            SELECT SUM(ph.amount) as amt
            FROM payment_history ph
            INNER JOIN room_registrations rr ON rr.id = ph.registration_id
            INNER JOIN kos_listings k ON k.id = rr.kos_id
            WHERE k.owner_id = ? AND ph.payment_status = 'paid' AND DATE(ph.paid_at) = ?
        ");
        $chartStmt->bind_param('ss', $ownerId, $date);
        $chartStmt->execute();
        $res = $chartStmt->get_result()->fetch_assoc();
        $chartStmt->close();
        
        $daily[] = [
            'label' => $dayLabel,
            'value' => (int)($res['amt'] ?? 0),
        ];
    }
    
    // Normalisasi value harian untuk 0.0 - 1.0 (proporsi chart)
    $maxDaily = max(array_column($daily, 'value'));
    foreach ($daily as &$d) {
        $d['proportion'] = $maxDaily > 0 ? ($d['value'] / $maxDaily) : 0.0;
    }

    // b. Bulanan (12 bulan terakhir)
    $monthly = [];
    for ($i = 11; $i >= 0; $i--) {
        $month = date('Y-m', strtotime("-$i months"));
        $monthLabel = date('M', strtotime("$month-01"));
        
        $chartStmt = $conn->prepare("
            SELECT SUM(ph.amount) as amt
            FROM payment_history ph
            INNER JOIN room_registrations rr ON rr.id = ph.registration_id
            INNER JOIN kos_listings k ON k.id = rr.kos_id
            WHERE k.owner_id = ? AND ph.payment_status = 'paid' AND ph.period_month = ?
        ");
        $chartStmt->bind_param('ss', $ownerId, $month);
        $chartStmt->execute();
        $res = $chartStmt->get_result()->fetch_assoc();
        $chartStmt->close();
        
        $monthly[] = [
            'label' => $monthLabel,
            'value' => (int)($res['amt'] ?? 0),
        ];
    }
    
    $maxMonthly = max(array_column($monthly, 'value'));
    foreach ($monthly as &$m) {
        $m['proportion'] = $maxMonthly > 0 ? ($m['value'] / $maxMonthly) : 0.0;
    }

    // c. Tahunan (5 tahun terakhir)
    $yearly = [];
    $thisYear = (int)date('Y');
    for ($i = 4; $i >= 0; $i--) {
        $year = $thisYear - $i;
        
        $chartStmt = $conn->prepare("
            SELECT SUM(ph.amount) as amt
            FROM payment_history ph
            INNER JOIN room_registrations rr ON rr.id = ph.registration_id
            INNER JOIN kos_listings k ON k.id = rr.kos_id
            WHERE k.owner_id = ? AND ph.payment_status = 'paid' AND YEAR(ph.paid_at) = ?
        ");
        $chartStmt->bind_param('si', $ownerId, $year);
        $chartStmt->execute();
        $res = $chartStmt->get_result()->fetch_assoc();
        $chartStmt->close();
        
        $yearly[] = [
            'label' => (string)$year,
            'value' => (int)($res['amt'] ?? 0),
        ];
    }
    
    $maxYearly = max(array_column($yearly, 'value'));
    foreach ($yearly as &$y) {
        $y['proportion'] = $maxYearly > 0 ? ($y['value'] / $maxYearly) : 0.0;
    }

    // 5. Daftar Riwayat Transaksi Lengkap
    $txStmt = $conn->prepare("
        SELECT 
            ph.id,
            ph.registration_id,
            u.display_name as tenant_name,
            r.room_number,
            k.title as kos_title,
            ph.amount,
            ph.period_month,
            ph.payment_status,
            ph.payment_method,
            ph.proof_url,
            ph.paid_at
        FROM payment_history ph
        INNER JOIN room_registrations rr ON rr.id = ph.registration_id
        INNER JOIN users u ON u.id = rr.user_id
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        WHERE k.owner_id = ?
        ORDER BY ph.created_at DESC, ph.id DESC
    ");
    $txStmt->bind_param('s', $ownerId);
    $txStmt->execute();
    $rows = $txStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $txStmt->close();

    $transactions = [];
    foreach ($rows as $row) {
        $transactions[] = [
            'id' => (int)$row['id'],
            'registrationId' => $row['registration_id'],
            'tenantName' => $row['tenant_name'],
            'roomNumber' => $row['room_number'],
            'kosTitle' => $row['kos_title'],
            'amount' => (int)$row['amount'],
            'periodMonth' => $row['period_month'],
            'paymentStatus' => $row['payment_status'],
            'paymentMethod' => $row['payment_method'],
            'proofUrl' => $row['proof_url'],
            'paidAt' => $row['paid_at'],
        ];
    }

    sendJson(true, [
        'totalPaid' => $totalPaid,
        'summary' => [
            'paid' => $paidCount,
            'unpaid' => $unpaidCount,
            'overdue' => $overdueCount,
        ],
        'occupancy' => [
            'efficiency' => $efficiencyPercent,
            'occupied' => $occupiedRooms,
            'total' => $totalRooms,
        ],
        'charts' => [
            'daily' => $daily,
            'monthly' => $monthly,
            'yearly' => $yearly,
        ],
        'payments' => $transactions,
    ], 'Data finansial owner berhasil dimuat');
}

function handlePut(mysqli $conn, string $ownerId): void {
    $body = json_decode(file_get_contents('php://input'), true);
    if (!is_array($body)) {
        sendJson(false, null, 'Invalid JSON request', 400);
    }

    $paymentId = (int)($body['paymentId'] ?? 0);
    if ($paymentId <= 0) {
        sendJson(false, null, 'paymentId wajib dikirim', 400);
    }

    // Validasi kepemilikan transaksi: pastikan transaksi tersebut merujuk pada kos milik owner
    $valStmt = $conn->prepare("
        SELECT ph.id, rr.room_id, u.display_name
        FROM payment_history ph
        INNER JOIN room_registrations rr ON rr.id = ph.registration_id
        INNER JOIN users u ON u.id = rr.user_id
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        WHERE ph.id = ? AND k.owner_id = ?
        LIMIT 1
    ");
    $valStmt->bind_param('is', $paymentId, $ownerId);
    $valStmt->execute();
    $tx = $valStmt->get_result()->fetch_assoc();
    $valStmt->close();

    if (!$tx) {
        sendJson(false, null, 'Transaksi tidak ditemukan atau bukan milik kos Anda', 404);
    }

    // Update status transaksi menjadi paid (lunas)
    $updStmt = $conn->prepare("
        UPDATE payment_history 
        SET payment_status = 'paid', paid_at = NOW(), payment_method = 'bank_transfer'
        WHERE id = ?
    ");
    $updStmt->bind_param('i', $paymentId);
    if (!$updStmt->execute()) {
        sendJson(false, null, 'Gagal mengkonfirmasi pembayaran: ' . $updStmt->error, 500);
    }
    $updStmt->close();

    // Pastikan kamar berstatus occupied
    $roomStmt = $conn->prepare("
        UPDATE kos_rooms 
        SET status = 'occupied' 
        WHERE id = ? AND status = 'available'
    ");
    $roomStmt->bind_param('s', $tx['room_id']);
    $roomStmt->execute();
    $roomStmt->close();

    sendJson(true, true, 'Pembayaran penyewa ' . $tx['display_name'] . ' berhasil dikonfirmasi');
}
?>
