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

function ensurePaymentPeriodColumn(mysqli $conn): void {
    if (!tableExists($conn, 'payment_history')) return;
    $conn->query("
        ALTER TABLE payment_history
        MODIFY period_month VARCHAR(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
    ");
}

function monthName(string $period): string {
    if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $period)) {
        $date = DateTime::createFromFormat('Y-m-d', $period);
        return $date ? $date->format('d/m/Y') : $period;
    }
    if (preg_match('/^\d{4}$/', $period)) {
        return $period;
    }

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

function periodKeyFromDate(DateTime $date, string $rentalType): string {
    return match ($rentalType) {
        'daily' => $date->format('Y-m-d'),
        'yearly' => $date->format('Y'),
        default => $date->format('Y-m'),
    };
}

function addMonthsToPeriod(string $period, int $months): string {
    $date = DateTime::createFromFormat('Y-m-d', $period . '-01');
    if (!$date) {
        return currentMonthPeriod();
    }
    $date->modify(($months >= 0 ? '+' : '') . $months . ' month');
    return $date->format('Y-m');
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

function expireDateForPeriod(string $period, ?string $startDate = null, string $rentalType = 'monthly'): string {
    $date = new DateTime(dueDateForPeriod($period, $startDate, $rentalType));
    $date->modify('+1 day');
    return $date->format('Y-m-d');
}

function paymentWindowBaseForPeriod(
    string $period,
    ?string $startDate,
    string $rentalType,
    int $paidPeriods
): string {
    return activeUntilFromPaidPeriods($startDate, $rentalType, $paidPeriods)
        ?? dateFromPeriodKey($period, $rentalType, $startDate)->format('Y-m-d');
}

function nextPeriodKey(string $period, string $rentalType, ?string $startDate): string {
    $date = dateFromPeriodKey($period, $rentalType, $startDate);
    return periodKeyFromDate(addRentalPeriods($date, $rentalType, 1), $rentalType);
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
    return activeUntilFromPaidPeriods(
        $row['start_date'] ?? null,
        $row['rental_type'] ?? 'monthly',
        (int)($row['paid_periods'] ?? 0)
    );
}

function billPayload(
    string $id,
    string $period,
    float $amount,
    string $status,
    ?string $paymentMethod,
    ?string $paymentDate,
    string $dueDate,
    array $room
): array {
    $cancelled = $status === 'dibatalkan' ||
        ($room['payment_status'] ?? '') === 'cancelled' ||
        ($room['registration_status'] ?? '') === 'cancelled';
    if ($cancelled && $status !== 'lunas') {
        $status = 'dibatalkan';
    }

    return [
        'id' => $id,
        'itemDescription' => 'Sewa ' . ($room['kos_name'] ?? 'Kos') . ' - ' . monthName($period),
        'amount' => $amount,
        'dueDate' => $dueDate,
        'activeUntil' => $room['active_until'] ?? null,
        'status' => $status,
        'paymentMethod' => $paymentMethod,
        'paymentDate' => $paymentDate,
        'kosName' => $room['kos_name'] ?? '',
        'kosAccessCode' => $room['access_code'] ?? '',
        'roomNumber' => $room['room_number'] ?? '',
        'roomType' => $room['room_type'] ?? '',
        'registrationStatus' => $room['registration_status'] ?? null,
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
            rr.status AS registration_status,
            rr.start_date,
            rr.end_date,
            k.title AS kos_name,
            k.access_code,
            r.room_number,
            r.room_type,
            r.price_per_month,
            r.rental_type
        FROM room_registrations rr
        INNER JOIN kos_listings k ON k.id = rr.kos_id
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        WHERE rr.user_id = ?
          AND rr.status IN ('active', 'approved')
          AND rr.end_date IS NULL
        ORDER BY rr.updated_at DESC, rr.registered_at DESC
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
    if (!empty($room['end_date'])) return [];

    $rentalType = $room['rental_type'] ?? 'monthly';
    $startDate = $room['start_date'] ?? null;
    $start = $startDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $startDate)
        ? new DateTime($startDate)
        : new DateTime(date('Y-m-d'));
    $period = periodKeyFromDate($start, $rentalType);

    if (tableExists($conn, 'payment_history')) {
        $stmt = $conn->prepare("
            SELECT
                SUM(CASE WHEN payment_status = 'paid' THEN 1 ELSE 0 END) AS paid_periods,
                SUM(CASE WHEN payment_status NOT IN ('paid', 'cancelled') THEN 1 ELSE 0 END) AS open_bills,
                MAX(CASE WHEN payment_status = 'paid' THEN period_month ELSE NULL END) AS latest_paid_period
            FROM payment_history
            WHERE registration_id = ?
        ");
        if ($stmt) {
            $stmt->bind_param('s', $room['registration_id']);
            $stmt->execute();
            $summary = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            if ($summary) {
                if ((int)($summary['open_bills'] ?? 0) > 0) {
                    return [];
                }
                $paidPeriods = (int)($summary['paid_periods'] ?? 0);
                $latestPaidPeriod = trim((string)($summary['latest_paid_period'] ?? ''));
                if ($latestPaidPeriod !== '') {
                    $period = nextPeriodKey($latestPaidPeriod, $rentalType, $startDate);
                } else {
                    $lastActiveUntil = activeUntilFromPaidPeriods(
                        $startDate,
                        $rentalType,
                        $paidPeriods
                    );
                    if ($lastActiveUntil !== null) {
                        $nextStart = new DateTime($lastActiveUntil);
                        $period = periodKeyFromDate($nextStart, $rentalType);
                    }
                }
            }
        }
    }

    $paidPeriods = isset($summary) ? (int)($summary['paid_periods'] ?? 0) : 0;
    $dueDate = paymentWindowBaseForPeriod(
        $period,
        $startDate,
        $rentalType,
        $paidPeriods
    );
    $room['active_until'] = $dueDate;

    return [
        billPayload(
            'generated-' . $room['registration_id'] . '-' . $period,
            $period,
            (float)$room['price_per_month'],
            'belum_bayar',
            null,
            null,
            $dueDate,
            $room
        ),
    ];
}

function expireScheduledEndDates(mysqli $conn, string $userId): void {
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

function expireOverdueBills(mysqli $conn, string $userId): void {
    $stmt = $conn->prepare("
        SELECT
            ph.id,
            ph.period_month,
            ph.payment_status,
            rr.id AS registration_id,
            rr.room_id,
            rr.start_date,
            r.rental_type
        FROM payment_history ph
        INNER JOIN room_registrations rr ON rr.id = ph.registration_id
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        WHERE rr.user_id = ?
          AND rr.status IN ('active', 'approved')
          AND ph.payment_status <> 'paid'
    ");
    if (!$stmt) return;

    $stmt->bind_param('s', $userId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $today = date('Y-m-d');
    foreach ($rows as $row) {
        $expireDate = expireDateForPeriod(
            $row['period_month'],
            $row['start_date'] ?? null,
            $row['rental_type'] ?? 'monthly'
        );
        if ($expireDate > $today) {
            continue;
        }

        $conn->begin_transaction();
        try {
            $paymentId = (string)$row['id'];
            $registrationId = (string)$row['registration_id'];
            $roomId = (string)$row['room_id'];

            $markExpired = $conn->prepare("
                UPDATE payment_history
                SET payment_status = 'cancelled',
                    payment_method = NULL,
                    paid_at = NULL
                WHERE id = ? AND payment_status <> 'paid'
            ");
            if (!$markExpired) {
                throw new Exception($conn->error);
            }
            $markExpired->bind_param('s', $paymentId);
            $markExpired->execute();
            $markExpired->close();

            $endRegistration = $conn->prepare("
                UPDATE room_registrations
                SET status = 'cancelled', end_date = ?, updated_at = NOW()
                WHERE id = ? AND status IN ('active', 'approved')
            ");
            if (!$endRegistration) {
                throw new Exception($conn->error);
            }
            $endRegistration->bind_param('ss', $expireDate, $registrationId);
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

            $conn->commit();
        } catch (Exception $e) {
            $conn->rollback();
            error_log('Failed to expire overdue bill ' . ($row['id'] ?? '') . ': ' . $e->getMessage());
        }
    }
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

function expireOverdueCurrentRegistrations(mysqli $conn, string $userId, bool $hasPayments): void {
    $today = date('Y-m-d');

    $sql = $hasPayments ? "
        SELECT
            rr.id AS registration_id,
            rr.room_id,
            rr.start_date,
            r.price_per_month,
            r.rental_type,
            ph.id AS payment_id,
            ph.payment_status,
            ph.period_month
        FROM room_registrations rr
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        LEFT JOIN payment_history ph
            ON ph.registration_id = rr.id
            AND ph.period_month = CASE
                WHEN r.rental_type = 'daily' THEN DATE_FORMAT(COALESCE(rr.start_date, CURDATE()), '%Y-%m-%d')
                WHEN r.rental_type = 'yearly' THEN DATE_FORMAT(COALESCE(rr.start_date, CURDATE()), '%Y')
                ELSE DATE_FORMAT(COALESCE(rr.start_date, CURDATE()), '%Y-%m')
            END
        WHERE rr.user_id = ?
          AND rr.status IN ('active', 'approved')
    " : "
        SELECT
            rr.id AS registration_id,
            rr.room_id,
            rr.start_date,
            r.price_per_month,
            r.rental_type,
            NULL AS payment_id,
            NULL AS payment_status,
            NULL AS period_month
        FROM room_registrations rr
        INNER JOIN kos_rooms r ON r.id = rr.room_id
        WHERE rr.user_id = ?
          AND rr.status IN ('active', 'approved')
    ";

    $stmt = $conn->prepare($sql);
    if (!$stmt) return;

    if ($hasPayments) {
        $stmt->bind_param('s', $userId);
    } else {
        $stmt->bind_param('s', $userId);
    }
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    foreach ($rows as $row) {
        $rentalType = $row['rental_type'] ?? 'monthly';
        $startDate = $row['start_date'] ?? null;
        $base = $startDate && preg_match('/^\d{4}-\d{2}-\d{2}$/', $startDate)
            ? new DateTime($startDate)
            : new DateTime(date('Y-m-d'));
        $period = $row['period_month'] ?: periodKeyFromDate($base, $rentalType);
        $expireDate = expireDateForPeriod($period, $startDate, $rentalType);
        if ($expireDate > $today || ($row['payment_status'] ?? '') === 'paid') {
            continue;
        }

        $conn->begin_transaction();
        try {
            if (!empty($row['payment_id'])) {
                $paymentId = (string)$row['payment_id'];
                $markUnpaid = $conn->prepare("
                    UPDATE payment_history
                    SET payment_status = 'cancelled',
                        payment_method = NULL,
                        paid_at = NULL
                    WHERE id = ? AND payment_status <> 'paid'
                ");
                if (!$markUnpaid) {
                    throw new Exception($conn->error);
                }
                $markUnpaid->bind_param('s', $paymentId);
                $markUnpaid->execute();
                $markUnpaid->close();
            } else {
                $registrationId = (string)$row['registration_id'];
                $amount = (int)round((float)($row['price_per_month'] ?? 0));
                $insertCancelled = $conn->prepare("
                    INSERT INTO payment_history
                        (registration_id, amount, period_month, payment_status, payment_method, created_at)
                    VALUES (?, ?, ?, 'cancelled', NULL, NOW())
                ");
                if (!$insertCancelled) {
                    throw new Exception($conn->error);
                }
                $insertCancelled->bind_param('sis', $registrationId, $amount, $period);
                $insertCancelled->execute();
                $insertCancelled->close();
            }

            endRegistrationAndFreeRoom(
                $conn,
                (string)$row['registration_id'],
                (string)$row['room_id'],
                $expireDate
            );

            $conn->commit();
        } catch (Exception $e) {
            $conn->rollback();
            error_log('Failed to expire overdue registration ' . ($row['registration_id'] ?? '') . ': ' . $e->getMessage());
        }
    }
}

function handlePut(mysqli $conn, string $userId): void {
    $body = json_decode(file_get_contents('php://input'), true);
    if (!is_array($body)) {
        sendJson(false, null, 'Invalid JSON request', 400);
    }

    $action = trim((string)($body['action'] ?? ''));
    if ($action !== 'cancel_order') {
        sendJson(false, null, 'Unsupported action', 400);
    }

    $billingId = trim((string)($body['id'] ?? ''));
    if ($billingId === '') {
        sendJson(false, null, 'ID tagihan wajib diisi', 400);
    }

    if (!tableExists($conn, 'room_registrations') ||
        !tableExists($conn, 'kos_rooms') ||
        !tableExists($conn, 'kos_listings') ||
        !tableExists($conn, 'payment_history')) {
        sendJson(false, null, 'Data tagihan belum tersedia', 404);
    }

    expireOverdueCurrentRegistrations($conn, $userId, true);
    expireOverdueBills($conn, $userId);

    if (preg_match('/^generated-(.+)-(\d{4}(?:-\d{2})?(?:-\d{2})?)$/', $billingId, $matches)) {
        $registrationId = $matches[1];
        $period = $matches[2];

        $stmt = $conn->prepare("
            SELECT rr.id AS registration_id, rr.room_id, r.price_per_month
            FROM room_registrations rr
            INNER JOIN kos_rooms r ON r.id = rr.room_id
            WHERE rr.id = ? AND rr.user_id = ? AND rr.status IN ('active', 'approved')
            LIMIT 1
        ");
        if (!$stmt) {
            sendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param('ss', $registrationId, $userId);
        $stmt->execute();
        $generated = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$generated) {
            sendJson(true, true, 'Order sudah dibatalkan.');
        }

        $activeUntil = getActiveUntil($conn, $userId);
        if ($activeUntil !== null && $activeUntil >= date('Y-m-d')) {
            $conn->begin_transaction();
            try {
                $amount = (int)round((float)($generated['price_per_month'] ?? 0));
                $insertCancelled = $conn->prepare("
                    INSERT INTO payment_history
                        (registration_id, amount, period_month, payment_status, payment_method, created_at)
                    VALUES (?, ?, ?, 'cancelled', NULL, NOW())
                ");
                if (!$insertCancelled) {
                    throw new Exception($conn->error);
                }
                $insertCancelled->bind_param('sis', $registrationId, $amount, $period);
                $insertCancelled->execute();
                $insertCancelled->close();

                $scheduleEnd = $conn->prepare("
                    UPDATE room_registrations
                    SET end_date = ?, updated_at = NOW()
                    WHERE id = ?
                      AND status IN ('active', 'approved')
                      AND (end_date IS NULL OR end_date > ?)
                ");
                if (!$scheduleEnd) {
                    throw new Exception($conn->error);
                }
                $scheduleEnd->bind_param('sss', $activeUntil, $registrationId, $activeUntil);
                $scheduleEnd->execute();
                $scheduleEnd->close();

                $conn->commit();
            } catch (Exception $e) {
                $conn->rollback();
                sendJson(false, null, 'Gagal menjadwalkan penghentian sewa', 500);
            }

            sendJson(true, true, 'Sewa tidak akan diperpanjang. Masa aktif tetap sampai ' . $activeUntil . '.');
        }

        $conn->begin_transaction();
        try {
            $amount = (int)round((float)($generated['price_per_month'] ?? 0));
            $insertCancelled = $conn->prepare("
                INSERT INTO payment_history
                    (registration_id, amount, period_month, payment_status, payment_method, created_at)
                VALUES (?, ?, ?, 'cancelled', NULL, NOW())
            ");
            if (!$insertCancelled) {
                throw new Exception($conn->error);
            }
            $insertCancelled->bind_param('sis', $registrationId, $amount, $period);
            $insertCancelled->execute();
            $insertCancelled->close();

            endRegistrationAndFreeRoom($conn, $registrationId, (string)$generated['room_id'], date('Y-m-d'));
            $conn->commit();
        } catch (Exception $e) {
            $conn->rollback();
            sendJson(false, null, 'Gagal membatalkan order', 500);
        }

        sendJson(true, true, 'Order berhasil dibatalkan.');
    }

    $stmt = $conn->prepare("
        SELECT ph.id, ph.period_month, ph.payment_status, ph.payment_method,
               rr.id AS registration_id, rr.room_id, rr.status AS registration_status
        FROM payment_history ph
        INNER JOIN room_registrations rr ON rr.id = ph.registration_id
        WHERE ph.id = ? AND rr.user_id = ?
        LIMIT 1
    ");
    if (!$stmt) {
        sendJson(false, null, 'Database error', 500);
    }
    $stmt->bind_param('ss', $billingId, $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) {
        sendJson(true, true, 'Order sudah otomatis dibatalkan karena jatuh tempo.');
    }

    if (($row['payment_status'] ?? '') === 'cancelled' || ($row['registration_status'] ?? '') === 'cancelled') {
        sendJson(true, true, 'Order sudah dibatalkan.');
    }

    if ($row['payment_status'] === 'paid') {
        $keepDueDateIfPaid = !empty($body['keep_due_date_if_paid']);
        if ($keepDueDateIfPaid) {
            $dueDate = trim((string)($body['paid_until'] ?? ''));
            if ($dueDate === '') {
                sendJson(false, null, 'Tanggal akhir masa sewa wajib dikirim untuk order lunas', 400);
            }
            $dueDate = substr($dueDate, 0, 10);

            $scheduleEnd = $conn->prepare("
                UPDATE room_registrations
                SET end_date = ?, updated_at = NOW()
                WHERE id = ?
                  AND status IN ('active', 'approved')
                  AND (end_date IS NULL OR end_date > ?)
            ");
            if (!$scheduleEnd) {
                sendJson(false, null, 'Database error', 500);
            }
            $scheduleEnd->bind_param('sss', $dueDate, $row['registration_id'], $dueDate);
            $scheduleEnd->execute();
            $scheduleEnd->close();

            $cancelFutureBills = $conn->prepare("
                UPDATE payment_history
                SET payment_status = 'cancelled',
                    payment_method = NULL,
                    paid_at = NULL
                WHERE registration_id = ?
                  AND period_month > ?
                  AND payment_status NOT IN ('paid', 'cancelled')
            ");
            if ($cancelFutureBills) {
                $cancelFutureBills->bind_param('ss', $row['registration_id'], $row['period_month']);
                $cancelFutureBills->execute();
                $cancelFutureBills->close();
            }

            sendJson(true, true, 'Sewa tidak akan diperpanjang. Masa aktif tetap sampai ' . $dueDate . '.');
        }
        sendJson(false, null, 'Tagihan sudah dibayar dan tidak dapat dibatalkan tanpa mempertahankan tanggal jatuh tempo.', 400);
    }

    $activeUntil = getActiveUntil($conn, $userId);
    if ($activeUntil !== null && $activeUntil >= date('Y-m-d')) {
        $conn->begin_transaction();
        try {
            $cancel = $conn->prepare("
                UPDATE payment_history
                SET payment_status = 'cancelled',
                    payment_method = NULL,
                    paid_at = NULL
                WHERE id = ? AND payment_status NOT IN ('paid', 'cancelled')
            ");
            if (!$cancel) {
                throw new Exception($conn->error);
            }
            $cancel->bind_param('s', $billingId);
            $cancel->execute();
            $cancel->close();

            $scheduleEnd = $conn->prepare("
                UPDATE room_registrations
                SET end_date = ?, updated_at = NOW()
                WHERE id = ?
                  AND status IN ('active', 'approved')
                  AND (end_date IS NULL OR end_date > ?)
            ");
            if (!$scheduleEnd) {
                throw new Exception($conn->error);
            }
            $scheduleEnd->bind_param('sss', $activeUntil, $row['registration_id'], $activeUntil);
            $scheduleEnd->execute();
            $scheduleEnd->close();

            $conn->commit();
        } catch (Exception $e) {
            $conn->rollback();
            sendJson(false, null, 'Gagal menjadwalkan penghentian sewa', 500);
        }

        sendJson(true, true, 'Sewa tidak akan diperpanjang. Masa aktif tetap sampai ' . $activeUntil . '.');
    }

    $conn->begin_transaction();
    try {
        $cancel = $conn->prepare("
            UPDATE payment_history
            SET payment_status = 'cancelled',
                payment_method = NULL,
                paid_at = NULL
            WHERE id = ? AND payment_status <> 'paid'
        ");
        if (!$cancel) {
            throw new Exception($conn->error);
        }
        $cancel->bind_param('s', $billingId);
        $cancel->execute();
        $cancel->close();

        endRegistrationAndFreeRoom($conn, (string)$row['registration_id'], (string)$row['room_id'], date('Y-m-d'));
        $conn->commit();
    } catch (Exception $e) {
        $conn->rollback();
        sendJson(false, null, 'Gagal membatalkan order', 500);
    }

    sendJson(true, true, 'Order berhasil dibatalkan.');
}

$payload = JWT::getPayloadFromRequest();
$userId = $payload['sub'] ?? null;

if (!$userId) {
    sendJson(false, null, 'Unauthorized', 401);
}

ensurePaymentPeriodColumn($conn);

if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    handlePut($conn, $userId);
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendJson(false, null, 'Only GET or PUT method allowed', 405);
}

if (!tableExists($conn, 'room_registrations') ||
    !tableExists($conn, 'kos_rooms') ||
    !tableExists($conn, 'kos_listings')) {
    sendJson(true, [], 'User belum tersambung dengan kos/kamar');
}

$hasPayments = tableExists($conn, 'payment_history');
expireScheduledEndDates($conn, $userId);
expireOverdueCurrentRegistrations($conn, $userId, $hasPayments);

if (!$hasPayments) {
    sendJson(true, generatedCurrentBill($conn, $userId), 'Tagihan kamar aktif berhasil dimuat');
}

expireOverdueBills($conn, $userId);

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
        r.rental_type,
        rr.id AS registration_id,
        rr.status AS registration_status,
        rr.start_date,
        (
            SELECT COUNT(*)
            FROM payment_history paid_ph
            WHERE paid_ph.registration_id = rr.id
              AND paid_ph.payment_status = 'paid'
        ) AS paid_periods
    FROM payment_history ph
    INNER JOIN room_registrations rr ON rr.id = ph.registration_id
    INNER JOIN kos_listings k ON k.id = rr.kos_id
    INNER JOIN kos_rooms r ON r.id = rr.room_id
    WHERE rr.user_id = ?
      AND (
          rr.status IN ('active', 'approved')
          OR (rr.status = 'cancelled' AND ph.payment_status = 'cancelled')
      )
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
    if ($r['payment_status'] === 'paid') {
        $status = 'lunas';
    } elseif ($r['payment_status'] === 'cancelled') {
        $status = 'dibatalkan';
    } else {
        $status = 'belum_bayar';
    }
    $dueDate = $status === 'belum_bayar'
        ? paymentWindowBaseForPeriod(
            $r['period_month'],
            $r['start_date'] ?? null,
            $r['rental_type'] ?? 'monthly',
            (int)($r['paid_periods'] ?? 0)
        )
        : dueDateForPeriod(
            $r['period_month'],
            $r['start_date'] ?? null,
            $r['rental_type'] ?? 'monthly'
        );
    $activeUntil = $status === 'belum_bayar'
        ? $dueDate
        : activeUntilFromPaidPeriods(
            $r['start_date'] ?? null,
            $r['rental_type'] ?? 'monthly',
            (int)($r['paid_periods'] ?? 0)
        );
    $r['active_until'] = $activeUntil;
    $rows[] = billPayload(
        (string)$r['id'],
        $r['period_month'],
        (float)($r['amount'] ?? $r['price_per_month']),
        $status,
        $r['payment_method'],
        $r['paid_at'],
        $dueDate,
        $r
    );
}
$stmt->close();

$activeRoom = activeRoomForUser($conn, $userId);

$hasPayableBillForActiveRoom = false;
if ($activeRoom !== null) {
    $activeRegId = (string)$activeRoom['registration_id'];
    foreach ($rows as $row) {
        if (($row['status'] ?? '') === 'belum_bayar' &&
            ($row['kosAccessCode'] ?? '') === ($activeRoom['access_code'] ?? '') &&
            ($row['roomNumber'] ?? '') === ($activeRoom['room_number'] ?? '')) {
            $hasPayableBillForActiveRoom = true;
            break;
        }
    }
} else {
    foreach ($rows as $row) {
        if (($row['status'] ?? '') === 'belum_bayar') {
            $hasPayableBillForActiveRoom = true;
            break;
        }
    }
}

if (!$hasPayableBillForActiveRoom) {
    $rows = array_merge(generatedCurrentBill($conn, $userId), $rows);
}

sendJson(true, $rows, 'Tagihan berhasil dimuat');
?>
