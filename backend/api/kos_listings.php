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

function sendResponse(bool $success, string $message, $data = null, int $code = 200): void
{
    http_response_code($code);
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data' => $data,
    ]);
    exit();
}

$payload = JWT::getPayloadFromRequest();
if (!$payload) {
    sendResponse(false, 'Unauthorized', null, 401);
}

$ownerId = $payload['sub'] ?? '';
$ownerRole = $payload['role'] ?? '';

if (!in_array($ownerRole, ['owner', 'admin'], true)) {
    sendResponse(false, 'Forbidden: hanya owner yang bisa akses', null, 403);
}

$method = $_SERVER['REQUEST_METHOD'];
$listingId = $_GET['id'] ?? null;

switch ($method) {
    case 'GET':
        handleGet($conn, $ownerId, $listingId);
        break;
    case 'POST':
        handlePost($conn, $ownerId);
        break;
    case 'PUT':
        if (!$listingId) {
            sendResponse(false, 'Parameter id wajib diisi', null, 400);
        }
        handlePut($conn, $ownerId, $listingId);
        break;
    case 'DELETE':
        if (!$listingId) {
            sendResponse(false, 'Parameter id wajib diisi', null, 400);
        }
        handleDelete($conn, $ownerId, $listingId);
        break;
    default:
        sendResponse(false, 'Method not allowed', null, 405);
}

