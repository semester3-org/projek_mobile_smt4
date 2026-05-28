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

function userMerchantIsOpenNow(?string $openTime, ?string $closeTime): bool {
    $open = trim((string)$openTime);
    $close = trim((string)$closeTime);
    if ($open === '' || $close === '') {
        return true;
    }
    $now = (int)date('G') * 60 + (int)date('i');
    $openParts = explode(':', $open);
    $closeParts = explode(':', $close);
    $openMin = ((int)($openParts[0] ?? 8)) * 60 + (int)($openParts[1] ?? 0);
    $closeMin = ((int)($closeParts[0] ?? 21)) * 60 + (int)($closeParts[1] ?? 0);
    if ($openMin === $closeMin) {
        return true;
    }
    if ($closeMin > $openMin) {
        return $now >= $openMin && $now < $closeMin;
    }
    return $now >= $openMin || $now < $closeMin;
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
    return array_map(function ($row) use ($type, $conn, $merchantId) {
        $price30 = (float)($row['harga'] ?? 0);
        $productId = (int)($row['id'] ?? 0);
        $promoDiscount = 0.0;
        $promoRow = null;
        if (merchantTableExists($conn, 'merchant_promos') && $productId > 0 && $price30 > 0) {
            $best = merchantBestPromoForCheckout(
                $conn,
                $merchantId,
                '',
                $price30,
                [['productId' => $productId]]
            );
            if ($best !== null) {
                $promoRow = $best['promo'];
                $promoDiscount = (float)($best['discount'] ?? 0);
            }
        }
        $promoPrice = max(0, $price30 - $promoDiscount);
        $payload = [
            'id' => (string)$row['id'],
            'name' => $row['nama_produk'],
            'description' => $row['deskripsi'] ?? '',
            'price' => $price30,
            'originalPrice' => $price30,
            'imageUrl' => $row['image_url'] ?? '',
            'category' => $row['category'] ?? '',
            'unit' => $row['unit'] ?? '',
            'packageDeliveryType' => $row['package_delivery_type'] ?? null,
            'hasPromo' => $promoDiscount > 0,
            'promoPrice' => $promoDiscount > 0 ? $promoPrice : null,
            'promoDiscountAmount' => $promoDiscount > 0 ? $promoDiscount : null,
            'promoLabel' => $promoDiscount > 0 ? 'PROMO' : null,
            'promoDescription' => $promoDiscount > 0 ? (string)($promoRow['name'] ?? 'Promo aktif') : null,
        ];
        if ($type === 'catering') {
            $payload['price20Days'] = isset($row['price_20_days']) ? (float)$row['price_20_days'] : null;
            $payload['price30Days'] = $price30;
        }
        return $payload;
    }, $rows);
}

