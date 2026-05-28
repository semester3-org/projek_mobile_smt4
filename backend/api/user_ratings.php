<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function userRatingDateLabel(?string $value): string {
    if (!$value) return '';
    return date('d M Y H:i', strtotime($value));
}

function userRatingReviewPayload(array $row): array {
    $editCount = isset($row['edit_count']) ? (int)$row['edit_count'] : 0;
    return [
        'id' => (string)($row['id'] ?? ''),
        'merchantId' => (string)($row['merchant_id'] ?? ''),
        'productId' => isset($row['product_id']) ? (string)$row['product_id'] : '',
        'productName' => $row['nama_produk'] ?? '',
        'reviewer' => $row['display_name'] ?? 'Anda',
        'rating' => (float)($row['rating'] ?? 0),
        'comment' => $row['comment'] ?? '',
        'timeLabel' => userRatingDateLabel($row['created_at'] ?? null),
        'createdAt' => $row['created_at'] ?? '',
        'updatedAt' => $row['updated_at'] ?? '',
        'deletedAt' => $row['deleted_at'] ?? '',
        'isDeleted' => !empty($row['deleted_at']),
        'editCount' => $editCount,
        'remainingEditAttempts' => max(0, 3 - $editCount),
    ];
}

function userRatingPurchasedProducts(mysqli $conn, string $userId, string $merchantId): array {
    if (!merchantTableExists($conn, 'orders') || !merchantTableExists($conn, 'order_items')) {
        return [];
    }
    $stmt = $conn->prepare("
        SELECT DISTINCT p.id, p.nama_produk
        FROM orders o
        INNER JOIN order_items oi ON oi.order_id = o.id
        INNER JOIN products p ON p.id = oi.product_id
        WHERE o.user_id = ?
          AND o.merchant_id = ?
          AND (
            o.status = 'done'
            OR (
              o.service_type = 'catering'
              AND o.status = 'accepted'
              AND COALESCE(o.payment_status, '') IN ('paid','payment_submitted')
              AND COALESCE(o.subscription_status, '') IN ('active','cancel_requested')
            )
          )
        ORDER BY p.nama_produk ASC
    ");
    if (!$stmt) return [];
    $stmt->bind_param('ss', $userId, $merchantId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return array_map(fn($row) => [
        'id' => (string)$row['id'],
        'name' => $row['nama_produk'] ?? 'Produk',
    ], $rows);
}

function userRatingMyReviews(mysqli $conn, string $userId, string $merchantId): array {
    if (!merchantTableExists($conn, 'merchant_reviews')) {
        return [];
    }
    $stmt = $conn->prepare("
        SELECT mr.*, u.display_name, p.nama_produk
        FROM merchant_reviews mr
        LEFT JOIN users u ON u.id = mr.user_id
        LEFT JOIN products p ON p.id = mr.product_id
        WHERE mr.user_id = ? AND mr.merchant_id = ?
        ORDER BY COALESCE(mr.deleted_at, mr.updated_at, mr.created_at) DESC, mr.id DESC
    ");
    if (!$stmt) return [];
    $stmt->bind_param('ss', $userId, $merchantId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return array_map('userRatingReviewPayload', $rows);
}

function userRatingState(mysqli $conn, string $userId, string $merchantId): array {
    return [
        'reviewableProducts' => userRatingPurchasedProducts($conn, $userId, $merchantId),
        'myReviews' => userRatingMyReviews($conn, $userId, $merchantId),
    ];
}

function userRatingActiveReview(mysqli $conn, string $userId, string $merchantId, int $productId): ?array {
    $stmt = $conn->prepare("
        SELECT mr.*, u.display_name, p.nama_produk
        FROM merchant_reviews mr
        LEFT JOIN users u ON u.id = mr.user_id
        LEFT JOIN products p ON p.id = mr.product_id
        WHERE mr.user_id = ? AND mr.merchant_id = ? AND mr.product_id = ? AND mr.deleted_at IS NULL
        ORDER BY mr.id DESC
        LIMIT 1
    ");
    if (!$stmt) return null;
    $stmt->bind_param('ssi', $userId, $merchantId, $productId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

function userRatingCanReviewProduct(mysqli $conn, string $userId, string $merchantId, int $productId): bool {
    $stmt = $conn->prepare("
        SELECT oi.id
        FROM orders o
        INNER JOIN order_items oi ON oi.order_id = o.id
        WHERE o.user_id = ?
          AND o.merchant_id = ?
          AND (
            o.status = 'done'
            OR (
              o.service_type = 'catering'
              AND o.status = 'accepted'
              AND COALESCE(o.payment_status, '') IN ('paid','payment_submitted')
              AND COALESCE(o.subscription_status, '') IN ('active','cancel_requested')
            )
          )
          AND oi.product_id = ?
        LIMIT 1
    ");
    if (!$stmt) return false;
    $stmt->bind_param('ssi', $userId, $merchantId, $productId);
    $stmt->execute();
    $exists = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return (bool)$exists;
}

try {
    merchantEnsureSchema($conn);
    $payload = merchantRequireAuth();
    $userId = (string)($payload['sub'] ?? '');
    if ($userId === '') {
        merchantSendJson(false, null, 'User tidak valid', 401);
    }

    $body = merchantBody();
    $type = strtolower(trim((string)($body['type'] ?? $_GET['type'] ?? '')));
    $merchantInput = trim((string)($body['merchantId'] ?? $_GET['merchantId'] ?? ''));
    $merchantId = merchantResolveMerchantId($conn, $merchantInput);

    if (!in_array($type, ['laundry', 'catering'], true) || !$merchantId) {
        merchantSendJson(false, null, 'Merchant tidak valid', 400);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        merchantSendJson(true, userRatingState($conn, $userId, $merchantId), 'Data ulasan berhasil dimuat');
    }

    $productId = (int)($body['productId'] ?? $_GET['productId'] ?? 0);
    if ($productId <= 0) {
        merchantSendJson(false, null, 'Pilih produk yang pernah dibeli', 400);
    }
    if (!userRatingCanReviewProduct($conn, $userId, $merchantId, $productId)) {
        merchantSendJson(false, null, 'Ulasan hanya bisa dikirim setelah produk pernah dibeli dan pesanan selesai', 403);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        $review = userRatingActiveReview($conn, $userId, $merchantId, $productId);
        if (!$review) {
            merchantSendJson(false, null, 'Ulasan aktif tidak ditemukan', 404);
        }
        $stmt = $conn->prepare("
            UPDATE merchant_reviews
            SET deleted_at = NOW(), updated_at = NOW()
            WHERE id = ? AND user_id = ? AND merchant_id = ? AND product_id = ?
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $reviewId = (int)$review['id'];
        $stmt->bind_param('issi', $reviewId, $userId, $merchantId, $productId);
        $stmt->execute();
        $stmt->close();
        $merchant = null;
        $merchantStmt = $conn->prepare('SELECT * FROM merchants WHERE id = ? LIMIT 1');
        if ($merchantStmt) {
            $merchantStmt->bind_param('s', $merchantId);
            $merchantStmt->execute();
            $merchant = $merchantStmt->get_result()->fetch_assoc();
            $merchantStmt->close();
        }
        if ($merchant) {
            merchantSyncPlace($conn, $merchant);
        }
        merchantSendJson(true, userRatingState($conn, $userId, $merchantId), 'Ulasan berhasil dihapus');
    }

    $rating = (int)($body['rating'] ?? 0);
    $comment = trim((string)($body['comment'] ?? ''));
    if ($rating < 1 || $rating > 5) {
        merchantSendJson(false, null, 'Rating harus 1 sampai 5', 400);
    }
    if ($comment === '') {
        merchantSendJson(false, null, 'Komentar wajib diisi', 400);
    }

    $existing = userRatingActiveReview($conn, $userId, $merchantId, $productId);
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        if ($existing) {
            merchantSendJson(false, null, 'Produk ini sudah pernah Anda ulas. Gunakan edit untuk memperbarui ulasan.', 409);
        }
        $stmt = $conn->prepare("
            INSERT INTO merchant_reviews (merchant_id, user_id, product_id, rating, comment, edit_count, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, 0, NOW(), NOW())
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param('ssiis', $merchantId, $userId, $productId, $rating, $comment);
        $stmt->execute();
        $stmt->close();
    } elseif ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        if (!$existing) {
            merchantSendJson(false, null, 'Ulasan aktif tidak ditemukan', 404);
        }
        $currentEditCount = isset($existing['edit_count']) ? (int)$existing['edit_count'] : 0;
        if ($currentEditCount >= 3) {
            merchantSendJson(false, null, 'Batas edit ulasan telah tercapai', 403);
        }
        $reviewId = (int)$existing['id'];
        $stmt = $conn->prepare("
            UPDATE merchant_reviews
            SET rating = ?, comment = ?, updated_at = NOW(), edit_count = edit_count + 1
            WHERE id = ? AND user_id = ? AND merchant_id = ? AND product_id = ? AND deleted_at IS NULL
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Database error', 500);
        }
        $stmt->bind_param('isissi', $rating, $comment, $reviewId, $userId, $merchantId, $productId);
        $stmt->execute();
        $stmt->close();
    } else {
        merchantSendJson(false, null, 'Only GET, POST, PUT, or DELETE method allowed', 405);
    }

    $merchant = null;
    $stmt = $conn->prepare('SELECT * FROM merchants WHERE id = ? LIMIT 1');
    if ($stmt) {
        $stmt->bind_param('s', $merchantId);
        $stmt->execute();
        $merchant = $stmt->get_result()->fetch_assoc();
        $stmt->close();
    }
    if ($merchant) {
        merchantSyncPlace($conn, $merchant);
        merchantCreateNotification(
            $conn,
            (string)$merchant['user_id'],
            $_SERVER['REQUEST_METHOD'] === 'PUT' ? 'Ulasan diperbarui' : 'Ulasan baru diterima',
            ($payload['displayName'] ?? 'User') . ' memberi rating ' . $rating . ' untuk produk merchant Anda.',
            'review',
            'Lihat Profil'
        );
    }

    merchantSendJson(true, userRatingState($conn, $userId, $merchantId), $_SERVER['REQUEST_METHOD'] === 'PUT'
        ? 'Ulasan berhasil diperbarui'
        : 'Ulasan berhasil dikirim');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
