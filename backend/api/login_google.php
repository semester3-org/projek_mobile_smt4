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

function ensureSessionsTable(mysqli $conn): void {
    $conn->query("CREATE TABLE IF NOT EXISTS sessions (
        id varchar(255) NOT NULL,
        user_id varchar(36) DEFAULT NULL,
        ip_address varchar(45) DEFAULT NULL,
        user_agent text,
        payload longtext NOT NULL,
        last_activity int NOT NULL,
        PRIMARY KEY (id),
        KEY sessions_user_id_index (user_id),
        KEY sessions_last_activity_index (last_activity)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

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

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendResponse(false, 'Only POST method allowed', null, 405);
}

$input = file_get_contents('php://input');
$body  = json_decode($input, true);

if (!$body) {
    sendResponse(false, 'Invalid JSON request', null, 400);
}

$email       = trim(strtolower($body['email'] ?? ''));
$displayName = trim($body['displayName'] ?? '');
$photoUrl    = trim($body['photoUrl'] ?? '');

if (empty($email)) {
    sendResponse(false, 'Email wajib diisi', null, 400);
}

// Cek apakah user sudah terdaftar di MySQL berdasarkan email
$stmt = $conn->prepare(
    "SELECT u.id, u.email, u.display_name, u.role, m.merchant_type
     FROM users u 
     LEFT JOIN merchants m ON u.id = m.user_id
     WHERE u.email = ? LIMIT 1"
);
if (!$stmt) {
    sendResponse(false, 'Database error: ' . $conn->error, null, 500);
}

$stmt->bind_param('s', $email);
$stmt->execute();
$result = $stmt->get_result();

$user = null;
if ($result->num_rows > 0) {
    // User exists, update photo_url if provided
    $user = $result->fetch_assoc();
    $stmt->close();
    
    if (!empty($photoUrl)) {
        $updateStmt = $conn->prepare("UPDATE users SET photo_url = ?, updated_at = NOW() WHERE id = ?");
        if ($updateStmt) {
            $updateStmt->bind_param('ss', $photoUrl, $user['id']);
            $updateStmt->execute();
            $updateStmt->close();
        }
    }
} else {
    // User does not exist, register them
    $stmt->close();
    
    $userId = generateUUID();
    $role = 'user'; // default role
    // Create random hashed password as it's NOT NULL in db schema
    $dummyPassword = password_hash(bin2hex(random_bytes(16)), PASSWORD_DEFAULT);
    
    $insertStmt = $conn->prepare(
        "INSERT INTO users (id, email, password, display_name, role, photo_url, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())"
    );
    if (!$insertStmt) {
        sendResponse(false, 'Database error: ' . $conn->error, null, 500);
    }
    
    $insertStmt->bind_param('ssssss', $userId, $email, $dummyPassword, $displayName, $role, $photoUrl);
    if (!$insertStmt->execute()) {
        sendResponse(false, 'Gagal menyimpan data ke MySQL: ' . $insertStmt->error, null, 500);
    }
    $insertStmt->close();
    
    // Set user info to return
    $user = [
        'id' => $userId,
        'email' => $email,
        'display_name' => $displayName,
        'role' => $role,
        'merchant_type' => null,
    ];
}

$role = strtolower(trim($user['role'] ?? 'user'));
$merchantType = $user['merchant_type'] ?? null;

// Generate JWT
$token = JWT::generate([
    'sub'          => $user['id'],
    'email'        => $user['email'],
    'displayName'  => $user['display_name'],
    'role'         => $role,
    'merchantType' => $merchantType,
]);

$sessionId = hash('sha256', $token);
ensureSessionsTable($conn);
$sessionPayload = json_encode([
    'email' => $user['email'],
    'displayName' => $user['display_name'],
    'role' => $role,
    'merchantType' => $merchantType,
], JSON_UNESCAPED_UNICODE);
$ipAddress = $_SERVER['REMOTE_ADDR'] ?? null;
$userAgent = $_SERVER['HTTP_USER_AGENT'] ?? null;
$lastActivity = time();

$sessionStmt = $conn->prepare(
    "REPLACE INTO sessions (id, user_id, ip_address, user_agent, payload, last_activity)
     VALUES (?, ?, ?, ?, ?, ?)"
);
if ($sessionStmt) {
    $sessionStmt->bind_param(
        'sssssi',
        $sessionId,
        $user['id'],
        $ipAddress,
        $userAgent,
        $sessionPayload,
        $lastActivity
    );
    $sessionStmt->execute();
    $sessionStmt->close();
}

$conn->close();

$responseData = [
    'token'        => $token,
    'sessionId'    => $sessionId,
    'id'           => $user['id'],
    'email'        => $user['email'],
    'displayName'  => $user['display_name'],
    'role'         => $role,
];

if ($merchantType) {
    $responseData['merchantType'] = $merchantType;
}

sendResponse(true, 'Login Google berhasil', $responseData);
