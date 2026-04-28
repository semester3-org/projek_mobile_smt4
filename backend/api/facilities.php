<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../helpers/jwt.php';

$payload = JWT::getPayloadFromRequest();
if (!$payload) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit();
}

$userId = $payload['sub'];
$role = $payload['role'] ?? 'user';
$method = $_SERVER['REQUEST_METHOD'];
$id = isset($_GET['id']) ? (int)$_GET['id'] : null;

try {
    switch ($method) {
        case 'GET':
            handleGet($conn);
            break;
        case 'POST':
            requireAdmin($role);
            handlePost($conn, $userId);
            break;
        case 'PUT':
            requireAdmin($role);
            if (!$id) throw new Exception('Parameter id wajib diisi', 400);
            handlePut($conn, $id);
            break;
        case 'DELETE':
            requireAdmin($role);
            if (!$id) throw new Exception('Parameter id wajib diisi', 400);
            handleDelete($conn, $id);
            break;
        default:
            throw new Exception('Method not allowed', 405);
    }
} catch (Exception $e) {
    http_response_code($e->getCode() ?: 500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}

function requireAdmin(string $role): void {
    if ($role !== 'admin') {
        throw new Exception('Forbidden: hanya admin yang bisa mengubah fasilitas', 403);
    }
}

function handleGet(mysqli $conn): void {
    $rows = $conn->query("SELECT id, name FROM facilities ORDER BY name ASC")
        ->fetch_all(MYSQLI_ASSOC);
    echo json_encode([
        'success' => true,
        'data' => array_map(
            fn($r) => ['id' => (int)$r['id'], 'name' => $r['name']],
            $rows
        ),
    ]);
}

function handlePost(mysqli $conn, string $adminId): void {
    $body = getJsonBody();
    $name = trim($body['name'] ?? '');
    if ($name === '') throw new Exception('name wajib diisi', 400);

    $stmt = $conn->prepare("
        INSERT INTO facilities (name, created_by, created_at)
        VALUES (?, ?, NOW())
    ");
    if ($stmt) {
        $stmt->bind_param('ss', $name, $adminId);
    } else {
        $stmt = $conn->prepare("INSERT INTO facilities (name, created_at) VALUES (?, NOW())");
        if (!$stmt) {
            throw new Exception('Gagal menambah fasilitas: ' . $conn->error, 500);
        }
        $stmt->bind_param('s', $name);
    }
    if (!$stmt->execute()) {
        if ((int)$stmt->errno === 1062) {
            throw new Exception('Nama fasilitas sudah ada', 409);
        }
        throw new Exception('Gagal menambah fasilitas: ' . $stmt->error, 500);
    }
    $id = (int)$stmt->insert_id;
    $stmt->close();

    echo json_encode([
        'success' => true,
        'message' => 'Fasilitas berhasil ditambahkan',
        'data' => ['id' => $id, 'name' => $name],
    ]);
}

function handlePut(mysqli $conn, int $id): void {
    $body = getJsonBody();
    $name = trim($body['name'] ?? '');
    if ($name === '') throw new Exception('name wajib diisi', 400);

    $stmt = $conn->prepare("UPDATE facilities SET name = ? WHERE id = ?");
    $stmt->bind_param('si', $name, $id);
    if (!$stmt->execute()) {
        if ((int)$stmt->errno === 1062) {
            throw new Exception('Nama fasilitas sudah ada', 409);
        }
        throw new Exception('Gagal update fasilitas: ' . $stmt->error, 500);
    }
    if ($stmt->affected_rows === 0) {
        throw new Exception('Fasilitas tidak ditemukan', 404);
    }
    $stmt->close();

    echo json_encode([
        'success' => true,
        'message' => 'Fasilitas berhasil diperbarui',
        'data' => ['id' => $id, 'name' => $name],
    ]);
}

function handleDelete(mysqli $conn, int $id): void {
    $stmt = $conn->prepare("DELETE FROM facilities WHERE id = ?");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    if ($stmt->affected_rows === 0) {
        throw new Exception('Fasilitas tidak ditemukan', 404);
    }
    $stmt->close();
    echo json_encode(['success' => true, 'message' => 'Fasilitas berhasil dihapus']);
}

function getJsonBody(): array {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        throw new Exception('Invalid JSON request', 400);
    }
    return $data;
}
?>
