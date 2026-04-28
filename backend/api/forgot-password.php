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

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Only POST method allowed', 405);
    }

    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data || empty($data['email'])) {
        throw new Exception('Email harus diisi', 400);
    }
    
    $email = trim($data['email']);
    
    // Cek email ada di database
    $checkQuery = "SELECT id, email FROM users WHERE email = ?";
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
    
    // Generate token unik
    $token = bin2hex(random_bytes(32));
    $expiresAt = date('Y-m-d H:i:s', strtotime('+1 hour'));
    
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
                    VALUES (?, ?, ?, ?, NOW()) 
                    ON DUPLICATE KEY UPDATE 
                    email = VALUES(email),
                    token = VALUES(token), 
                    expires_at = VALUES(expires_at),
                    used_at = NULL,
                    created_at = NOW()";
    
    $insertStmt = $conn->prepare($insertQuery);
    if ($insertStmt) {
        $insertStmt->bind_param("ssss", $user['id'], $email, $token, $expiresAt);
    } else {
        // Fallback untuk skema lama (tanpa user_id/used_at)
        $insertQuery = "INSERT INTO password_resets (email, token, expires_at, created_at) 
                        VALUES (?, ?, ?, NOW()) 
                        ON DUPLICATE KEY UPDATE 
                        token = VALUES(token), 
                        expires_at = VALUES(expires_at),
                        created_at = NOW()";
        $insertStmt = $conn->prepare($insertQuery);
        if (!$insertStmt) {
            throw new Exception('Gagal menyiapkan query reset token');
        }
        $insertStmt->bind_param("sss", $email, $token, $expiresAt);
    }
    
    if (!$insertStmt->execute()) {
        throw new Exception('Gagal menyimpan token reset');
    }
    $insertStmt->close();
    
    // Untuk development, kirim token via response
    // Untuk production, kirim email sungguhan
    echo json_encode([
        'success' => true,
        'message' => 'Token reset password telah dibuat. (Mode Development)',
        'data' => [
            'token' => $token,
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
