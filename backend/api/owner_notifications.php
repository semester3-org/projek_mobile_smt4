<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';

function sendJson(bool $success, $data = null, string $message = '', int $code = 200): void {
    http_response_code($code);
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data' => $data,
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

$payload = JWT::getPayloadFromRequest();
if (!$payload) {
    sendJson(false, null, 'Unauthorized', 401);
}

$ownerId = $payload['sub'] ?? '';
$role = $payload['role'] ?? '';
if (!in_array($role, ['owner', 'admin'], true)) {
    sendJson(false, null, 'Forbidden: hanya owner yang bisa akses', 403);
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'PUT') {
    // Mark specific notification as read
    $body = json_decode(file_get_contents('php://input'), true);
    $notifId = isset($body['id']) ? (int)$body['id'] : 0;
    
    if ($notifId > 0) {
        $stmt = $conn->prepare("UPDATE app_notifications SET read_at = NOW() WHERE id = ? AND user_id = ?");
        $stmt->bind_param('is', $notifId, $ownerId);
        $stmt->execute();
        $stmt->close();
    } else {
        // Mark all as read
        $stmt = $conn->prepare("UPDATE app_notifications SET read_at = NOW() WHERE user_id = ? AND read_at IS NULL");
        $stmt->bind_param('s', $ownerId);
        $stmt->execute();
        $stmt->close();
    }
    
    sendJson(true, true, 'Notifikasi berhasil diperbarui');
} else if ($method === 'GET') {
    // Check if table exists, if not, or if empty, let's create & insert some highly realistic sample notifications for owner
    $checkStmt = $conn->query("SHOW TABLES LIKE 'app_notifications'");
    if ($checkStmt->num_rows === 0) {
        // Create table
        $conn->query("
            CREATE TABLE `app_notifications` (
              `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
              `user_id` varchar(36) NOT NULL,
              `title` varchar(255) NOT NULL,
              `message` text NOT NULL,
              `read_at` timestamp NULL DEFAULT NULL,
              `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
              `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
              PRIMARY KEY (`id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ");
    }

    // Check count for this owner
    $cntStmt = $conn->prepare("SELECT COUNT(*) as total FROM app_notifications WHERE user_id = ?");
    $cntStmt->bind_param('s', $ownerId);
    $cntStmt->execute();
    $cntRes = $cntStmt->get_result()->fetch_assoc();
    $cntStmt->close();

    if ((int)$cntRes['total'] === 0) {
        // Seed some beautiful, personalized default notifications for this owner
        $sampleNotifs = [
            [
                'title' => 'Pembayaran Baru',
                'message' => 'Bukti pembayaran transfer bank telah diterima untuk Kamar A01 sebesar Rp 1.500.000. Mohon segera verifikasi.',
                'hours_offset' => 1
            ],
            [
                'title' => 'Penghuni Baru Terhubung',
                'message' => 'Akun penyewa baru telah berhasil terhubung dengan akses kode properti Kos Hijau Asri Anda.',
                'hours_offset' => 3
            ],
            [
                'title' => 'Pengajuan Kamar',
                'message' => 'Anda menerima pengajuan sewa kamar baru untuk Kamar B01. Segera periksa di tab Approval.',
                'hours_offset' => 5
            ],
            [
                'title' => 'Komplain Perbaikan',
                'message' => 'Laporan dari Kamar D-04 mengenai air keran bocor sedang dalam penanganan teknisi.',
                'hours_offset' => 24
            ]
        ];

        foreach ($sampleNotifs as $sn) {
            $createdTime = date('Y-m-d H:i:s', strtotime("-{$sn['hours_offset']} hours"));
            $insStmt = $conn->prepare("INSERT INTO app_notifications (user_id, title, message, created_at) VALUES (?, ?, ?, ?)");
            $insStmt->bind_param('ssss', $ownerId, $sn['title'], $sn['message'], $createdTime);
            $insStmt->execute();
            $insStmt->close();
        }
    }

    // Fetch all notifications
    $notifStmt = $conn->prepare("
        SELECT id, title, message, read_at, created_at 
        FROM app_notifications 
        WHERE user_id = ?
        ORDER BY created_at DESC
    ");
    $notifStmt->bind_param('s', $ownerId);
    $notifStmt->execute();
    $rows = $notifStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $notifStmt->close();

    $notifications = [];
    foreach ($rows as $row) {
        $category = 'umum';
        $icon = 'info';
        $titleLower = strtolower($row['title']);
        if (strpos($titleLower, 'bayar') !== false) {
            $category = 'pembayaran';
            $icon = 'payment';
        } else if (strpos($titleLower, 'huni') !== false || strpos($titleLower, 'kamar') !== false) {
            $category = 'penghuni';
            $icon = 'person';
        } else if (strpos($titleLower, 'perbaikan') !== false || strpos($titleLower, 'komplain') !== false) {
            $category = 'laporan';
            $icon = 'build';
        }

        // Format friendly time label
        $createdSecs = !empty($row['created_at']) ? strtotime($row['created_at']) : false;
        if ($createdSecs === false) {
            $timeLabel = 'Baru saja';
        } else {
            $diff = time() - $createdSecs;
            if ($diff < 60) {
                $timeLabel = 'Baru saja';
            } else if ($diff < 3600) {
                $timeLabel = floor($diff / 60) . ' menit lalu';
            } else if ($diff < 86400) {
                $timeLabel = floor($diff / 3600) . ' jam lalu';
            } else {
                $timeLabel = date('d M Y', $createdSecs);
            }
        }

        $notifications[] = [
            'id' => (int)$row['id'],
            'title' => $row['title'],
            'subtitle' => $row['message'],
            'time' => $timeLabel,
            'category' => $category,
            'isRead' => !empty($row['read_at']),
        ];
    }

    // De-duplikasi notifikasi pengajuan untuk user/kamar yang sama (hanya menampilkan yang terbaru)
    $seenApprovals = [];
    $filteredNotifications = [];
    foreach ($notifications as $notif) {
        $titleLower = strtolower($notif['title']);
        $msgLower = strtolower($notif['subtitle']);
        
        $isApproval = (strpos($titleLower, 'pengajuan') !== false) || 
                      (strpos($titleLower, 'approval') !== false) || 
                      (strpos($msgLower, 'pengajuan sewa') !== false) ||
                      ($notif['category'] === 'penghuni');
                      
        if ($isApproval) {
            $uniqueKey = '';
            
            // 1. Coba cari nama user: "dari [Nama] untuk Kamar"
            if (preg_match('/dari\s+([a-zA-Z\s]+)\s+untuk\s+kamar/i', $notif['subtitle'], $matches)) {
                $uniqueKey = 'user_' . strtolower(trim($matches[1]));
            }
            // 2. Jika tidak ada, coba cari nomor kamar: "Kamar [Kamar]"
            elseif (preg_match('/kamar\s+([a-zA-Z0-9\-]+)/i', $notif['subtitle'], $matches)) {
                $uniqueKey = 'room_' . strtolower(trim($matches[1]));
            }
            // 3. Jika tidak ada, gunakan teks pesan sebagai fallback
            else {
                $uniqueKey = $notif['subtitle'];
            }
            
            if (isset($seenApprovals[$uniqueKey])) {
                continue; // Lewati jika sudah ada notifikasi yang lebih baru
            }
            $seenApprovals[$uniqueKey] = true;
        }
        
        $filteredNotifications[] = $notif;
    }
    $notifications = $filteredNotifications;

    sendJson(true, $notifications, 'Daftar notifikasi berhasil dimuat');
}
?>
