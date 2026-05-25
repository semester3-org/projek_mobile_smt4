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
require_once __DIR__ . '/../utils/mail_service.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Only POST method allowed', 405);
    }

    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data || empty($data['email'])) {
        throw new Exception('Email harus diisi', 400);
    }
    
    $email = strtolower(trim($data['email']));

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new Exception('Format email tidak valid', 400);
    }
    
    // Cek email ada di database
    $checkQuery = "SELECT id, email, display_name FROM users WHERE email = ?";
    $checkStmt = $conn->prepare($checkQuery);
    $checkStmt->bind_param("s", $email);
    $checkStmt->execute();
    $result = $checkStmt->get_result();
    
    if ($result->num_rows === 0) {
        $checkStmt->close();
        echo json_encode([
            'success' => false,
            'message' => 'Email tidak terdaftar'
        ]);
        exit();
    }
    
    $user = $result->fetch_assoc();
    $checkStmt->close();
    
    // Generate token angka 6 digit agar mudah diketik dari email
    $token = (string) random_int(100000, 999999);
    // Buat tabel password_resets jika belum ada
    $createTable = "CREATE TABLE IF NOT EXISTS password_resets (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        email VARCHAR(255) NOT NULL,
        token VARCHAR(255) NOT NULL,
        expires_at DATETIME NOT NULL,
        used_at DATETIME NULL DEFAULT NULL,
        created_at DATETIME NOT NULL,
        UNIQUE KEY uniq_user_id (user_id),
        INDEX idx_email_token (email, token),
        INDEX idx_expires_at (expires_at),
        CONSTRAINT fk_password_resets_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )";
    $conn->query($createTable);
    
    // Simpan token ke database
    $insertQuery = "INSERT INTO password_resets (user_id, email, token, expires_at, created_at) 
                    VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 1 HOUR), NOW()) 
                    ON DUPLICATE KEY UPDATE 
                    email = VALUES(email),
                    token = VALUES(token), 
                    expires_at = DATE_ADD(NOW(), INTERVAL 1 HOUR),
                    used_at = NULL,
                    created_at = NOW()";
    
    $insertStmt = $conn->prepare($insertQuery);
    if ($insertStmt) {
        $insertStmt->bind_param("sss", $user['id'], $email, $token);
    } else {
        // Fallback untuk skema lama (tanpa user_id/used_at)
        $insertQuery = "INSERT INTO password_resets (email, token, expires_at, created_at) 
                        VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 1 HOUR), NOW()) 
                        ON DUPLICATE KEY UPDATE 
                        token = VALUES(token), 
                        expires_at = DATE_ADD(NOW(), INTERVAL 1 HOUR),
                        created_at = NOW()";
        $insertStmt = $conn->prepare($insertQuery);
        if (!$insertStmt) {
            throw new Exception('Gagal menyiapkan query reset token');
        }
        $insertStmt->bind_param("ss", $email, $token);
    }
    
    if (!$insertStmt->execute()) {
        throw new Exception('Gagal menyimpan token reset');
    }
    $insertStmt->close();

    $displayName = trim($user['display_name'] ?? '');
    if ($displayName === '') {
        $displayName = 'Pengguna';
    }

    $mailConfigError = getResetMailConfigError();
    if ($mailConfigError !== null) {
        throw new Exception($mailConfigError, 500);
    }

    if (!sendResetPasswordEmail($email, $displayName, $token)) {
        throw new Exception('Gagal mengirim email reset password. Periksa konfigurasi SMTP Gmail dan koneksi internet server.', 500);
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Token reset password telah dikirim ke email Anda.',
        'data' => [
            'email' => $email
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code($e->getCode() ?: 500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
