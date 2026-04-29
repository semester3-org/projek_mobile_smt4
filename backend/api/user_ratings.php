<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Only POST method allowed']);
    exit();
}

$body = json_decode(file_get_contents('php://input'), true);
if (!is_array($body)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid JSON request']);
    exit();
}

$type = strtolower(trim($body['type'] ?? ''));
$merchantId = trim($body['merchantId'] ?? '');
$rating = (int)($body['rating'] ?? 0);
$comment = trim($body['comment'] ?? '');

if (!in_array($type, ['laundry', 'catering', 'cafe'], true) || $merchantId === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Merchant tidak valid']);
    exit();
}

if ($rating < 1 || $rating > 5) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Rating harus 1 sampai 5']);
    exit();
}

if ($comment === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Komentar wajib diisi']);
    exit();
}

echo json_encode([
    'success' => true,
    'message' => 'Ulasan berhasil dikirim',
    'data' => [
        'type' => $type,
        'merchantId' => $merchantId,
        'rating' => $rating,
    ],
], JSON_UNESCAPED_UNICODE);
?>
