<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/db.php';

function sendJson(bool $success, $data = null, string $message = '', int $code = 200): void {
    http_response_code($code);
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data' => $data,
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

function tableExists(mysqli $conn, string $table): bool {
    $stmt = $conn->prepare(
        'SELECT COUNT(*) AS total FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?'
    );
    if (!$stmt) return false;
    $stmt->bind_param('s', $table);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return (int)($result['total'] ?? 0) > 0;
}

function moneyMenu(string $type, string $merchantId): array {
    if ($type === 'laundry') {
        return [
            [
                'id' => $merchantId . '-wash-fold',
                'name' => 'Cuci Lipat (Kg)',
                'description' => 'Regular',
                'price' => 8000,
                'imageUrl' => 'https://images.unsplash.com/photo-1517677200551-7920f4b53198?w=400',
            ],
            [
                'id' => $merchantId . '-wash-iron',
                'name' => 'Cuci Setrika (Kg)',
                'description' => 'Rapi dan wangi',
                'price' => 12000,
                'imageUrl' => 'https://images.unsplash.com/photo-1521656693074-0ef32e80a5d5?w=400',
            ],
        ];
    }

    if ($type === 'catering') {
        return [
            [
                'id' => $merchantId . '-box',
                'name' => 'Paket Nasi Kotak Premium',
                'description' => 'Lengkap dengan 5 lauk pauk',
                'price' => 45000,
                'imageUrl' => 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=400',
            ],
            [
                'id' => $merchantId . '-diet',
                'name' => 'Catering Diet Sehat',
                'description' => 'Rendah kalori, tinggi protein',
                'price' => 55000,
                'imageUrl' => 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400',
            ],
        ];
    }

    return [
        [
            'id' => $merchantId . '-coffee',
            'name' => 'Signature Coffee',
            'description' => 'Kopi susu gula aren',
            'price' => 18000,
            'imageUrl' => 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400',
        ],
        [
            'id' => $merchantId . '-croissant',
            'name' => 'Croissant Butter',
            'description' => 'Fresh baked',
            'price' => 22000,
            'imageUrl' => 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400',
        ],
    ];
}

function reviewsFor(string $type): array {
    if ($type === 'laundry') {
        return [
            [
                'reviewer' => 'Siska Amelia',
                'rating' => 5,
                'comment' => 'Hasil cucian sangat bersih dan wangi. Pengirimannya juga cepat, kurirnya ramah.',
                'timeLabel' => '2 hari yang lalu',
            ],
            [
                'reviewer' => 'Budi Santoso',
                'rating' => 4,
                'comment' => 'Layanan oke, lipatan rapi sekali. Secara keseluruhan puas dengan hasilnya.',
                'timeLabel' => '1 minggu yang lalu',
            ],
        ];
    }

    return [
        [
            'reviewer' => 'Anita Wijaya',
            'rating' => 5,
            'comment' => 'Makanannya enak dan porsinya pas. Kemasan juga sangat rapi.',
            'timeLabel' => '2 jam yang lalu',
        ],
        [
            'reviewer' => 'Budi Santoso',
            'rating' => 4,
            'comment' => 'Layanannya tepat waktu dan kualitasnya konsisten.',
            'timeLabel' => 'Kemarin',
        ],
    ];
}

function fallbackMerchants(string $type): array {
    if ($type === 'laundry') {
        return [
            merchantPayload('l1', 'laundry', 'Clean & Fresh Laundry', 'Antar jemput dan express 6 jam', 'Jl. Sudirman No. 45, Jakarta Pusat', 4.8, 120, 0.8, 'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?w=900', 'Tersedia', ['ANTAR JEMPUT', 'EXPRESS 6 JAM'], 8000, '/kg', '25-30 mnt', '08:00 - 21:00'),
            merchantPayload('l2', 'laundry', 'Kiloan Express', 'Cuci sepatu dan kiloan cepat', 'Jl. Melati No. 18, Jakarta Selatan', 4.5, 80, 1.2, 'https://images.unsplash.com/photo-1626806819282-2c1dc01a5e0c?w=900', 'Tersedia', ['CUCI SEPATU', 'KILOAN'], 7500, '/kg', '35-45 mnt', '07:00 - 22:00'),
        ];
    }

    if ($type === 'catering') {
        return [
            merchantPayload('cat1', 'catering', 'Green Garden Catering', 'Masakan sehat dan diet kalori', 'Jl. Kemang Raya No. 9, Jakarta Selatan', 4.8, 124, 1.2, 'https://images.unsplash.com/photo-1543353071-873f17a7a088?w=900', 'Tersedia', ['DIET SEHAT', 'HARIAN'], 25000, '', '25-30 mnt', '08:00 - 20:00'),
            merchantPayload('cat2', 'catering', 'Dapur Nusantara', 'Masakan tradisional Indonesia', 'Jl. Panglima Polim No. 11, Jakarta Selatan', 4.9, 210, 2.5, 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=900', 'Tersedia', ['NASI BOX', 'PRASMANAN'], 35000, '', '35-45 mnt', '07:00 - 21:00'),
        ];
    }

    return [
        merchantPayload('c1', 'cafe', 'Kopi Senja', 'Coffee & workspace', 'Sentra Ruang Ground Floor, Blok A1', 4.8, 124, 0.8, 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=900', 'Buka', ['WiFi Cepat', 'Stopkontak', 'Outdoor'], 18000, '', '', '08:00 - 22:00'),
        merchantPayload('c2', 'cafe', 'Ruang Kopi', 'Tenang dan parkir luas', 'Jl. Cendana No. 21', 4.6, 85, 1.2, 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=900', 'Buka', ['AC', 'Tenang', 'Parkir Luas'], 20000, '', '', '09:00 - 22:00'),
        merchantPayload('c3', 'cafe', 'Brew & Chill', 'Artisan coffee', 'Jl. Purnama No. 8', 4.9, 210, 2.5, 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=900', 'Tutup', ['Artisan Coffee', 'Smoking Area'], 24000, '', '', '10:00 - 23:00'),
    ];
}

function merchantPayload(
    string $id,
    string $type,
    string $name,
    string $subtitle,
    string $address,
    float $rating,
    int $reviewCount,
    float $distanceKm,
    string $imageUrl,
    string $status,
    array $tags,
    float $minPrice,
    string $priceUnit,
    string $eta,
    string $openHours
): array {
    $description = match ($type) {
        'laundry' => 'Laundry cepat dengan layanan cuci lipat, setrika, satuan, dan antar jemput area Sentra Ruang.',
        'catering' => 'Menu harian bergizi untuk penghuni kos, cocok untuk makan siang dan makan malam.',
        default => 'Ruang komunal yang menggabungkan kenikmatan kopi artisan dengan kenyamanan ruang kerja.',
    };

    return [
        'id' => $id,
        'type' => $type,
        'name' => $name,
        'subtitle' => $subtitle,
        'address' => $address,
        'rating' => $rating,
        'reviewCount' => $reviewCount,
        'distanceKm' => $distanceKm,
        'imageUrl' => $imageUrl,
        'status' => $status,
        'tags' => $tags,
        'minPrice' => $minPrice,
        'priceUnit' => $priceUnit,
        'eta' => $eta,
        'openHours' => $openHours,
        'description' => $description,
        'phone' => '+62 812-3456-7890',
        'email' => 'halo@sentraruang.id',
        'menuItems' => moneyMenu($type, $id),
        'reviews' => reviewsFor($type),
    ];
}

function merchantsFromDb(mysqli $conn, string $type): array {
    if ($type === 'laundry' && tableExists($conn, 'laundry_places')) {
        $result = $conn->query('SELECT id, name, address, rating, distance_km, image_url, open_hours FROM laundry_places ORDER BY distance_km ASC');
        if ($result && $result->num_rows > 0) {
            $rows = [];
            while ($r = $result->fetch_assoc()) {
                $rows[] = merchantPayload(
                    $r['id'],
                    'laundry',
                    $r['name'],
                    'Antar jemput dan express 6 jam',
                    $r['address'],
                    (float)$r['rating'],
                    120,
                    (float)$r['distance_km'],
                    $r['image_url'],
                    'Tersedia',
                    ['ANTAR JEMPUT', 'EXPRESS 6 JAM'],
                    8000,
                    '/kg',
                    '25-30 mnt',
                    $r['open_hours']
                );
            }
            return $rows;
        }
    }

    if ($type === 'cafe' && tableExists($conn, 'cafe_places')) {
        $result = $conn->query('SELECT id, name, vibe, rating, distance_km, image_url FROM cafe_places ORDER BY distance_km ASC');
        if ($result && $result->num_rows > 0) {
            $rows = [];
            while ($r = $result->fetch_assoc()) {
                $rows[] = merchantPayload(
                    $r['id'],
                    'cafe',
                    $r['name'],
                    $r['vibe'],
                    'Sentra Ruang Ground Floor, Blok A1',
                    (float)$r['rating'],
                    124,
                    (float)$r['distance_km'],
                    $r['image_url'],
                    'Buka',
                    ['WiFi Cepat', 'Stopkontak', 'Outdoor'],
                    18000,
                    '',
                    '',
                    '08:00 - 22:00'
                );
            }
            return $rows;
        }
    }

    if ($type === 'catering' && tableExists($conn, 'catering_places')) {
        $result = $conn->query('SELECT id, name, address, specialty, rating, distance_km, image_url FROM catering_places ORDER BY distance_km ASC');
        if ($result && $result->num_rows > 0) {
            $rows = [];
            while ($r = $result->fetch_assoc()) {
                $rows[] = merchantPayload(
                    $r['id'],
                    'catering',
                    $r['name'],
                    $r['specialty'],
                    $r['address'],
                    (float)$r['rating'],
                    124,
                    (float)$r['distance_km'],
                    $r['image_url'],
                    'Tersedia',
                    ['DIET SEHAT', 'HARIAN'],
                    25000,
                    '',
                    '25-30 mnt',
                    '08:00 - 20:00'
                );
            }
            return $rows;
        }
    }

    return fallbackMerchants($type);
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendJson(false, null, 'Only GET method allowed', 405);
}

$type = strtolower(trim($_GET['type'] ?? 'cafe'));
if (!in_array($type, ['laundry', 'catering', 'cafe'], true)) {
    $type = 'cafe';
}

$id = trim($_GET['id'] ?? '');
$data = merchantsFromDb($conn, $type);

if ($id !== '') {
    foreach ($data as $merchant) {
        if ($merchant['id'] === $id) {
            sendJson(true, $merchant, 'Detail merchant berhasil dimuat');
        }
    }
    sendJson(false, null, 'Merchant tidak ditemukan', 404);
}

sendJson(true, $data, 'Daftar merchant berhasil dimuat');
?>
