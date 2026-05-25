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

function currentPeriodKey(string $rentalType): string {
    return match ($rentalType) {
        'daily' => date('Y-m-d'),
        'yearly' => date('Y'),
        default => date('Y-m'),
    };
}

function periodKeyFromStartDate(?string $startDate, string $rentalType): string {
    if (!$startDate || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $startDate)) {
        return currentPeriodKey($rentalType);
    }

    $date = new DateTime($startDate);
    return match ($rentalType) {
        'daily' => $date->format('Y-m-d'),
        'yearly' => $date->format('Y'),
        default => $date->format('Y-m'),
    };
}

function dateFromPeriodKey(string $period, string $rentalType, ?string $startDate = null): DateTime {
    $defaultDay = 5;
    $dueDay = $defaultDay;

    if ($startDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $startDate)) {
        $dueDay = (int)substr($startDate, 8, 2);
        if ($dueDay < 1 || $dueDay > 31) {
            $dueDay = $defaultDay;
        }
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
    if ($dueDay > $daysInMonth) {
        $dueDay = $daysInMonth;
    }

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

function activeUntilFromPaidPeriods(?string $startDate, string $rentalType, int $paidPeriods): ?string {
    if ($paidPeriods <= 0) {
        return null;
    }

    $base = $startDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $startDate)
        ? new DateTime($startDate)
        : new DateTime(date('Y-m-d'));

    return addRentalPeriods($base, $rentalType, $paidPeriods)->format('Y-m-d');
}

function paymentLimitText(string $activeUntil): string {
    $date = new DateTime($activeUntil);
    $date->modify('+1 day');
    return 'Batas bayar ' . monthNameShort($date->format('Y-m-d'));
}

if (
    $userId &&
    tableExists($conn, 'room_registrations') &&
    tableExists($conn, 'kos_rooms') &&
    tableExists($conn, 'kos_listings')
) {
    $hasPayments = tableExists($conn, 'payment_history');
    $stmt = $conn->prepare($hasPayments ? "
        SELECT
            rr.id AS registration_id,
            rr.start_date,
            r.room_number,
            r.price_per_month,
            r.rental_type,
            k.title AS kos_name,
            ph.amount,
            ph.period_month,
            ph.payment_status,
            (
                SELECT COUNT(*)
                FROM payment_history paid_ph
                WHERE paid_ph.registration_id = rr.id
                  AND paid_ph.payment_status = 'paid'
            ) AS paid_periods
        FROM room_registrations rr
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        LEFT JOIN payment_history ph
            ON ph.registration_id = rr.id
            AND ph.payment_status NOT IN ('paid', 'cancelled')
        WHERE rr.user_id = ?
          AND rr.status IN ('active', 'approved')
          AND rr.end_date IS NULL
        ORDER BY ph.period_month ASC, rr.registered_at DESC
        LIMIT 1
    " : "
        SELECT
            rr.id AS registration_id,
            rr.start_date,
            r.room_number,
            r.price_per_month,
            r.price_per_month AS amount,
            r.rental_type,
            k.title AS kos_name,
            NULL AS period_month,
            0 AS paid_periods
        FROM room_registrations rr
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        WHERE rr.user_id = ? AND rr.status IN ('active', 'approved')
          AND rr.end_date IS NULL
        ORDER BY rr.registered_at DESC
        LIMIT 1
    ");
    if ($stmt) {
        $stmt->bind_param('s', $userId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if ($row) {
            $rentalType = $row['rental_type'] ?? 'monthly';
            $period = $row['period_month'] ?: periodKeyFromStartDate($row['start_date'] ?? null, $rentalType);
            $paidPeriods = (int)($row['paid_periods'] ?? 0);
            $activeUntil = activeUntilFromPaidPeriods(
                $row['start_date'] ?? null,
                $rentalType,
                $paidPeriods
            ) ?? dateFromPeriodKey($period, $rentalType, $row['start_date'] ?? null)->format('Y-m-d');

            $activeBillAmount = (float)($row['amount'] ?? $row['price_per_month'] ?? 0);
            $activeBillLabel = ($row['kos_name'] ?? 'Kos') . ' - Kamar ' . $row['room_number'];
            $dueDateText = paymentLimitText($activeUntil);
            $billProgress = min(1, max(0.15, (int)date('d') / 30));
        }
    }
}

$recommendations = [
    [
        'id' => 'rec-1',
        'name' => 'Paket Menu Harian',
        'description' => 'Sering dipesan pengguna kos',
        'price' => 25000,
        'imageUrl' => 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800',
    ],
    [
        'id' => 'rec-2',
        'name' => 'Cuci Lipat Regular',
        'description' => 'Layanan laundry praktis',
        'price' => 8000,
        'imageUrl' => 'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=800',
    ],
];

if (
    $userId &&
    tableExists($conn, 'orders') &&
    tableExists($conn, 'order_items') &&
    tableExists($conn, 'products')
) {
    $stmt = $conn->prepare("
        SELECT
            p.id,
            p.nama_produk,
            p.deskripsi,
            p.harga,
            p.image_url,
            COUNT(oi.id) AS order_count,
            MAX(o.created_at) AS last_ordered_at
        FROM orders o
        INNER JOIN order_items oi ON oi.order_id = o.id
        INNER JOIN products p ON p.id = oi.product_id
        WHERE o.user_id = ?
          AND COALESCE(o.service_type, p.service_type, '') IN ('laundry', 'catering')
        GROUP BY p.id, p.nama_produk, p.deskripsi, p.harga, p.image_url
        ORDER BY order_count DESC, last_ordered_at DESC
        LIMIT 6
    ");
    if ($stmt) {
        $stmt->bind_param('s', $userId);
        $stmt->execute();
        $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();

        if (!empty($rows)) {
            $recommendations = array_map(fn($row) => [
                'id' => (string)$row['id'],
                'name' => $row['nama_produk'] ?? '',
                'description' => $row['deskripsi'] ?? 'Sering Anda pesan',
                'price' => (float)($row['harga'] ?? 0),
                'imageUrl' => $row['image_url'] ?? '',
            ], $rows);
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
    'recommendations' => $recommendations,
]);
?>
