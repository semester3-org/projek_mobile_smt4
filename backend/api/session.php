<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Session-Id');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';

function sendSessionResponse(bool $success, string $message, $data = null, int $code = 200): void {
    http_response_code($code);
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data' => $data,
    ]);
    exit();
}

function getBearerToken(): ?string {
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!str_starts_with($authHeader, 'Bearer ')) {
        return null;
    }
    return trim(substr($authHeader, 7));
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

$token = getBearerToken();
if ($token === null || $token === '') {
    sendSessionResponse(false, 'Token tidak ditemukan', null, 401);
}

$payload = JWT::verify($token);
if ($payload === null) {
    sendSessionResponse(false, 'Session sudah berakhir. Silakan login ulang.', null, 401);
}

ensureSessionsTable($conn);
$sessionId = hash('sha256', $token);

if ($_SERVER['REQUEST_METHOD'] === 'DELETE' || $_SERVER['REQUEST_METHOD'] === 'POST') {
    $deleteStmt = $conn->prepare('DELETE FROM sessions WHERE id = ?');
    if ($deleteStmt) {
        $deleteStmt->bind_param('s', $sessionId);
        $deleteStmt->execute();
        $deleteStmt->close();
    }
    sendSessionResponse(true, 'Logout berhasil');
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendSessionResponse(false, 'Only GET, POST, DELETE method allowed', null, 405);
}

$stmt = $conn->prepare(
    "SELECT s.id, u.id AS user_id, u.email, u.display_name, u.role, m.merchant_type
     FROM sessions s
     JOIN users u ON u.id = s.user_id
     LEFT JOIN merchants m ON m.user_id = u.id
     WHERE s.id = ?
     LIMIT 1"
);

if (!$stmt) {
    sendSessionResponse(false, 'Database error: ' . $conn->error, null, 500);
}

$stmt->bind_param('s', $sessionId);
$stmt->execute();
$session = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$session) {
    sendSessionResponse(false, 'Session tidak ditemukan. Silakan login ulang.', null, 401);
}

$updateStmt = $conn->prepare('UPDATE sessions SET last_activity = ? WHERE id = ?');
if ($updateStmt) {
    $lastActivity = time();
    $updateStmt->bind_param('is', $lastActivity, $sessionId);
    $updateStmt->execute();
    $updateStmt->close();
}

$data = [
    'token' => $token,
    'sessionId' => $sessionId,
    'id' => $session['user_id'],
    'email' => $session['email'],
    'displayName' => $session['display_name'],
    'role' => strtolower($session['role'] ?? 'user'),
];

if (!empty($session['merchant_type'])) {
    $data['merchantType'] = $session['merchant_type'];
}

sendSessionResponse(true, 'Session masih aktif', $data);
?>
