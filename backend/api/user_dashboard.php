<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../helpers/jwt.php';
require_once __DIR__ . '/../config/db.php';

function sendDashboard(array $data): void {
    echo json_encode([
        'success' => true,
        'message' => 'Dashboard user berhasil dimuat',
        'data' => $data,
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

$payload = JWT::getPayloadFromRequest();
$displayName = $payload['displayName'] ?? 'User';
$userId = $payload['sub'] ?? null;

$activeBillAmount = 0;
$activeBillLabel = 'Belum ada tagihan aktif';
$dueDateText = '-';
$billProgress = 0;

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

function monthNameShort(string $date): string {
    $months = [
        '01' => 'Jan', '02' => 'Feb', '03' => 'Mar', '04' => 'Apr',
        '05' => 'Mei', '06' => 'Jun', '07' => 'Jul', '08' => 'Agu',
        '09' => 'Sep', '10' => 'Okt', '11' => 'Nov', '12' => 'Des',
    ];
    $parts = explode('-', $date);
    return (int)($parts[2] ?? 5) . ' ' . ($months[$parts[1] ?? ''] ?? '');
}

if (
    $userId &&
    tableExists($conn, 'room_registrations') &&
    tableExists($conn, 'kos_rooms') &&
    tableExists($conn, 'kos_listings')
) {
    $hasPayments = tableExists($conn, 'payment_history');
    $stmt = $conn->prepare($hasPayments ? "
        SELECT ph.amount, ph.period_month, r.room_number, k.title AS kos_name
        FROM payment_history ph
        INNER JOIN room_registrations rr ON rr.id = ph.registration_id
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        WHERE rr.user_id = ? AND ph.payment_status <> 'paid'
        ORDER BY ph.period_month ASC
        LIMIT 1
    " : "
        SELECT r.price_per_month AS amount, DATE_FORMAT(CURDATE(), '%Y-%m') AS period_month,
               r.room_number, k.title AS kos_name
        FROM room_registrations rr
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        WHERE rr.user_id = ? AND rr.status IN ('active', 'approved', 'pending')
        ORDER BY rr.registered_at DESC
        LIMIT 1
    ");
    if ($stmt) {
        $stmt->bind_param('s', $userId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if ($row) {
            $dueDate = $row['period_month'] . '-05';
            $activeBillAmount = (float)$row['amount'];
            $activeBillLabel = ($row['kos_name'] ?? 'Kos') . ' - Kamar ' . $row['room_number'];
            $dueDateText = 'Jatuh tempo ' . monthNameShort($dueDate);
            $billProgress = min(1, max(0.15, (int)date('d') / 30));
        }
    }
}

sendDashboard([
    'displayName' => $displayName,
    'activeBillAmount' => $activeBillAmount,
    'activeBillLabel' => $activeBillLabel,
    'dueDateText' => $dueDateText,
    'billProgress' => $billProgress,
    'announcementTitle' => 'Pembersihan AC Terjadwal',
    'announcementSubtitle' => 'Besok, pukul 10:00 WIB',
    'recommendations' => [
        [
            'id' => 'rec-1',
            'name' => 'Salad Sehat Ayam Bakar',
            'description' => 'Menu harian',
            'price' => 25000,
            'imageUrl' => 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800',
        ],
        [
            'id' => 'rec-2',
            'name' => 'Signature Coffee',
            'description' => 'Kopi favorit',
            'price' => 18000,
            'imageUrl' => 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
        ],
    ],
]);
?>
