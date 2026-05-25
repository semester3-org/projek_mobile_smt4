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

function userMerchantDefaultImage(string $type): string {
    return match ($type) {
        'laundry' => 'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?w=900',
        'catering' => 'https://images.unsplash.com/photo-1543353071-873f17a7a088?w=900',
        default => 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=900',
    };
}

function userMerchantFallbackMenu(string $type, string $merchantId): array {
    if ($type === 'laundry') {
        return [
            [
                'id' => $merchantId . '-wash-fold',
                'name' => 'Cuci Lipat (Kg)',
                'description' => 'Regular',
                'price' => 8000,
                'imageUrl' => 'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=400',
                'category' => 'Laundry Kiloan',
                'unit' => '/kg',
            ],
            [
                'id' => $merchantId . '-wash-iron',
                'name' => 'Cuci Setrika (Kg)',
                'description' => 'Rapi dan wangi',
                'price' => 12000,
                'imageUrl' => 'https://images.unsplash.com/photo-1521656693074-0ef32e80a5d5?w=400',
                'category' => 'Laundry Kiloan',
                'unit' => '/kg',
            ],
        ];
    }

    if ($type === 'catering') {
        return [
            [
                'id' => $merchantId . '-monthly',
                'name' => 'Paket Catering Bulanan',
                'description' => 'Menu berganti setiap hari selama satu bulan',
                'price' => 900000,
                'imageUrl' => 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=400',
                'category' => 'Paket Bulanan',
                'unit' => '/bulan',
            ],
            [
                'id' => $merchantId . '-diet',
                'name' => 'Paket Diet Sehat Bulanan',
                'description' => 'Lauk tinggi protein, sayur, dan buah harian',
                'price' => 1250000,
                'imageUrl' => 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400',
                'category' => 'Menu Sehat',
                'unit' => '/bulan',
            ],
        ];
    }

    return [];
}

