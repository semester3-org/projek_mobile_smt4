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
        'data'    => $data,
    ]);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse(false, 'Only POST method allowed', null, 405);
}

$input = file_get_contents('php://input');
$body  = json_decode($input, true);

if (!$body) {
    sendResponse(false, 'Invalid JSON request', null, 400);
}

$email    = trim(strtolower($body['email'] ?? ''));
$password = $body['password'] ?? '';

if (empty($email) || empty($password)) {
    sendResponse(false, 'Email dan password wajib diisi', null, 400);
}

// Ambil user berdasarkan email
$stmt = $conn->prepare(
    "SELECT id, email, password, display_name, role FROM users WHERE email = ? LIMIT 1"
);
if (!$stmt) {
    sendResponse(false, 'Database error: ' . $conn->error, null, 500);
}

$stmt->bind_param('s', $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    $stmt->close();
    sendResponse(false, 'Email atau kata sandi tidak cocok. Periksa kembali.', null, 401);
}

$user = $result->fetch_assoc();
$stmt->close();

// ---------------------------------------------------------------
// Verifikasi password — mendukung DUA format:
//
//   1. password_hash() bcrypt  → akun baru via register.php
//   2. SHA-256 hex plain       → akun lama seed phpMyAdmin
//      password akun seed = "password123"
//      password admin     = "1"
//
// Jika cocok format lama, langsung rehash ke bcrypt otomatis.
// ---------------------------------------------------------------
$passwordOk = false;

if (password_verify($password, $user['password'])) {
    // Bcrypt — aman
    $passwordOk = true;

    // Upgrade jika algoritma usang
    if (password_needs_rehash($user['password'], PASSWORD_DEFAULT)) {
        $newHash = password_hash($password, PASSWORD_DEFAULT);
        $up = $conn->prepare("UPDATE users SET password = ? WHERE id = ?");
        if ($up) {
            $up->bind_param('ss', $newHash, $user['id']);
            $up->execute();
            $up->close();
        }
    }
} else {
    // Fallback SHA-256 untuk akun seed lama
    $sha256 = hash('sha256', $password);
    if (hash_equals($user['password'], $sha256)) {
        $passwordOk = true;
        // Rehash ke bcrypt sekarang juga
        $newHash = password_hash($password, PASSWORD_DEFAULT);
        $up = $conn->prepare("UPDATE users SET password = ? WHERE id = ?");
        if ($up) {
            $up->bind_param('ss', $newHash, $user['id']);
            $up->execute();
            $up->close();
        }
    }
}

if (!$passwordOk) {
    sendResponse(false, 'Email atau kata sandi tidak cocok. Periksa kembali.', null, 401);
}

// Generate JWT
$token = JWT::generate([
    'sub'         => $user['id'],
    'email'       => $user['email'],
    'displayName' => $user['display_name'],
    'role'        => $user['role'],
]);

$conn->close();

sendResponse(true, 'Login berhasil', [
    'token'       => $token,
    'id'          => $user['id'],
    'email'       => $user['email'],
    'displayName' => $user['display_name'],
    'role'        => $user['role'],
]);