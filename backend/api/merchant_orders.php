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
    $merchantId = (string)$merchant['id'];

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $id = trim($_GET['id'] ?? '');
        $status = strtolower(trim($_GET['status'] ?? ''));
        $search = trim($_GET['search'] ?? '');
        $status = in_array($status, ['pending', 'processing', 'done'], true) ? $status : null;

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
            $status = merchantNextStatus($current[0]['status']);
        }

        if ($current[0]['status'] === 'pending' &&
            in_array($status, ['accepted', 'processing', 'delivered', 'done'], true) &&
            empty($current[0]['canApprove'])) {
            merchantSendJson(false, null, 'Pembayaran belum masuk. Pesanan non-COD baru bisa di-approve setelah user mengonfirmasi pembayaran.', 400);
        }

        $allowed = ['pending', 'accepted', 'processing', 'delivered', 'done'];
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

        $updated = merchantOrderQuery($conn, $merchantId, $id);
        $data = $updated[0] ?? $current[0];

        $userId = merchantQueryValue($conn, 'SELECT user_id FROM orders WHERE id = ?', 'i', [(int)$data['id']]);
        if ($userId && $status !== '') {
            merchantCreateNotification(
                $conn,
                (string)$userId,
                'Status pesanan diperbarui',
                $data['code'] . ' sekarang ' . merchantStatusLabel($status) . '.',
                'order',
                'Lihat Detail',
                'order:' . (string)$data['id']
            );
        }

        merchantSendJson(true, $data, 'Pesanan berhasil diperbarui');
    }

    merchantSendJson(false, null, 'Only GET or PUT method allowed', 405);
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
