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

$payload = JWT::getPayloadFromRequest();
if (!$payload) {
    sendJson(false, null, 'Unauthorized', 401);
}

$ownerId = $payload['sub'] ?? '';
$role = $payload['role'] ?? '';
if (!in_array($role, ['owner', 'admin'], true)) {
    sendJson(false, null, 'Forbidden: hanya owner yang bisa akses', 403);
}

// 1. Ambil Statistik Kamar
$statStmt = $conn->prepare("
    SELECT 
        COUNT(r.id) as total,
        SUM(CASE WHEN r.status = 'occupied' THEN 1 ELSE 0 END) as occupied,
        SUM(CASE WHEN r.status = 'available' THEN 1 ELSE 0 END) as available,
        SUM(CASE WHEN r.status = 'maintenance' THEN 1 ELSE 0 END) as maintenance
    FROM kos_rooms r
    INNER JOIN kos_listings k ON k.id = r.kos_id
    WHERE k.owner_id = ?
");
$statStmt->bind_param('s', $ownerId);
$statStmt->execute();
$stats = $statStmt->get_result()->fetch_assoc();
$statStmt->close();

$totalRooms = (int)($stats['total'] ?? 0);
$occupiedRooms = (int)($stats['occupied'] ?? 0);
$availableRooms = (int)($stats['available'] ?? 0);
$maintenanceRooms = (int)($stats['maintenance'] ?? 0);

// 2. Pendapatan Bulan Ini (Lunas - paid)
$currentMonth = date('Y-m');
$revStmt = $conn->prepare("
    SELECT SUM(ph.amount) as total_revenue
    FROM payment_history ph
    INNER JOIN room_registrations rr ON rr.id = ph.registration_id
    INNER JOIN kos_listings k ON k.id = rr.kos_id
    WHERE k.owner_id = ? AND ph.payment_status = 'paid' AND ph.period_month = ?
");
$revStmt->bind_param('ss', $ownerId, $currentMonth);
$revStmt->execute();
$revResult = $revStmt->get_result()->fetch_assoc();
$revStmt->close();

$monthlyRevenue = (int)($revResult['total_revenue'] ?? 0);

// Hitung persentase kenaikan (dummy dinamis berdasarkan pembanding bulan lalu)
$prevMonth = date('Y-m', strtotime('-1 month'));
$prevRevStmt = $conn->prepare("
    SELECT SUM(ph.amount) as total_revenue
    FROM payment_history ph
    INNER JOIN room_registrations rr ON rr.id = ph.registration_id
    INNER JOIN kos_listings k ON k.id = rr.kos_id
    WHERE k.owner_id = ? AND ph.payment_status = 'paid' AND ph.period_month = ?
");
$prevRevStmt->bind_param('ss', $ownerId, $prevMonth);
$prevRevStmt->execute();
$prevRevResult = $prevRevStmt->get_result()->fetch_assoc();
$prevRevStmt->close();

$prevRevenue = (int)($prevRevResult['total_revenue'] ?? 0);
if ($prevRevenue > 0) {
    $diffPercent = (($monthlyRevenue - $prevRevenue) / $prevRevenue) * 100;
    $growthText = ($diffPercent >= 0 ? '+' : '') . number_format($diffPercent, 1) . '% dari bulan lalu';
} else {
    $growthText = '+100% dari bulan lalu';
}

// 3. Aktivitas Terkini (Maksimal 5)
// a. Ambil pendaftaran baru yang statusnya pending atau disetujui baru-baru ini
$activities = [];

$regActStmt = $conn->prepare("
    SELECT rr.id, u.display_name, r.room_number, k.title as kos_title, rr.status, rr.registered_at
    FROM room_registrations rr
    INNER JOIN users u ON u.id = rr.user_id
    INNER JOIN kos_rooms r ON r.id = rr.room_id
    INNER JOIN kos_listings k ON k.id = rr.kos_id
    WHERE k.owner_id = ?
    ORDER BY rr.registered_at DESC
    LIMIT 3
");
$regActStmt->bind_param('s', $ownerId);
$regActStmt->execute();
$regActs = $regActStmt->get_result()->fetch_all(MYSQLI_ASSOC);
$regActStmt->close();

foreach ($regActs as $act) {
    $statusText = $act['status'] === 'pending' ? 'Pengajuan pending' : 'Verifikasi selesai';
    $color = $act['status'] === 'pending' ? '0xFFEF6C00' : '0xFFEF6C00';
    $activities[] = [
        'color' => $color,
        'title' => $act['status'] === 'pending' ? 'Pengajuan Baru' : 'Penghuni Baru',
        'subtitle' => 'Kamar ' . $act['room_number'] . ' • ' . $act['display_name'],
        'time' => date('d M H:i', strtotime($act['registered_at'])),
        'raw_time' => $act['registered_at']
    ];
}

// b. Ambil pembayaran terbaru (sukses)
$payActStmt = $conn->prepare("
    SELECT ph.id, u.display_name, r.room_number, ph.amount, ph.paid_at
    FROM payment_history ph
    INNER JOIN room_registrations rr ON rr.id = ph.registration_id
    INNER JOIN users u ON u.id = rr.user_id
    INNER JOIN kos_rooms r ON r.id = rr.room_id
    INNER JOIN kos_listings k ON k.id = rr.kos_id
    WHERE k.owner_id = ? AND ph.payment_status = 'paid'
    ORDER BY ph.paid_at DESC
    LIMIT 3
");
$payActStmt->bind_param('s', $ownerId);
$payActStmt->execute();
$payActs = $payActStmt->get_result()->fetch_all(MYSQLI_ASSOC);
$payActStmt->close();

foreach ($payActs as $act) {
    $activities[] = [
        'color' => '0xFF2E7D32',
        'title' => 'Pembayaran Berhasil',
        'subtitle' => 'Kamar ' . $act['room_number'] . ' • Rp ' . number_format($act['amount'], 0, ',', '.'),
        'time' => date('d M H:i', strtotime($act['paid_at'])),
        'raw_time' => $act['paid_at']
    ];
}

// c. Cari kamar yang sedang dalam maintenance untuk disimulasikan komplainnya
$maintStmt = $conn->prepare("
    SELECT r.room_number, r.description, r.updated_at
    FROM kos_rooms r
    INNER JOIN kos_listings k ON k.id = r.kos_id
    WHERE k.owner_id = ? AND r.status = 'maintenance'
    ORDER BY r.updated_at DESC
    LIMIT 2
");
$maintStmt->bind_param('s', $ownerId);
$maintStmt->execute();
$maints = $maintStmt->get_result()->fetch_all(MYSQLI_ASSOC);
$maintStmt->close();

foreach ($maints as $m) {
    $note = !empty($m['description']) ? $m['description'] : 'Kerusakan fasilitas kamar';
    $activities[] = [
        'color' => '0xFF1565C0',
        'title' => 'Komplain Perbaikan',
        'subtitle' => 'Kamar ' . $m['room_number'] . ' • ' . $note,
        'time' => date('d M H:i', strtotime($m['updated_at'])),
        'raw_time' => $m['updated_at']
    ];
}

// Urutkan aktivitas berdasarkan waktu (terbaru di atas)
usort($activities, function($a, $b) {
    return strcmp($b['raw_time'], $a['raw_time']);
});
$activities = array_slice($activities, 0, 5);

// 4. Jatuh Tempo Mendatang (Paling mendesak, status unpaid/overdue)
$dueStmt = $conn->prepare("
    SELECT ph.id, u.display_name, r.room_number, ph.period_month, ph.amount, ph.created_at
    FROM payment_history ph
    INNER JOIN room_registrations rr ON rr.id = ph.registration_id
    INNER JOIN users u ON u.id = rr.user_id
    INNER JOIN kos_rooms r ON r.id = rr.room_id
    INNER JOIN kos_listings k ON k.id = rr.kos_id
    WHERE k.owner_id = ? AND ph.payment_status IN ('unpaid', 'overdue')
    ORDER BY ph.period_month ASC, ph.created_at ASC
    LIMIT 3
");
$dueStmt->bind_param('s', $ownerId);
$dueStmt->execute();
$dues = $dueStmt->get_result()->fetch_all(MYSQLI_ASSOC);
$dueStmt->close();

$dueList = [];
foreach ($dues as $d) {
    // Hitung perkiraan jatuh tempo berdasarkan tanggal dibuat transaksi + 3 hari
    $createdTime = strtotime($d['created_at']);
    $dueTime = $createdTime + (3 * 24 * 3600);
    $diffDays = ceil(($dueTime - time()) / (24 * 3600));
    
    if ($diffDays < 0) {
        $daysText = abs($diffDays) . ' hari terlambat';
    } elseif ($diffDays == 0) {
        $daysText = 'Hari ini';
    } else {
        $daysText = $diffDays . ' hari lagi';
    }

    $dueList[] = [
        'id' => $d['id'],
        'name' => $d['display_name'],
        'room' => $d['room_number'],
        'amount' => (int)$d['amount'],
        'inDays' => $daysText,
    ];
}

sendJson(true, [
    'statistics' => [
        'total' => $totalRooms,
        'occupied' => $occupiedRooms,
        'available' => $availableRooms,
        'maintenance' => $maintenanceRooms,
    ],
    'revenue' => [
        'monthly' => $monthlyRevenue,
        'growth' => $growthText,
    ],
    'activities' => $activities,
    'dueSoon' => $dueList,
], 'Data dashboard berhasil dimuat');
?>
