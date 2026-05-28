<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    merchantSendJson(false, null, 'Only GET method allowed', 405);
}

function merchantReviewPayloadForProduct(array $row): array {
    return [
        'id' => (string)($row['id'] ?? ''),
        'productId' => isset($row['product_id']) ? (string)$row['product_id'] : '',
        'productName' => $row['nama_produk'] ?? '',
        'reviewer' => $row['display_name'] ?? 'User',
        'rating' => (float)($row['rating'] ?? 0),
        'comment' => $row['comment'] ?? '',
        'createdAt' => !empty($row['created_at']) ? date(DATE_ATOM, strtotime($row['created_at'])) : date(DATE_ATOM),
        'updatedAt' => !empty($row['updated_at']) ? date(DATE_ATOM, strtotime($row['updated_at'])) : date(DATE_ATOM),
    ];
}

try {
    merchantEnsureSchema($conn);
    $payload = merchantRequireMerchant();
    $merchant = merchantCurrent($conn, $payload);
    $merchantId = (string)$merchant['id'];
    $ratingFilter = (int)($_GET['rating'] ?? 0);
    if ($ratingFilter < 0 || $ratingFilter > 5) {
        $ratingFilter = 0;
    }

    $stmt = $conn->prepare("
        SELECT p.*,
               COALESCE(AVG(CASE WHEN mr.deleted_at IS NULL THEN mr.rating END), 0) AS rating,
               COUNT(CASE WHEN mr.deleted_at IS NULL THEN mr.id END) AS review_count
        FROM products p
        LEFT JOIN merchant_reviews mr ON mr.product_id = p.id
        WHERE p.merchant_id = ? AND p.is_active = 1
        GROUP BY p.id
        ORDER BY review_count DESC, rating DESC, p.updated_at DESC
    ");
    if (!$stmt) {
        merchantSendJson(false, null, 'Database error', 500);
    }
    $stmt->bind_param('s', $merchantId);
    $stmt->execute();
    $products = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $data = [];
    foreach ($products as $product) {
        $productId = (int)($product['id'] ?? 0);
        $sql = "
            SELECT mr.*, u.display_name, p.nama_produk
            FROM merchant_reviews mr
            LEFT JOIN users u ON u.id = mr.user_id
            LEFT JOIN products p ON p.id = mr.product_id
            WHERE mr.merchant_id = ?
              AND mr.product_id = ?
              AND mr.deleted_at IS NULL
        ";
        $types = 'si';
        $params = [$merchantId, $productId];
        if ($ratingFilter > 0) {
            $sql .= " AND mr.rating = ?";
            $types .= 'i';
            $params[] = $ratingFilter;
        }
        $sql .= " ORDER BY mr.updated_at DESC, mr.created_at DESC, mr.id DESC";
        $reviewStmt = $conn->prepare($sql);
        if (!$reviewStmt) {
            continue;
        }
        $reviewStmt->bind_param($types, ...$params);
        $reviewStmt->execute();
        $reviews = $reviewStmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $reviewStmt->close();

        $data[] = [
            'product' => merchantProductPayload($product),
            'reviews' => array_map('merchantReviewPayloadForProduct', $reviews),
        ];
    }

    merchantSendJson(true, $data, 'Ulasan produk berhasil dimuat');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
