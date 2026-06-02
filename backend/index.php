<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Session-Id');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$uri  = $_SERVER['REQUEST_URI'];
$path = parse_url($uri, PHP_URL_PATH);

if (strpos($path, '/backend') === 0) {
    $path = substr($path, 8);
}
$path = trim($path, '/');
$path = strtok($path, '?');

error_log("DEBUG: URI=$uri | Path=$path | Method=" . $_SERVER['REQUEST_METHOD']);

// ── Auth endpoints (tidak perlu login) ────────────────────────────────────────
if ($path === 'api/login')           { require_once __DIR__ . '/api/login.php';          exit; }
if ($path === 'api/login-google')    { require_once __DIR__ . '/api/login_google.php';   exit; }
if ($path === 'api/session')         { require_once __DIR__ . '/api/session.php';        exit; }
if ($path === 'api/register')        { require_once __DIR__ . '/api/register.php';       exit; }
if ($path === 'api/forgot-password') { require_once __DIR__ . '/api/forgot-password.php'; exit; }
if ($path === 'api/reset-password')  { require_once __DIR__ . '/api/reset-password.php'; exit; }

// ── Endpoint publik (tidak perlu login) ───────────────────────────────────────
if ($path === 'api/kos_listings_public') { require_once __DIR__ . '/api/kos_listings_public.php'; exit; }
if ($path === 'api/laundry_places')      { require_once __DIR__ . '/api/laundry_places.php';      exit; }
if ($path === 'api/catering_places')     { require_once __DIR__ . '/api/catering_places.php';     exit; }

// ── User app endpoints ───────────────────────────────────────────────────────
if ($path === 'api/user_dashboard')       { require_once __DIR__ . '/api/user_dashboard.php';      exit; }
if ($path === 'api/user_merchants')       { require_once __DIR__ . '/api/user_merchants.php';      exit; }
if ($path === 'api/user_billings')        { require_once __DIR__ . '/api/user_billings.php';       exit; }
if ($path === 'api/user_billings/pay')    { require_once __DIR__ . '/api/user_billings_pay.php';   exit; }
if ($path === 'api/user_orders')          { require_once __DIR__ . '/api/user_orders.php';         exit; }
if ($path === 'api/user_notifications')   { require_once __DIR__ . '/api/user_notifications.php';  exit; }
if ($path === 'api/user_notification_presence') { require_once __DIR__ . '/api/user_notification_presence.php'; exit; }
if ($path === 'api/user_profile')         { require_once __DIR__ . '/api/user_profile.php';        exit; }
if ($path === 'api/change-password')      { require_once __DIR__ . '/api/change-password.php';     exit; }
if ($path === 'api/user_ratings')         { require_once __DIR__ . '/api/user_ratings.php';        exit; }
if ($path === 'api/user_favorite_merchants') { require_once __DIR__ . '/api/user_favorite_merchants.php'; exit; }
if ($path === 'api/midtrans')             { require_once __DIR__ . '/api/midtrans.php';            exit; }
if ($path === 'api/midtrans_notification') { require_once __DIR__ . '/api/midtrans_notification.php'; exit; }
if ($path === 'api/catering_subscribers') { require_once __DIR__ . '/api/catering_subscribers.php'; exit; }
if ($path === 'api/transaction_receipts') { require_once __DIR__ . '/api/transaction_receipts.php'; exit; }
if ($path === 'api/catering_package_categories') { require_once __DIR__ . '/api/catering_package_categories.php'; exit; }
if ($path === 'api/laundry_service_estimates') { require_once __DIR__ . '/api/laundry_service_estimates.php'; exit; }

