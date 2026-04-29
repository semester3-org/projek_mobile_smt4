<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/db.php';

function tableExists(mysqli $conn, string $table): bool {
    $stmt = $conn->prepare(
        'SELECT COUNT(*) AS total FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?'
    );
    if (!$stmt) return false;
    $stmt->bind_param('s', $table);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return (int)($row['total'] ?? 0) > 0;
}

$fallback = [
    [
        'id' => 'cat1',
        'name' => 'Green Garden Catering',
        'address' => 'Jl. Kemang Raya No. 9, Jakarta Selatan',
        'specialty' => 'Masakan Sehat & Diet Kalori',
        'rating' => 4.8,
        'distanceKm' => 1.2,
        'imageUrl' => 'https://images.unsplash.com/photo-1543353071-873f17a7a088?w=900',
        'minOrderPortion' => 1,
    ],
    [
        'id' => 'cat2',
        'name' => 'Dapur Nusantara',
        'address' => 'Jl. Panglima Polim No. 11, Jakarta Selatan',
        'specialty' => 'Masakan Tradisional Indonesia',
        'rating' => 4.9,
        'distanceKm' => 2.5,
        'imageUrl' => 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=900',
        'minOrderPortion' => 1,
    ],
];

if (!tableExists($conn, 'catering_places')) {
    echo json_encode(['success' => true, 'data' => $fallback, 'total' => count($fallback)], JSON_UNESCAPED_UNICODE);
    exit();
}

$result = $conn->query("
    SELECT id, name, address, specialty, rating, distance_km, image_url, min_order_portion
    FROM catering_places
    ORDER BY distance_km ASC
");

if (!$result || $result->num_rows === 0) {
    echo json_encode(['success' => true, 'data' => $fallback, 'total' => count($fallback)], JSON_UNESCAPED_UNICODE);
    exit();
}

$data = [];
while ($r = $result->fetch_assoc()) {
    $data[] = [
        'id' => $r['id'],
        'name' => $r['name'],
        'address' => $r['address'],
        'specialty' => $r['specialty'],
        'rating' => (float)$r['rating'],
        'distanceKm' => (float)$r['distance_km'],
        'imageUrl' => $r['image_url'],
        'minOrderPortion' => (int)$r['min_order_portion'],
    ];
}

echo json_encode(['success' => true, 'data' => $data, 'total' => count($data)], JSON_UNESCAPED_UNICODE);
?>
