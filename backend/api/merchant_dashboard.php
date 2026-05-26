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

try {
    $payload = merchantRequireMerchant();
    $merchant = merchantCurrent($conn, $payload);
    merchantExpireFinishedCateringSubscriptions($conn);
    $merchantId = (string)$merchant['id'];

    $totalOrders = (int)(merchantQueryValue(
        $conn,
        'SELECT COUNT(*) FROM orders WHERE merchant_id = ?',
        's',
        [$merchantId]
    ) ?? 0);
    $processingOrders = (int)(merchantQueryValue(
        $conn,
        "SELECT COUNT(*) FROM orders WHERE merchant_id = ? AND status IN ('accepted','processing','delivered')",
        's',
        [$merchantId]
    ) ?? 0);
    $activeProducts = (int)(merchantQueryValue(
        $conn,
        'SELECT COUNT(*) FROM products WHERE merchant_id = ? AND is_active = 1',
        's',
        [$merchantId]
    ) ?? 0);
    $activePromos = (int)(merchantQueryValue(
        $conn,
        "SELECT COUNT(*) FROM merchant_promos
         WHERE merchant_id = ?
           AND is_active = 1
           AND (start_at IS NULL OR start_at <= NOW())
           AND (end_at IS NULL OR end_at >= NOW())",
        's',
        [$merchantId]
    ) ?? 0);

    $recentOrders = merchantOrderQuery($conn, $merchantId, null, null, null, 4);
    $profile = merchantProfilePayload($conn, $merchant);

    merchantSendJson(true, [
        'merchantName' => $profile['businessName'],
        'merchantType' => $profile['merchantType'],
        'totalOrders' => $totalOrders,
        'processingOrders' => $processingOrders,
        'activeProducts' => $activeProducts,
        'activePromos' => $activePromos,
        'recentOrders' => $recentOrders,
    ], 'Dashboard merchant berhasil dimuat');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