function handleGet(mysqli $conn, string $ownerId, ?string $listingId): void
{
    if ($listingId) {
        $stmt = $conn->prepare("
            SELECT *
            FROM kos_listings
            WHERE id = ? AND owner_id = ?
            LIMIT 1
        ");
        $stmt->bind_param('ss', $listingId, $ownerId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$row) {
            sendResponse(false, 'Kos tidak ditemukan', null, 404);
        }

        sendResponse(true, 'Berhasil', formatListing($row));
    }

    $stmt = $conn->prepare("
        SELECT *
        FROM kos_listings
        WHERE owner_id = ?
        ORDER BY created_at DESC
    ");
    $stmt->bind_param('s', $ownerId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $items = array_map('formatListing', $rows);

    echo json_encode([
        'success' => true,
        'message' => 'Berhasil',
        'data' => $items,
        'total' => count($items),
    ]);
}

function handlePost(mysqli $conn, string $ownerId): void
{
    $body = getJsonBody();

    $title = trim($body['title'] ?? '');
    $location = trim($body['location'] ?? '');
    $description = trim($body['description'] ?? '');
    $pricePerMonth = (int)($body['price_per_month'] ?? 0);
    $ownerContact = trim($body['owner_contact'] ?? '');
    $rating = isset($body['rating']) ? (float)$body['rating'] : 0.0;

    if ($title === '') sendResponse(false, 'title wajib diisi', null, 400);
    if ($location === '') sendResponse(false, 'location wajib diisi', null, 400);
    if ($description === '') sendResponse(false, 'description wajib diisi', null, 400);
    if ($pricePerMonth <= 0) sendResponse(false, 'price_per_month harus lebih dari 0', null, 400);
    if ($ownerContact === '') sendResponse(false, 'owner_contact wajib diisi', null, 400);

    $id = generateUuid();
    $accessCode = generateAccessCode($id);

    $stmt = $conn->prepare("
        INSERT INTO kos_listings
            (id, owner_id, access_code, title, location, description, price_per_month, rating, owner_contact)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->bind_param(
        'ssssssids',
        $id,
        $ownerId,
        $accessCode,
        $title,
        $location,
        $description,
        $pricePerMonth,
        $rating,
        $ownerContact
    );

    if (!$stmt->execute()) {
        sendResponse(false, 'Gagal menambah kos: ' . $stmt->error, null, 500);
    }
    $stmt->close();

    $sel = $conn->prepare('SELECT * FROM kos_listings WHERE id = ? LIMIT 1');
    $sel->bind_param('s', $id);
    $sel->execute();
    $row = $sel->get_result()->fetch_assoc();
    $sel->close();

    sendResponse(true, 'Kos berhasil ditambahkan', formatListing($row), 201);
}

function handlePut(mysqli $conn, string $ownerId, string $listingId): void
{
    $body = getJsonBody();

    if (!validateListingOwnership($conn, $listingId, $ownerId)) {
        sendResponse(false, 'Kos tidak ditemukan atau bukan milik Anda', null, 403);
    }

    $fields = [];
    $values = [];
    $types = '';

    if (isset($body['title'])) {
        $fields[] = 'title = ?';
        $values[] = trim((string)$body['title']);
        $types .= 's';
    }
    if (isset($body['location'])) {
        $fields[] = 'location = ?';
        $values[] = trim((string)$body['location']);
        $types .= 's';
    }
    if (isset($body['description'])) {
        $fields[] = 'description = ?';
        $values[] = trim((string)$body['description']);
        $types .= 's';
    }
    if (isset($body['price_per_month'])) {
        $fields[] = 'price_per_month = ?';
        $values[] = (int)$body['price_per_month'];
        $types .= 'i';
    }
    if (isset($body['owner_contact'])) {
        $fields[] = 'owner_contact = ?';
        $values[] = trim((string)$body['owner_contact']);
        $types .= 's';
    }
    if (isset($body['rating'])) {
        $fields[] = 'rating = ?';
        $values[] = (float)$body['rating'];
        $types .= 'd';
    }

    if (empty($fields)) {
        sendResponse(false, 'Tidak ada field yang diupdate', null, 400);
    }

    $values[] = $listingId;
    $types .= 's';

    $stmt = $conn->prepare('UPDATE kos_listings SET ' . implode(', ', $fields) . ' WHERE id = ?');
    $stmt->bind_param($types, ...$values);
    if (!$stmt->execute()) {
        sendResponse(false, 'Gagal update kos: ' . $stmt->error, null, 500);
    }
    $stmt->close();

    $sel = $conn->prepare('SELECT * FROM kos_listings WHERE id = ? LIMIT 1');
    $sel->bind_param('s', $listingId);
    $sel->execute();
    $row = $sel->get_result()->fetch_assoc();
    $sel->close();

    sendResponse(true, 'Kos berhasil diperbarui', formatListing($row));
}

function handleDelete(mysqli $conn, string $ownerId, string $listingId): void
{
    if (!validateListingOwnership($conn, $listingId, $ownerId)) {
        sendResponse(false, 'Kos tidak ditemukan atau bukan milik Anda', null, 403);
    }

    $stmt = $conn->prepare('DELETE FROM kos_listings WHERE id = ?');
    $stmt->bind_param('s', $listingId);
    if (!$stmt->execute()) {
        sendResponse(false, 'Gagal menghapus kos: ' . $stmt->error, null, 500);
    }
    $stmt->close();

    sendResponse(true, 'Kos berhasil dihapus');
}

function validateListingOwnership(mysqli $conn, string $listingId, string $ownerId): bool
{
    $stmt = $conn->prepare('SELECT id FROM kos_listings WHERE id = ? AND owner_id = ?');
    $stmt->bind_param('ss', $listingId, $ownerId);
    $stmt->execute();
    $stmt->store_result();
    $found = $stmt->num_rows > 0;
    $stmt->close();
    return $found;
}

function getJsonBody(): array
{
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        sendResponse(false, 'Invalid JSON request', null, 400);
    }
    return $data;
}

function formatListing(array $row): array
{
    return [
        'id' => $row['id'],
        'ownerId' => $row['owner_id'],
        'title' => $row['title'],
        'location' => $row['location'],
        'description' => $row['description'],
        'pricePerMonth' => (int)$row['price_per_month'],
        'rating' => (float)$row['rating'],
        'accessCode' => $row['access_code'],
        'ownerContact' => $row['owner_contact'],
        'createdAt' => $row['created_at'],
        'updatedAt' => $row['updated_at'],
    ];
}

function generateUuid(): string
{
    return sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}

function generateAccessCode(string $id): string
{
    $token = strtoupper(substr(str_replace('-', '', $id), 0, 6));
    return 'KOS-' . $token;
}

