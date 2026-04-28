<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../utils/response.php';

// Untuk debugging - catat request
error_log("=== REGISTER REQUEST ===");
error_log("Method: " . $_SERVER['REQUEST_METHOD']);
error_log("Input: " . file_get_contents('php://input'));

try {
    // Only POST allowed
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendError('Only POST method allowed', 405);
    }

    // Get JSON input
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);

    if (!$data) {
        error_log("Invalid JSON: " . $input);
        sendError('Invalid JSON request', 400);
    }

    $email = trim($data['email'] ?? '');
    $password = trim($data['password'] ?? '');
    $displayName = trim($data['displayName'] ?? 'Pengguna');
    $role = trim($data['role'] ?? 'user');

    error_log("Processing register for email: $email, role: $role");

    // Validasi input
    if (empty($email) || empty($password)) {
        sendError('Email dan password harus diisi', 400);
    }

    if (strlen($password) < 4) {
        sendError('Password minimal 4 karakter', 400);
    }

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        sendError('Format email tidak valid', 400);
    }

    if (!in_array($role, ['user', 'owner'])) {
        sendError('Role tidak valid. Gunakan user atau owner', 400);
    }

    // Cek koneksi database
    if (!$conn || $conn->connect_error) {
        error_log("DB Connection failed: " . ($conn->connect_error ?? 'Unknown'));
        sendError('Database connection failed', 500);
    }

    // Check if email already exists
    $checkQuery = "SELECT id FROM users WHERE email = ?";
    $checkStmt = $conn->prepare($checkQuery);

    if (!$checkStmt) {
        error_log("Prepare failed: " . $conn->error);
        sendError('Database error: ' . $conn->error, 500);
    }

    $checkStmt->bind_param("s", $email);
    
    if (!$checkStmt->execute()) {
        error_log("Execute failed: " . $checkStmt->error);
        sendError('Query error: ' . $checkStmt->error, 500);
    }

    $checkResult = $checkStmt->get_result();

    if ($checkResult->num_rows > 0) {
        $checkStmt->close();
        sendError('Email sudah terdaftar', 409);
    }
    $checkStmt->close();

    // Hash password
    if (!function_exists('hashPassword')) {
        function hashPassword($password) {
            return password_hash($password, PASSWORD_DEFAULT);
        }
    }
    
    $passwordHash = hashPassword($password);
    error_log("Password hashed successfully");

    // Insert new user
    $query = "INSERT INTO users (email, password, display_name, role, created_at) VALUES (?, ?, ?, ?, NOW())";
    $stmt = $conn->prepare($query);

    if (!$stmt) {
        error_log("Insert prepare failed: " . $conn->error);
        sendError('Database error: ' . $conn->error, 500);
    }

    $stmt->bind_param("ssss", $email, $passwordHash, $displayName, $role);

    if (!$stmt->execute()) {
        error_log("Insert execute failed: " . $stmt->error);
        sendError('Gagal membuat akun: ' . $stmt->error, 500);
    }

    $userId = $stmt->insert_id;
    $stmt->close();

    error_log("User created successfully with ID: $userId");

    // Success response
    sendSuccess([
        'id' => $userId,
        'email' => $email,
        'displayName' => $displayName,
        'role' => $role
    ], 'Akun berhasil dibuat', 201);

    $conn->close();

} catch (Exception $e) {
    error_log("Exception: " . $e->getMessage());
    sendError('Server error: ' . $e->getMessage(), 500);
}
?>