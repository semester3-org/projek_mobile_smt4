<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    merchantSendJson(false, null, 'Only POST method allowed', 405);
}

try {
    merchantEnsureSchema($conn);
    $payload = merchantRequireAuth();
    $userId = (string)($payload['sub'] ?? '');
    $body = merchantBody();

    $type = strtolower(trim((string)($body['type'] ?? '')));
    $merchantInput = trim((string)($body['merchantId'] ?? ''));
    $merchantId = merchantResolveMerchantId($conn, $merchantInput);
    $rating = (int)($body['rating'] ?? 0);
    $comment = trim((string)($body['comment'] ?? ''));

    if (!in_array($type, ['laundry', 'catering'], true) || !$merchantId) {
        merchantSendJson(false, null, 'Merchant tidak valid', 400);
    }
    if ($rating < 1 || $rating > 5) {
        merchantSendJson(false, null, 'Rating harus 1 sampai 5', 400);
    }
    if ($comment === '') {
        merchantSendJson(false, null, 'Komentar wajib diisi', 400);
    }

    $stmt = $conn->prepare("
        INSERT INTO merchant_reviews (merchant_id, user_id, rating, comment, created_at, updated_at)
        VALUES (?, ?, ?, ?, NOW(), NOW())
    ");
    if (!$stmt) {
        merchantSendJson(false, null, 'Database error', 500);
    }
    $stmt->bind_param('ssis', $merchantId, $userId, $rating, $comment);
    $stmt->execute();
    $stmt->close();

    $merchant = null;
    $stmt = $conn->prepare('SELECT * FROM merchants WHERE id = ? LIMIT 1');
    if ($stmt) {
        $stmt->bind_param('s', $merchantId);
        $stmt->execute();
        $merchant = $stmt->get_result()->fetch_assoc();
        $stmt->close();
    }
    if ($merchant) {
        merchantSyncPlace($conn, $merchant);
        merchantCreateNotification(
            $conn,
            (string)$merchant['user_id'],
            'Ulasan baru diterima',
            ($payload['displayName'] ?? 'User') . ' memberi rating ' . $rating . ' untuk merchant Anda.',
            'review',
            'Lihat Profil'
        );
    }

    merchantSendJson(true, [
        'type' => $type,
        'merchantId' => $merchantId,
        'rating' => $rating,
    ], 'Ulasan berhasil dikirim');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