function userMerchantMenu(mysqli $conn, string $type, string $merchantId): array {
    if (!merchantTableExists($conn, 'products')) {
        return userMerchantFallbackMenu($type, $merchantId);
    }
    $stmt = $conn->prepare("
        SELECT *
        FROM products
        WHERE merchant_id = ? AND is_active = 1
        ORDER BY updated_at DESC, id DESC
        LIMIT 20
    ");
    if (!$stmt) return userMerchantFallbackMenu($type, $merchantId);
    $stmt->bind_param('s', $merchantId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    if (empty($rows)) return [];
    return array_map(fn($row) => [
        'id' => (string)$row['id'],
        'name' => $row['nama_produk'],
        'description' => $row['deskripsi'] ?? '',
        'price' => (float)$row['harga'],
        'imageUrl' => $row['image_url'] ?? '',
        'category' => $row['category'] ?? '',
        'unit' => $row['unit'] ?? '',
    ], $rows);
}

function userMerchantReviews(mysqli $conn, string $merchantId): array {
    if (!merchantTableExists($conn, 'merchant_reviews')) return [];
    $stmt = $conn->prepare("
        SELECT mr.rating, mr.comment, mr.created_at, u.display_name
        FROM merchant_reviews mr
        INNER JOIN users u ON u.id = mr.user_id
        WHERE mr.merchant_id = ?
        ORDER BY mr.created_at DESC
        LIMIT 10
    ");
    if (!$stmt) return [];
    $stmt->bind_param('s', $merchantId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return array_map(fn($row) => [
        'reviewer' => $row['display_name'] ?? 'User',
        'rating' => (float)$row['rating'],
        'comment' => $row['comment'] ?? '',
        'timeLabel' => date('d M Y', strtotime($row['created_at'] ?? 'now')),
    ], $rows);
}

function userMerchantDistance(?float $lat1, ?float $lon1, $lat2, $lon2, float $fallback): float {
    if ($lat1 === null || $lon1 === null || $lat2 === null || $lon2 === null || $lat2 === '' || $lon2 === '') {
        return $fallback;
    }
    $earth = 6371;
    $dLat = deg2rad((float)$lat2 - $lat1);
    $dLon = deg2rad((float)$lon2 - $lon1);
    $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad((float)$lat2)) * sin($dLon / 2) ** 2;
    return round($earth * 2 * atan2(sqrt($a), sqrt(1 - $a)), 2);
}

function userMerchantPayload(mysqli $conn, array $row, string $type, ?float $userLat, ?float $userLng): array {
    $merchantId = (string)($row['merchant_id'] ?? $row['id']);
    $placeId = (string)($row['place_id'] ?? $merchantId);
    $summary = $merchantId !== '' ? merchantRatingSummary($conn, $merchantId) : ['rating' => 0, 'reviewCount' => 0];
    $rating = $summary['reviewCount'] > 0 ? $summary['rating'] : (float)($row['place_rating'] ?? 0);
    $reviewCount = $summary['reviewCount'] > 0 ? $summary['reviewCount'] : (int)($row['review_count'] ?? 0);
    $menu = $merchantId !== '' ? userMerchantMenu($conn, $type, $merchantId) : userMerchantFallbackMenu($type, $placeId);
    $minPrice = 0;
    foreach ($menu as $item) {
        $price = (float)$item['price'];
        if ($price > 0 && ($minPrice <= 0 || $price < $minPrice)) $minPrice = $price;
    }

    $categories = merchantCategories($row['service_categories'] ?? null, $type);
    foreach ($menu as $item) {
        $category = trim((string)($item['category'] ?? ''));
        if ($category !== '' && !in_array($category, $categories, true)) {
            $categories[] = $category;
        }
    }
    $hasDistanceEstimate = $userLat !== null &&
        $userLng !== null &&
        ($row['latitude'] ?? null) !== null &&
        ($row['longitude'] ?? null) !== null &&
        ($row['latitude'] ?? '') !== '' &&
        ($row['longitude'] ?? '') !== '';
    $distance = userMerchantDistance(
        $userLat,
        $userLng,
        $row['latitude'] ?? null,
        $row['longitude'] ?? null,
        (float)($row['distance_km'] ?? 0)
    );
    $openHours = trim((string)($row['open_hours'] ?? ''));
    if ($openHours === '') {
        $openHours = trim(($row['open_time'] ?? '08:00') . ' - ' . ($row['close_time'] ?? '21:00'));
    }

    return [
        'id' => $merchantId !== '' ? $merchantId : $placeId,
        'placeId' => $placeId,
        'merchantId' => $merchantId,
        'type' => $type,
        'name' => $row['business_name'] ?? $row['name'] ?? 'Merchant',
        'subtitle' => $type === 'laundry' ? 'Layanan laundry sekitar kos' : 'Paket menu pilihan untuk penghuni kos',
        'address' => $row['address'] ?? $row['place_address'] ?? '',
        'rating' => $rating,
        'reviewCount' => $reviewCount,
        'distanceKm' => $distance,
        'imageUrl' => $row['photo_url'] ?? $row['image_url'] ?? userMerchantDefaultImage($type),
        'status' => ($row['status'] ?? 'active') === 'inactive' ? 'Tutup' : 'Tersedia',
        'tags' => $categories,
        'minPrice' => $minPrice,
        'priceUnit' => $type === 'laundry' ? '/kg' : '/bulan',
        'eta' => $hasDistanceEstimate ? ($distance <= 1 ? '15-20 mnt' : ($distance <= 3 ? '25-35 mnt' : '40+ mnt')) : '',
        'hasDistanceEstimate' => $hasDistanceEstimate,
        'openHours' => $openHours,
        'description' => $row['description'] ?? ($type === 'laundry'
            ? 'Laundry cepat dengan layanan cuci lipat, setrika, satuan, dan antar jemput.'
            : 'Paket catering bulanan dengan menu yang dapat diperbarui merchant.'),
        'phone' => $row['phone'] ?? '',
        'email' => $row['email'] ?? '',
        'menuItems' => $menu,
        'reviews' => $merchantId !== '' ? userMerchantReviews($conn, $merchantId) : [],
    ];
}

function userMerchantFallback(string $type): array {
    if ($type === 'laundry') {
        return [
            [
                'id' => 'l1',
                'merchantId' => 'l1',
                'type' => 'laundry',
                'name' => 'Clean & Fresh Laundry',
                'subtitle' => 'Antar jemput dan express 6 jam',
                'address' => 'Jl. Sudirman No. 45, Jakarta Pusat',
                'rating' => 4.8,
                'reviewCount' => 120,
                'distanceKm' => 0.8,
                'imageUrl' => userMerchantDefaultImage('laundry'),
                'status' => 'Tersedia',
                'tags' => ['Laundry Kiloan', 'Antar Jemput'],
                'minPrice' => 8000,
                'priceUnit' => '/kg',
                'eta' => '25-30 mnt',
                'hasDistanceEstimate' => false,
                'openHours' => '08:00 - 21:00',
                'description' => 'Laundry cepat dengan layanan cuci lipat, setrika, satuan, dan antar jemput area Sentra Ruang.',
                'phone' => '+62 812-3456-7890',
                'email' => 'halo@cleanfresh.id',
                'menuItems' => userMerchantFallbackMenu('laundry', 'l1'),
                'reviews' => [],
            ],
        ];
    }

    return [
        [
            'id' => 'cat1',
            'merchantId' => 'cat1',
            'type' => 'catering',
            'name' => 'Green Garden Catering',
            'subtitle' => 'Masakan sehat dan diet kalori',
            'address' => 'Jl. Kemang Raya No. 9, Jakarta Selatan',
            'rating' => 4.8,
            'reviewCount' => 124,
            'distanceKm' => 1.2,
            'imageUrl' => userMerchantDefaultImage('catering'),
            'status' => 'Tersedia',
            'tags' => ['Paket Bulanan', 'Menu Sehat'],
            'minPrice' => 900000,
            'priceUnit' => '/bulan',
            'eta' => '25-30 mnt',
            'hasDistanceEstimate' => false,
            'openHours' => '08:00 - 20:00',
            'description' => 'Menu harian bergizi untuk penghuni kos selama satu bulan penuh.',
            'phone' => '+62 812-4455-7788',
            'email' => 'order@greengarden.id',
            'menuItems' => userMerchantFallbackMenu('catering', 'cat1'),
            'reviews' => [],
        ],
    ];
}

try {
    merchantEnsureSchema($conn);

    $type = strtolower(trim($_GET['type'] ?? 'laundry'));
    if (!in_array($type, ['laundry', 'catering'], true)) {
        merchantSendJson(false, null, 'Tipe merchant tidak tersedia', 400);
    }
    $id = trim($_GET['id'] ?? '');
    $userLat = isset($_GET['lat']) && $_GET['lat'] !== '' ? (float)$_GET['lat'] : null;
    $userLng = isset($_GET['lng']) && $_GET['lng'] !== '' ? (float)$_GET['lng'] : null;

    $rows = [];
    if (merchantTableExists($conn, 'merchants')) {
        $placeJoin = $type === 'laundry'
            ? "LEFT JOIN laundry_places p ON p.merchant_id = m.id OR p.id = m.id"
            : "LEFT JOIN catering_places p ON p.merchant_id = m.id OR p.id = m.id";
        $specialtySelect = $type === 'catering' && merchantColumnExists($conn, 'catering_places', 'specialty')
            ? "p.specialty"
            : "NULL";
        $stmt = $conn->prepare("
            SELECT m.id AS merchant_id, m.business_name, m.merchant_type, m.phone, m.address,
                   m.description, m.photo_url, m.latitude, m.longitude, m.open_time, m.close_time,
                   m.service_categories, m.status, u.email,
                   p.id AS place_id,
                   COALESCE(p.address, m.address) AS place_address,
                   p.rating AS place_rating,
                   p.distance_km,
                   p.image_url,
                   " . ($type === 'laundry' ? "p.open_hours" : "NULL") . " AS open_hours,
                   $specialtySelect AS specialty
            FROM merchants m
            INNER JOIN users u ON u.id = m.user_id
            $placeJoin
            WHERE m.merchant_type = ?
            ORDER BY COALESCE(p.distance_km, 999), m.updated_at DESC
        ");
        if ($stmt) {
            $stmt->bind_param('s', $type);
            $stmt->execute();
            $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            $stmt->close();
        }
    }

    $data = array_map(fn($row) => userMerchantPayload($conn, $row, $type, $userLat, $userLng), $rows);
    if (empty($data)) {
        $data = userMerchantFallback($type);
    }
    usort($data, fn($a, $b) => $a['distanceKm'] <=> $b['distanceKm']);

    if ($id !== '') {
        foreach ($data as $merchant) {
            if ($merchant['id'] === $id || ($merchant['placeId'] ?? '') === $id) {
                merchantSendJson(true, $merchant, 'Detail merchant berhasil dimuat');
            }
        }
        merchantSendJson(false, null, 'Merchant tidak ditemukan', 404);
    }

    merchantSendJson(true, $data, 'Daftar merchant berhasil dimuat');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
