<?php
header('Content-Type: application/json');

// Test database connection
$conn = new mysqli('localhost', 'root', '', 'projek_kos');

if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Database connection failed',
        'error' => $conn->connect_error
    ]);
    exit();
}

// Test query
$result = $conn->query("SELECT COUNT(*) as user_count FROM users");
$row = $result->fetch_assoc();

echo json_encode([
    'status' => 'success',
    'message' => 'Database connected!',
    'users_count' => $row['user_count']
]);

$conn->close();
?>
