<?php
/**
 * GET /api/cafe_places.php
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
        SELECT id, name, vibe, rating, image_url, distance_km
        FROM cafe_places
        ORDER BY distance_km ASC
    ")->fetch_all(MYSQLI_ASSOC);

    $data = array_map(fn($r) => [
        'id'         => $r['id'],
        'name'       => $r['name'],
        'vibe'       => $r['vibe'],
        'rating'     => (float)$r['rating'],
        'imageUrl'   => $r['image_url'],
        'distanceKm' => (float)$r['distance_km'],
    ], $rows);

    echo json_encode(['success' => true, 'data' => $data, 'total' => count($data)]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>