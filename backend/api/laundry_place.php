<?php
/**
 * GET /api/laundry_places.php
 * Endpoint publik — tidak butuh login.
 */
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once __DIR__ . '/../config/db.php';

try {
    $rows = $conn->query("
        SELECT id, name, address, rating, distance_km, image_url, open_hours
        FROM laundry_places
        ORDER BY distance_km ASC
    ")->fetch_all(MYSQLI_ASSOC);

    $data = array_map(fn($r) => [
        'id'         => $r['id'],
        'name'       => $r['name'],
        'address'    => $r['address'],
        'rating'     => (float)$r['rating'],
        'distanceKm' => (float)$r['distance_km'],
        'imageUrl'   => $r['image_url'],
        'openHours'  => $r['open_hours'],
    ], $rows);

    echo json_encode(['success' => true, 'data' => $data, 'total' => count($data)]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>