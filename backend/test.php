<?php
// Test endpoint
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

echo json_encode([
    'status' => 'success',
    'message' => 'API server is working!',
    'timestamp' => date('Y-m-d H:i:s')
]);
?>