function userMerchantReviews(mysqli $conn, string $merchantId): array {
    if (!merchantTableExists($conn, 'merchant_reviews')) return [];
    $stmt = $conn->prepare("
        SELECT mr.id, mr.product_id, mr.rating, mr.comment, mr.created_at, mr.updated_at,
               u.id AS user_id, u.display_name, p.nama_produk
        FROM merchant_reviews mr
        INNER JOIN users u ON u.id = mr.user_id
        LEFT JOIN products p ON p.id = mr.product_id
        WHERE mr.merchant_id = ?
          AND mr.deleted_at IS NULL
        ORDER BY mr.created_at DESC
        LIMIT 10
    ");
    if (!$stmt) return [];
    $stmt->bind_param('s', $merchantId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return array_map(fn($row) => [
        'id' => (string)($row['id'] ?? ''),
        'productId' => isset($row['product_id']) ? (string)$row['product_id'] : '',
        'productName' => $row['nama_produk'] ?? '',
        'userId' => (string)($row['user_id'] ?? ''),
        'reviewer' => $row['display_name'] ?? 'User',
        'rating' => (float)$row['rating'],
        'comment' => $row['comment'] ?? '',
        'timeLabel' => date('d M Y H:i', strtotime($row['created_at'] ?? 'now')),
        'createdAt' => $row['created_at'] ?? '',
        'updatedAt' => $row['updated_at'] ?? '',
        'deletedAt' => '',
        'isDeleted' => false,
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

function userMerchantEtaFromKm(float $distanceKm): string {
    if ($distanceKm <= 0) {
        return '';
    }
    // Perkiraan tempuh motor/mobil perkotaan ~18 km/jam
    $minutes = (int)ceil(($distanceKm / 18) * 60);
    $low = max(5, $minutes - 3);
    $high = min(120, $minutes + 8);
    return $low >= $high ? "{$low} mnt" : "{$low}-{$high} mnt";
}

function userMerchantValidCoord($value): ?float {
    if ($value === null || $value === '') {
        return null;
    }
    $num = (float)$value;
    if (abs($num) < 0.0001) {
        return null;
    }
    return $num;
}

function userMerchantResolveUserCoords(mysqli $conn, ?float $userLat, ?float $userLng, string $userId): array {
    if ($userLat !== null && $userLng !== null && userMerchantValidCoord($userLat) !== null) {
        return [$userLat, $userLng];
    }
    if ($userId === '' || !merchantTableExists($conn, 'users')) {
        return [null, null];
    }
    $hasLat = merchantColumnExists($conn, 'users', 'latitude');
    if (!$hasLat) {
        return [null, null];
    }
    $stmt = $conn->prepare('SELECT latitude, longitude FROM users WHERE id = ? LIMIT 1');
    if (!$stmt) {
        return [null, null];
    }
    $stmt->bind_param('s', $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return [
        userMerchantValidCoord($row['latitude'] ?? null),
        userMerchantValidCoord($row['longitude'] ?? null),
    ];
}

function userMerchantRowCoords(array $row): array {
    $lat = userMerchantValidCoord($row['latitude'] ?? null);
    $lng = userMerchantValidCoord($row['longitude'] ?? null);
    return [$lat, $lng];
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
    [$merchantLat, $merchantLng] = userMerchantRowCoords($row);
    $hasDistanceEstimate = $userLat !== null &&
        $userLng !== null &&
        $merchantLat !== null &&
        $merchantLng !== null;
    $distance = userMerchantDistance(
        $userLat,
        $userLng,
        $merchantLat,
        $merchantLng,
        (float)($row['distance_km'] ?? 0)
    );
    if ($hasDistanceEstimate && $distance < 0.05) {
        $distance = 0.05;
    }
    $hasDistanceEstimate = $hasDistanceEstimate && $distance > 0;
    $openHours = trim((string)($row['open_hours'] ?? ''));
    $openTime = trim((string)($row['open_time'] ?? '08:00'));
    $closeTime = trim((string)($row['close_time'] ?? '21:00'));
    if ($openHours === '') {
        $openHours = trim($openTime . ' - ' . $closeTime);
    }
    $isInactive = ($row['status'] ?? 'active') === 'inactive';
    $isOpenNow = !$isInactive && userMerchantIsOpenNow($openTime, $closeTime);

    return [
        'id' => $merchantId !== '' ? $merchantId : $placeId,
        'placeId' => $placeId,
        'merchantId' => $merchantId,
        'type' => $type,
        'name' => $row['business_name'] ?? $row['name'] ?? 'Merchant',
        'subtitle' => '',
        'address' => $row['address'] ?? $row['place_address'] ?? '',
        'rating' => $rating,
        'reviewCount' => $reviewCount,
        'distanceKm' => $distance,
        'imageUrl' => $row['photo_url'] ?? $row['image_url'] ?? userMerchantDefaultImage($type),
        'status' => $isOpenNow ? 'Tersedia' : 'Tutup',
        'openTime' => $openTime,
        'closeTime' => $closeTime,
        'isOpenNow' => $isOpenNow,
        'tags' => $categories,
        'minPrice' => $minPrice,
        'priceUnit' => $type === 'laundry' ? '/kg' : '/bulan',
        'eta' => $hasDistanceEstimate ? userMerchantEtaFromKm($distance) : '',
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
    $payload = merchantRequireAuth();
    $userId = (string)($payload['sub'] ?? '');
    [$userLat, $userLng] = userMerchantResolveUserCoords($conn, $userLat, $userLng, $userId);

    $rows = [];
    if (merchantTableExists($conn, 'merchants')) {
        $placeJoin = $type === 'laundry'
            ? "LEFT JOIN laundry_places p ON p.merchant_id = m.id OR p.id = m.id"
            : "LEFT JOIN catering_places p ON p.merchant_id = m.id OR p.id = m.id";
        $specialtySelect = $type === 'catering' && merchantColumnExists($conn, 'catering_places', 'specialty')
            ? "p.specialty"
            : "NULL";
        $placeLat = merchantColumnExists($conn, $type === 'laundry' ? 'laundry_places' : 'catering_places', 'latitude')
            ? 'p.latitude' : 'NULL';
        $placeLng = merchantColumnExists($conn, $type === 'laundry' ? 'laundry_places' : 'catering_places', 'longitude')
            ? 'p.longitude' : 'NULL';
        $stmt = $conn->prepare("
            SELECT m.id AS merchant_id, m.business_name, m.merchant_type, m.phone, m.address,
                   m.description, m.photo_url, m.open_time, m.close_time,
                   m.service_categories, m.status, u.email,
                   COALESCE(NULLIF(m.latitude, 0), $placeLat) AS latitude,
                   COALESCE(NULLIF(m.longitude, 0), $placeLng) AS longitude,
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

    $data = [];
    $seenMerchantIds = [];
    foreach ($rows as $row) {
        $merchantId = (string)($row['merchant_id'] ?? $row['id'] ?? '');
        $placeId = (string)($row['place_id'] ?? '');
        $dedupeKey = $merchantId !== '' ? $merchantId : $placeId;
        if ($dedupeKey !== '' && isset($seenMerchantIds[$dedupeKey])) {
            continue;
        }
        if ($dedupeKey !== '') {
            $seenMerchantIds[$dedupeKey] = true;
        }
        $data[] = userMerchantPayload($conn, $row, $type, $userLat, $userLng);
    }
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