// Merchant app endpoints
if ($path === 'api/merchant_dashboard')     { require_once __DIR__ . '/api/merchant_dashboard.php';     exit; }
if ($path === 'api/merchant_orders')        { require_once __DIR__ . '/api/merchant_orders.php';        exit; }
if ($path === 'api/merchant_products')      { require_once __DIR__ . '/api/merchant_products.php';      exit; }
if ($path === 'api/merchant_product_reviews') { require_once __DIR__ . '/api/merchant_product_reviews.php'; exit; }
if ($path === 'api/merchant_promos')        { require_once __DIR__ . '/api/merchant_promos.php';        exit; }
if ($path === 'api/merchant_profile')       { require_once __DIR__ . '/api/merchant_profile.php';       exit; }
if ($path === 'api/merchant_notifications') { require_once __DIR__ . '/api/merchant_notifications.php'; exit; }

// ── Endpoint owner (butuh JWT) ────────────────────────────────────────────────
if ($path === 'api/kos_listings')        { require_once __DIR__ . '/api/kos_listings.php';        exit; }
if ($path === 'api/kos_rooms')           { require_once __DIR__ . '/api/kos_rooms.php';           exit; }
if ($path === 'api/facilities')          { require_once __DIR__ . '/api/facilities.php';          exit; }
if ($path === 'api/owner_tenants')       { require_once __DIR__ . '/api/owner_tenants.php';       exit; }
if ($path === 'api/owner_dashboard')     { require_once __DIR__ . '/api/owner_dashboard.php';     exit; }
if ($path === 'api/owner_finance')       { require_once __DIR__ . '/api/owner_finance.php';       exit; }
if ($path === 'api/owner_notifications') { require_once __DIR__ . '/api/owner_notifications.php'; exit; }

// ── Debug / test ──────────────────────────────────────────────────────────────
if ($path === 'db-test') { require_once __DIR__ . '/db-test.php'; exit; }
if ($path === 'test')    { require_once __DIR__ . '/test.php';    exit; }

// ── Root ──────────────────────────────────────────────────────────────────────
if (empty($path)) {
    http_response_code(200);
    echo json_encode([
        'status'  => 'success',
        'message' => 'KosFinder API Server',
        'version' => '1.0',
        'endpoints' => [
            // Auth
            'POST /api/login',
            'GET|POST|DELETE /api/session',
            'POST /api/register',
            'POST /api/forgot-password',
            'POST /api/reset-password',
            // Public
            'GET  /api/kos_listings_public',
            'GET  /api/kos_listings_public?id={id}',
            'GET  /api/kos_listings_public?search=&max_price=&facilities=WiFi,AC',
            'GET  /api/laundry_places',
            'GET  /api/catering_places',
            'GET  /api/user_dashboard',
            'GET  /api/user_merchants?type=laundry|catering',
            'GET  /api/user_billings',
            'POST /api/user_billings/pay',
            'GET  /api/user_orders',
            'GET  /api/user_notifications',
            'POST|PUT|DELETE /api/user_notification_presence',
            'GET|POST|PUT /api/user_profile',
            'POST /api/change-password',
            'GET|POST|PUT|DELETE /api/user_ratings',
            'GET|POST|DELETE /api/user_favorite_merchants',
            'POST /api/midtrans',
            'POST /api/midtrans_notification',
            'GET /api/merchant_dashboard',
            'GET|PUT /api/merchant_orders',
            'GET|POST|PUT|DELETE /api/merchant_products',
            'GET /api/merchant_product_reviews',
            'GET|POST|PUT|DELETE /api/merchant_promos',
            'GET|PUT /api/merchant_profile',
            'GET /api/merchant_notifications',
            // Owner (JWT required)
            'GET  /api/kos_listings',
            'GET|POST|PUT|DELETE /api/kos_rooms',
            'GET /api/facilities',
            'POST|PUT|DELETE /api/facilities (admin)',
            'GET /api/owner_tenants',
        ],
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

// ── 404 ───────────────────────────────────────────────────────────────────────
http_response_code(404);
echo json_encode([
    'status'         => 'error',
    'message'        => 'Endpoint tidak ditemukan',
    'requested_path' => $path,
    'method'         => $_SERVER['REQUEST_METHOD'],
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
?>
