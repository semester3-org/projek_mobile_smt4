<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Allow-Credentials: true');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/db.php';

function generateUUID(): string {
    return sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}

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
    sendResponse(false, 'Invalid JSON request. Please send valid JSON.', null, 400);
}

$email       = trim(strtolower($body['email'] ?? ''));
$password    = $body['password'] ?? '';
$displayName = trim($body['displayName'] ?? '');
$role        = trim(strtolower($body['role'] ?? 'user'));

// Validasi
$errors = [];

if (empty($email)) {
    $errors[] = 'Email harus diisi';
} elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    $errors[] = 'Format email tidak valid';
}

if (empty($password)) {
    $errors[] = 'Password harus diisi';
} elseif (strlen($password) < 4) {
    $errors[] = 'Password minimal 4 karakter';
}

if (empty($displayName)) {
    $errors[] = 'Nama lengkap harus diisi';
} elseif (strlen($displayName) < 3) {
    $errors[] = 'Nama lengkap minimal 3 karakter';
}

$allowedRoles = ['user', 'owner', 'merchant'];
if (!in_array($role, $allowedRoles)) {
    $role = 'user';
}

if (!empty($errors)) {
    sendResponse(false, implode(', ', $errors), null, 400);
}

// Cek duplikat email
$checkStmt = $conn->prepare("SELECT id FROM users WHERE email = ? LIMIT 1");
if (!$checkStmt) {
    sendResponse(false, 'Database error: ' . $conn->error, null, 500);
}
$checkStmt->bind_param('s', $email);
$checkStmt->execute();
$checkStmt->store_result();

if ($checkStmt->num_rows > 0) {
    $checkStmt->close();
    sendResponse(false, 'Email sudah terdaftar. Gunakan email lain.', null, 409);
}
$checkStmt->close();

// Hash password pakai bcrypt
$passwordHash = password_hash($password, PASSWORD_DEFAULT);
if ($passwordHash === false) {
    sendResponse(false, 'Gagal mengenkripsi password', null, 500);
}

$userId = generateUUID();

$stmt = $conn->prepare(
    "INSERT INTO users (id, email, password, display_name, role, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, NOW(), NOW())"
);
if (!$stmt) {
    sendResponse(false, 'Database error: ' . $conn->error, null, 500);
}

$stmt->bind_param('sssss', $userId, $email, $passwordHash, $displayName, $role);

if (!$stmt->execute()) {
    sendResponse(false, 'Gagal membuat akun: ' . $stmt->error, null, 500);
}

$stmt->close();
$conn->close();

sendResponse(true, 'Akun berhasil dibuat', [
    'id'          => $userId,
    'email'       => $email,
    'displayName' => $displayName,
    'role'        => $role,
], 201);