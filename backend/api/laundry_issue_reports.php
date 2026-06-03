<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/merchant_helpers.php';

function laundryIssueEnsureSchema(mysqli $conn): void {
    if (!merchantTableExists($conn, 'laundry_issue_reports')) {
        $conn->query("
            CREATE TABLE IF NOT EXISTS laundry_issue_reports (
                id INT AUTO_INCREMENT PRIMARY KEY,
                order_id INT NOT NULL,
                user_id VARCHAR(64) NOT NULL,
                merchant_id VARCHAR(64) NOT NULL,
                service_name VARCHAR(180) DEFAULT NULL,
                reason TEXT NOT NULL,
                photo_url LONGTEXT DEFAULT NULL,
                status VARCHAR(30) DEFAULT 'submitted',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                KEY idx_laundry_issue_order (order_id),
                KEY idx_laundry_issue_user (user_id),
                KEY idx_laundry_issue_merchant (merchant_id),
                KEY idx_laundry_issue_status (status)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ");
        return;
    }

    merchantAddColumn($conn, 'laundry_issue_reports', 'service_name', "`service_name` VARCHAR(180) DEFAULT NULL");
    merchantAddColumn($conn, 'laundry_issue_reports', 'reason', "`reason` TEXT DEFAULT NULL");
    merchantAddColumn($conn, 'laundry_issue_reports', 'photo_url', "`photo_url` LONGTEXT DEFAULT NULL");
    merchantAddColumn($conn, 'laundry_issue_reports', 'status', "`status` VARCHAR(30) DEFAULT 'submitted'");
    merchantAddColumn($conn, 'laundry_issue_reports', 'updated_at', "`updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP");
    merchantAddIndex($conn, 'laundry_issue_reports', 'idx_laundry_issue_order', '`order_id`');
    merchantAddIndex($conn, 'laundry_issue_reports', 'idx_laundry_issue_user', '`user_id`');
    merchantAddIndex($conn, 'laundry_issue_reports', 'idx_laundry_issue_merchant', '`merchant_id`');
    merchantAddIndex($conn, 'laundry_issue_reports', 'idx_laundry_issue_status', '`status`');
}

function laundryIssueNotifyAdmins(mysqli $conn, int $orderId, string $orderCode, string $userName): void {
    $admins = $conn->query("SELECT id FROM users WHERE role = 'admin'");
    if (!$admins) return;
    while ($admin = $admins->fetch_assoc()) {
        merchantCreateNotification(
            $conn,
            (string)$admin['id'],
            'Laporan masalah laundry',
            $userName . ' melaporkan masalah pada ' . $orderCode . '.',
            'laundry_report',
            'Lihat Laporan',
            'admin:laundry_report:' . $orderId,
            'high'
        );
    }
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    merchantSendJson(false, null, 'Only POST method allowed', 405);
}

$payload = JWT::getPayloadFromRequest();
if (!$payload || ($payload['role'] ?? '') !== 'user') {
    merchantSendJson(false, null, 'Unauthorized', 401);
}

$userId = (string)($payload['sub'] ?? '');
$body = merchantBody();
$orderId = (int)($body['orderId'] ?? $body['order_id'] ?? 0);
$serviceName = trim((string)($body['serviceName'] ?? $body['service_name'] ?? ''));
$reason = trim((string)($body['reason'] ?? ''));
$photoUrl = trim((string)($body['photoUrl'] ?? $body['photo_url'] ?? ''));

if ($orderId <= 0) {
    merchantSendJson(false, null, 'Order tidak valid', 400);
}
if ($reason === '' || strlen($reason) < 8) {
    merchantSendJson(false, null, 'Alasan laporan minimal 8 karakter', 400);
}

laundryIssueEnsureSchema($conn);

$stmt = $conn->prepare("
    SELECT
        o.id,
        o.order_code,
        o.user_id,
        o.merchant_id,
        o.status,
        o.service_type,
        m.merchant_type,
        m.user_id AS merchant_user_id,
        u.display_name AS user_name
    FROM orders o
    INNER JOIN merchants m ON m.id = o.merchant_id
    INNER JOIN users u ON u.id = o.user_id
    WHERE o.id = ? AND o.user_id = ?
    LIMIT 1
");
if (!$stmt) {
    merchantSendJson(false, null, 'Gagal menyiapkan laporan', 500);
}
$stmt->bind_param('is', $orderId, $userId);
$stmt->execute();
$order = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$order) {
    merchantSendJson(false, null, 'Pesanan tidak ditemukan', 404);
}
if (($order['service_type'] ?? '') !== 'laundry' && ($order['merchant_type'] ?? '') !== 'laundry') {
    merchantSendJson(false, null, 'Laporan ini hanya untuk pesanan laundry', 400);
}
if (!in_array(strtolower((string)$order['status']), ['done', 'completed'], true)) {
    merchantSendJson(false, null, 'Laporan masalah tersedia setelah pesanan selesai', 400);
}

$stmt = $conn->prepare("
    INSERT INTO laundry_issue_reports
        (order_id, user_id, merchant_id, service_name, reason, photo_url, status, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, 'submitted', NOW(), NOW())
");
if (!$stmt) {
    merchantSendJson(false, null, 'Gagal menyimpan laporan', 500);
}
$merchantId = (string)$order['merchant_id'];
$photoValue = $photoUrl !== '' ? $photoUrl : null;
$stmt->bind_param('isssss', $orderId, $userId, $merchantId, $serviceName, $reason, $photoValue);
$stmt->execute();
$reportId = (int)$conn->insert_id;
$stmt->close();

$orderCode = (string)($order['order_code'] ?? ('SR-LAUNDRY-' . $orderId));
$userName = (string)($order['user_name'] ?? 'User');
$merchantUserId = (string)($order['merchant_user_id'] ?? '');
if ($merchantUserId !== '') {
    merchantCreateNotification(
        $conn,
        $merchantUserId,
        'Laporan masalah laundry',
        $userName . ' melaporkan masalah pada ' . $orderCode . '. Mohon cek detail pesanan.',
        'laundry_report',
        'Lihat Pesanan',
        'order:' . $orderId,
        'high'
    );
}
laundryIssueNotifyAdmins($conn, $orderId, $orderCode, $userName);

merchantSendJson(true, [
    'id' => $reportId,
    'orderId' => $orderId,
    'status' => 'submitted',
], 'Laporan masalah laundry berhasil dikirim');

?>
