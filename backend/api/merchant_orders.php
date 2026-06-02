<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    $payload = merchantRequireMerchant();
    $merchant = merchantCurrent($conn, $payload);
    merchantExpireFinishedCateringSubscriptions($conn);
    $merchantId = (string)$merchant['id'];

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $id = trim($_GET['id'] ?? '');
        $status = strtolower(trim($_GET['status'] ?? ''));
        $search = trim($_GET['search'] ?? '');
        $status = in_array($status, ['pending', 'waiting_payment', 'today_delivery', 'processing', 'done'], true) ? $status : null;

        if (($_GET['sync'] ?? '') === '1' && $id === '' && $status === null && $search === '') {
            $stmt = $conn->prepare("
                SELECT id, order_code, status, payment_status, total_harga,
                       updated_at, laundry_weight_kg, subtotal_amount,
                       promo_discount_amount
                FROM orders
                WHERE merchant_id = ?
                  AND (COALESCE(extension_parent_order_id, 0) = 0 OR status <> 'done')
                ORDER BY updated_at DESC, id DESC
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Database error', 500);
            }
            $stmt->bind_param('s', $merchantId);
            $stmt->execute();
            $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            $stmt->close();
            $data = array_map(fn($row) => [
                'id' => (string)($row['id'] ?? ''),
                'code' => (string)($row['order_code'] ?? ''),
                'status' => (string)($row['status'] ?? ''),
                'paymentStatus' => (string)($row['payment_status'] ?? ''),
                'totalAmount' => (float)($row['total_harga'] ?? 0),
                'updatedAt' => $row['updated_at'] ?? null,
                'actualWeight' => isset($row['laundry_weight_kg']) ? (float)$row['laundry_weight_kg'] : null,
                'subtotalAmount' => (float)($row['subtotal_amount'] ?? 0),
                'promoDiscountAmount' => (float)($row['promo_discount_amount'] ?? 0),
            ], $rows);
            merchantSendJson(true, $data, 'Sinkronisasi pesanan merchant berhasil');
        }

        $pendingActivation = $conn->prepare("
            SELECT id
            FROM orders
            WHERE merchant_id = ?
              AND service_type = 'catering'
              AND status = 'accepted'
              AND COALESCE(payment_status, '') IN ('paid','payment_submitted')
              AND (subscription_start_date IS NULL OR subscription_end_date IS NULL)
        ");
        if ($pendingActivation) {
            $pendingActivation->bind_param('s', $merchantId);
            $pendingActivation->execute();
            $rows = $pendingActivation->get_result()->fetch_all(MYSQLI_ASSOC);
            $pendingActivation->close();
            foreach ($rows as $row) {
                merchantActivateCateringSubscription($conn, (int)($row['id'] ?? 0));
            }
        }

        $activeToday = $conn->prepare("
            SELECT id
            FROM orders
            WHERE merchant_id = ?
              AND service_type = 'catering'
              AND status = 'accepted'
              AND COALESCE(payment_status, '') IN ('paid','payment_submitted')
              AND subscription_start_date <= CURDATE()
              AND subscription_end_date >= CURDATE()
        ");
        if ($activeToday) {
            $activeToday->bind_param('s', $merchantId);
            $activeToday->execute();
            $rows = $activeToday->get_result()->fetch_all(MYSQLI_ASSOC);
            $activeToday->close();
            foreach ($rows as $row) {
                merchantEnsureCateringDeliveryLogs($conn, (int)($row['id'] ?? 0));
            }
        }

        $orders = merchantOrderQuery(
            $conn,
            $merchantId,
            $id !== '' ? $id : null,
            $status,
            $search !== '' ? $search : null
        );

        if ($id !== '') {
            if (empty($orders)) {
                merchantSendJson(false, null, 'Pesanan tidak ditemukan', 404);
            }
            merchantSendJson(true, $orders[0], 'Detail pesanan berhasil dimuat');
        }

        merchantSendJson(true, $orders, 'Pesanan merchant berhasil dimuat');
    }

    if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        $body = merchantBody();
        $id = trim((string)($body['id'] ?? ''));
        $status = strtolower(trim((string)($body['status'] ?? '')));
        $estimatedTime = trim((string)($body['estimatedTime'] ?? ''));
        $action = strtolower(trim((string)($body['action'] ?? '')));

        if ($id === '') {
            merchantSendJson(false, null, 'ID pesanan wajib diisi', 400);
        }

        $current = merchantOrderQuery($conn, $merchantId, $id);
        if (empty($current)) {
            merchantSendJson(false, null, 'Pesanan tidak ditemukan', 404);
        }

        if ($action === 'next') {
            if (strtolower((string)($current[0]['paymentStatus'] ?? '')) === 'cancelled' ||
                strtolower((string)($current[0]['statusGroup'] ?? '')) === 'cancelled') {
                merchantSendJson(false, null, 'Pesanan dibatalkan tidak bisa diproses', 400);
            }
            $isCatering = strtolower((string)($current[0]['serviceType'] ?? '')) === 'catering';
            $isLaundry = !$isCatering;
            $currentStatus = strtolower((string)($current[0]['status'] ?? ''));
            $paymentStatus = strtolower((string)($current[0]['paymentStatus'] ?? ''));
            if ($isLaundry && $currentStatus === 'accepted') {
                if ($paymentStatus === 'awaiting_weighing' || (float)($current[0]['totalAmount'] ?? 0) <= 0) {
                    merchantSendJson(false, null, 'Lengkapi penimbangan dan total pembayaran terlebih dahulu', 400);
                }
                if (in_array($paymentStatus, ['waiting_payment', 'unpaid'], true)) {
                    merchantSendJson(false, null, 'Pesanan masih menunggu pembayaran user', 400);
                }
            }
            $status = merchantNextStatus($current[0]['status'], $isCatering);
        }

        if ($action === 'set_laundry_total') {
            $weightKg = (float)($body['weightKg'] ?? 0);
            $totalAmount = (float)($body['totalAmount'] ?? 0);
            $addonIds = is_array($body['addonIds'] ?? null) ? $body['addonIds'] : [];
            $orderIdInt = (int)($current[0]['id'] ?? 0);
            merchantFinalizeLaundryOrder(
                $conn,
                $orderIdInt,
                $merchantId,
                $weightKg,
                $totalAmount,
                $addonIds
            );
            $updated = merchantOrderQuery($conn, $merchantId, $id);
            merchantSendJson(true, $updated[0] ?? $current[0], 'Total laundry berhasil disimpan');
        }

        if ($action === 'complete_delivery') {
            $logId = (int)($body['deliveryLogId'] ?? 0);
            $deliveryNote = trim((string)($body['deliveryNote'] ?? ''));
            $deliveryPhotoUrl = trim((string)($body['deliveryPhotoUrl'] ?? ''));
            if ($logId <= 0) {
                merchantSendJson(false, null, 'ID pengantaran wajib diisi', 400);
            }
            if (mb_strlen($deliveryNote) > 500) {
                merchantSendJson(false, null, 'Catatan pengantaran maksimal 500 karakter', 400);
            }
            if ($deliveryPhotoUrl !== '' && !preg_match('/^data:image\/(jpeg|jpg|png|webp);base64,/', $deliveryPhotoUrl)) {
                merchantSendJson(false, null, 'Foto bukti harus berupa gambar JPG, PNG, atau WEBP', 400);
            }
            if (strtolower((string)($current[0]['serviceType'] ?? '')) !== 'catering') {
                merchantSendJson(false, null, 'Validasi pengantaran hanya untuk pesanan catering', 400);
            }
            if (strtolower((string)($current[0]['status'] ?? '')) !== 'accepted') {
                merchantSendJson(false, null, 'Pesanan belum aktif untuk pengantaran', 400);
            }
            if (!in_array(strtolower((string)($current[0]['paymentStatus'] ?? '')), ['paid', 'payment_submitted'], true)) {
                merchantSendJson(false, null, 'Pengantaran hanya bisa diselesaikan setelah pembayaran masuk', 400);
            }
            if (!merchantTableExists($conn, 'catering_delivery_logs')) {
                merchantSendJson(false, null, 'Tabel pengantaran catering belum tersedia', 500);
            }
            $orderIdInt = (int)($current[0]['id'] ?? 0);
            $logStmt = $conn->prepare("
                SELECT id, delivery_date, scheduled_time, slot_number, status
                FROM catering_delivery_logs
                WHERE id = ? AND merchant_id = ? AND order_id = ?
                LIMIT 1
            ");
            if (!$logStmt) {
                merchantSendJson(false, null, 'Database error', 500);
            }
            $logStmt->bind_param('isi', $logId, $merchantId, $orderIdInt);
            $logStmt->execute();
            $logRow = $logStmt->get_result()->fetch_assoc();
            $logStmt->close();
            if (!$logRow) {
                merchantSendJson(false, null, 'Data pengantaran tidak ditemukan', 404);
            }
            if (($logRow['status'] ?? '') === 'delivered') {
                $updated = merchantOrderQuery($conn, $merchantId, $id);
                merchantSendJson(true, $updated[0] ?? $current[0], 'Pengantaran sudah selesai');
            }
            $deliveryDate = (string)($logRow['delivery_date'] ?? date('Y-m-d'));
            if ($deliveryDate !== date('Y-m-d')) {
                merchantSendJson(false, null, 'Hanya pengantaran hari ini yang bisa diselesaikan', 400);
            }
            $scheduledTime = trim((string)($logRow['scheduled_time'] ?? ''));
            if (preg_match('/^\d{2}:\d{2}$/', $scheduledTime)) {
                $scheduledAt = strtotime($deliveryDate . ' ' . $scheduledTime . ':00');
                if ($scheduledAt !== false && time() < ($scheduledAt - (15 * 60))) {
                    merchantSendJson(false, null, 'Pengantaran belum masuk waktunya. Tombol selesai aktif maksimal 15 menit sebelum jadwal.', 400);
                }
            }
            $slotNumber = (int)($logRow['slot_number'] ?? 1);
            if ($slotNumber > 1) {
                $previousStmt = $conn->prepare("
                    SELECT COUNT(*) AS total
                    FROM catering_delivery_logs
                    WHERE merchant_id = ?
                      AND order_id = ?
                      AND delivery_date = ?
                      AND slot_number < ?
                      AND status <> 'delivered'
                ");
                if (!$previousStmt) {
                    merchantSendJson(false, null, 'Database error', 500);
                }
                $previousStmt->bind_param('sisi', $merchantId, $orderIdInt, $deliveryDate, $slotNumber);
                $previousStmt->execute();
                $previousRow = $previousStmt->get_result()->fetch_assoc();
                $previousStmt->close();
                if ((int)($previousRow['total'] ?? 0) > 0) {
                    merchantSendJson(false, null, 'Pengantaran sebelumnya belum selesai. Selesaikan berurutan agar tidak ada pengiriman yang terlewat.', 400);
                }
            }
            $stmt = $conn->prepare("
                UPDATE catering_delivery_logs
                SET status = 'delivered',
                    delivered_at = NOW(),
                    delivery_note = NULLIF(?, ''),
                    delivery_photo_url = NULLIF(?, ''),
                    updated_at = NOW()
                WHERE id = ? AND merchant_id = ? AND order_id = ?
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Database error', 500);
            }
            $stmt->bind_param('ssisi', $deliveryNote, $deliveryPhotoUrl, $logId, $merchantId, $orderIdInt);
            $stmt->execute();
            $stmt->close();

            $userId = merchantQueryValue($conn, 'SELECT user_id FROM orders WHERE id = ?', 'i', [$orderIdInt]);
            if ($userId) {
                $orderCode = (string)($current[0]['code'] ?? ('#' . $orderIdInt));
                $slotText = $slotNumber > 1 ? ' sesi ' . $slotNumber : '';
                merchantCreateNotification(
                    $conn,
                    (string)$userId,
                    'Pengantaran catering selesai',
                    $orderCode . ' pengantaran hari ini' . $slotText . ' sudah ditandai selesai oleh merchant.',
                    'order',
                    'Lihat Detail',
                    'order:' . (string)$orderIdInt,
                    'high'
                );
            }

            $updated = merchantOrderQuery($conn, $merchantId, $id);
            merchantSendJson(true, $updated[0] ?? $current[0], 'Pengantaran berhasil ditandai selesai');
        }

        if ($action === 'reject_order') {
            $reason = trim((string)($body['reason'] ?? ''));
            if ($reason === '') {
                merchantSendJson(false, null, 'Alasan penolakan wajib diisi', 400);
            }
            if (($current[0]['status'] ?? '') !== 'pending') {
                merchantSendJson(false, null, 'Hanya pesanan pending yang bisa ditolak', 400);
            }
            $orderIdInt = (int)($current[0]['id'] ?? 0);
            $note = "\n[Ditolak merchant] " . $reason;
            $stmt = $conn->prepare("
                UPDATE orders
                SET payment_status = 'cancelled',
                    subscription_status = IF(service_type = 'catering', 'cancelled', subscription_status),
                    cancellation_requested_at = IF(service_type = 'catering', NOW(), cancellation_requested_at),
                    notes = CONCAT(COALESCE(notes, ''), ?),
                    updated_at = NOW()
                WHERE id = ? AND merchant_id = ?
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Database error', 500);
            }
            $stmt->bind_param('sis', $note, $orderIdInt, $merchantId);
            $stmt->execute();
            $stmt->close();

            $userId = merchantQueryValue($conn, 'SELECT user_id FROM orders WHERE id = ?', 'i', [$orderIdInt]);
            if ($userId) {
                merchantCreateNotification(
                    $conn,
                    (string)$userId,
                    'Pesanan ditolak merchant',
                    ($current[0]['code'] ?? ('#' . $orderIdInt)) . ' ditolak. Alasan: ' . $reason,
                    'order',
                    'Lihat Detail',
                    'order:' . (string)$orderIdInt,
                    'high'
                );
            }

            $updated = merchantOrderQuery($conn, $merchantId, $id);
            merchantSendJson(true, $updated[0] ?? $current[0], 'Pesanan berhasil ditolak');
        }

        if ($current[0]['status'] === 'pending' &&
            in_array($status, ['accepted', 'processing', 'delivered', 'done'], true) &&
            empty($current[0]['canApprove'])) {
            merchantSendJson(false, null, 'Pembayaran belum masuk. Pesanan non-COD baru bisa di-approve setelah user mengonfirmasi pembayaran.', 400);
        }

        $isCateringOrder = strtolower((string)($current[0]['serviceType'] ?? '')) === 'catering';
        $allowed = $isCateringOrder
            ? ['pending', 'accepted', 'done']
            : ['pending', 'accepted', 'processing', 'delivered', 'done'];
        if ($status !== '' && !in_array($status, $allowed, true)) {
            merchantSendJson(false, null, 'Status pesanan tidak valid', 400);
        }

        $sets = [];
        $types = '';
        $params = [];
        if ($status !== '') {
            $sets[] = 'status = ?';
            $types .= 's';
            $params[] = $status;
        }
        if ($estimatedTime !== '') {
            $sets[] = 'estimated_time = ?';
            $types .= 's';
            $params[] = $estimatedTime;
        }
        if (empty($sets)) {
            merchantSendJson(false, null, 'Tidak ada perubahan yang dikirim', 400);
        }

        $sets[] = 'updated_at = NOW()';
        $stmt = $conn->prepare("
            UPDATE orders
            SET " . implode(', ', $sets) . "
            WHERE (CAST(id AS CHAR) = ? OR order_code = ?)
              AND merchant_id = ?
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }

        $types .= 'sss';
        $params[] = $id;
        $params[] = $id;
        $params[] = $merchantId;

        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $stmt->close();

        $orderIdInt = (int)($current[0]['id'] ?? 0);
        if ($orderIdInt > 0 &&
            in_array($status, ['accepted', 'processing', 'delivered', 'done'], true) &&
            strtolower((string)($current[0]['serviceType'] ?? '')) === 'catering') {
            $payment = strtolower((string)($current[0]['paymentStatus'] ?? ''));
            if (in_array($payment, ['paid', 'payment_submitted'], true)) {
                merchantActivateCateringSubscription($conn, $orderIdInt);
            }
        }

        $updated = merchantOrderQuery($conn, $merchantId, $id);
        $data = $updated[0] ?? $current[0];

        $userId = merchantQueryValue($conn, 'SELECT user_id FROM orders WHERE id = ?', 'i', [(int)$data['id']]);
        if ($userId && $status !== '') {
            $serviceType = strtolower((string)($data['serviceType'] ?? $current[0]['serviceType'] ?? ''));
            $code = (string)($data['code'] ?? ('#' . $data['id']));
            $title = 'Status pesanan diperbarui';
            $message = $code . ' sekarang ' . merchantStatusLabel($status) . '.';
            $importance = 'normal';

            if ($serviceType === 'laundry') {
                $importance = in_array($status, ['accepted', 'processing', 'delivered', 'done'], true)
                    ? 'high'
                    : 'normal';
                if ($status === 'accepted') {
                    $title = 'Pesanan laundry diterima';
                    $message = 'Merchant telah menerima ' . $code . '. Pesanan akan masuk ke tahap berikutnya.';
                } elseif ($status === 'processing') {
                    $title = 'Laundry sedang diproses';
                    $message = $code . ' sedang diproses oleh merchant.';
                } elseif ($status === 'delivered') {
                    $title = 'Laundry siap diantar';
                    $message = $code . ' sudah siap diantar ke alamat tujuan.';
                } elseif ($status === 'done') {
                    $title = 'Laundry selesai';
                    $message = $code . ' sudah selesai. Terima kasih sudah menggunakan layanan laundry.';
                }
            } elseif ($serviceType === 'catering') {
                $importance = in_array($status, ['accepted', 'done'], true)
                    ? 'high'
                    : 'normal';
                if ($status === 'accepted') {
                    $title = 'Pesanan catering diterima';
                    $message = 'Merchant telah menerima ' . $code . '. Silakan lanjutkan pembayaran jika belum dibayar.';
                } elseif ($status === 'done') {
                    $title = 'Pesanan catering selesai';
                    $message = $code . ' sudah ditandai selesai oleh merchant.';
                }
            }

            merchantCreateNotification(
                $conn,
                (string)$userId,
                $title,
                $message,
                'order',
                'Lihat Detail',
                'order:' . (string)$data['id'],
                $importance
            );
        }

        merchantSendJson(true, $data, 'Pesanan berhasil diperbarui');
    }

    merchantSendJson(false, null, 'Only GET or PUT method allowed', 405);
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
