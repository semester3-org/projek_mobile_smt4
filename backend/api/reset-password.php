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
    
    if (!$data || empty($data['token']) || empty($data['email']) || empty($data['newPassword'])) {
        throw new Exception('Token, email, dan password baru wajib diisi', 400);
    }
    
    $token = trim($data['token']);
    $email = trim($data['email']);
    $newPassword = trim($data['newPassword']);
    
    if (strlen($newPassword) < 4) {
        throw new Exception('Password minimal 4 karakter', 400);
    }
    
    $userQuery = "SELECT id FROM users WHERE email = ? LIMIT 1";
    $userStmt = $conn->prepare($userQuery);
    $userStmt->bind_param("s", $email);
    $userStmt->execute();
    $user = $userStmt->get_result()->fetch_assoc();
    $userStmt->close();

    if (!$user) {
        echo json_encode([
            'success' => false,
            'message' => 'Email tidak terdaftar'
        ]);
        exit();
    }

    $userId = $user['id'];

    // Cek token valid
    $query = "SELECT * FROM password_resets 
              WHERE user_id = ? AND token = ? AND expires_at > NOW() AND used_at IS NULL
              ORDER BY created_at DESC LIMIT 1";
    
    $stmt = $conn->prepare($query);
    if ($stmt) {
        $stmt->bind_param("ss", $userId, $token);
    } else {
        // Fallback untuk skema lama (tanpa user_id/used_at)
        $query = "SELECT * FROM password_resets
                  WHERE email = ? AND token = ? AND expires_at > NOW()
                  ORDER BY created_at DESC LIMIT 1";
        $stmt = $conn->prepare($query);
        if (!$stmt) {
            throw new Exception('Gagal menyiapkan query validasi token');
        }
        $stmt->bind_param("ss", $email, $token);
    }
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        $stmt->close();
        echo json_encode([
            'success' => false,
            'message' => 'Token tidak valid atau sudah kadaluarsa'
        ]);
        exit();
    }
    
    $stmt->close();
    
    // Update password user
    $passwordHash = password_hash($newPassword, PASSWORD_DEFAULT);
    $updateQuery = "UPDATE users SET password = ? WHERE id = ?";
    $updateStmt = $conn->prepare($updateQuery);
    $updateStmt->bind_param("ss", $passwordHash, $userId);
    
    if (!$updateStmt->execute()) {
        throw new Exception('Gagal mengupdate password');
    }
    $updateStmt->close();
    
    // Tandai token sudah digunakan
    $usedQuery = "UPDATE password_resets SET used_at = NOW() WHERE user_id = ?";
    $usedStmt = $conn->prepare($usedQuery);
    if ($usedStmt) {
      $usedStmt->bind_param("s", $userId);
      $usedStmt->execute();
      $usedStmt->close();
    } else {
      $deleteQuery = "DELETE FROM password_resets WHERE email = ?";
      $deleteStmt = $conn->prepare($deleteQuery);
      if ($deleteStmt) {
        $deleteStmt->bind_param("s", $email);
        $deleteStmt->execute();
        $deleteStmt->close();
      }
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Password berhasil direset. Silakan login dengan password baru Anda.'
    ]);
    
} catch (Exception $e) {
    http_response_code($e->getCode() ?: 500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
