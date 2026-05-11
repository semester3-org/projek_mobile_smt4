<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';

function sendResponse(bool $success, string $message, $data = null, int $code = 200): void {
    http_response_code($code);
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data' => $data,
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse(false, 'Only POST method allowed', null, 405);
}

$payload = JWT::getPayloadFromRequest();
$userId = $payload['sub'] ?? null;
if (!$userId) {
    sendResponse(false, 'Unauthorized', null, 401);
}

$body = json_decode(file_get_contents('php://input'), true);
if (!is_array($body)) {
    sendResponse(false, 'Invalid JSON request', null, 400);
}

$currentPassword = $body['currentPassword'] ?? '';
$newPassword = $body['newPassword'] ?? '';

if ($currentPassword === '' || $newPassword === '') {
    sendResponse(false, 'Password saat ini dan password baru wajib diisi', null, 400);
}
if (strlen($newPassword) < 4) {
    sendResponse(false, 'Password baru minimal 4 karakter', null, 400);
}

$stmt = $conn->prepare('SELECT id, password FROM users WHERE id = ? LIMIT 1');
if (!$stmt) {
    sendResponse(false, 'Database error: ' . $conn->error, null, 500);
}
$stmt->bind_param('s', $userId);
$stmt->execute();
$user = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$user) {
    sendResponse(false, 'User tidak ditemukan', null, 404);
}

$passwordOk = password_verify($currentPassword, $user['password']);
if (!$passwordOk && hash_equals($user['password'], hash('sha256', $currentPassword))) {
    $passwordOk = true;
}

if (!$passwordOk) {
    sendResponse(false, 'Password saat ini tidak cocok', null, 401);
}

$newHash = password_hash($newPassword, PASSWORD_DEFAULT);
if ($newHash === false) {
    sendResponse(false, 'Gagal mengenkripsi password baru', null, 500);
}

$upd = $conn->prepare('UPDATE users SET password = ?, updated_at = NOW() WHERE id = ?');
if (!$upd) {
    sendResponse(false, 'Database error: ' . $conn->error, null, 500);
}
$upd->bind_param('ss', $newHash, $userId);
$upd->execute();
$upd->close();

sendResponse(true, 'Kata sandi berhasil diubah', true);
?>
