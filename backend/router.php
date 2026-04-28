<?php
// This router is used when running PHP with: php -S localhost:8000 router.php

// Get the requested path
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

// Remove leading slash
$path = ltrim($path, '/');

// If path is empty or it's a physical file/directory, serve it directly
if (empty($path) || is_file($path) || is_dir($path)) {
    return false; // Let the server handle it
}

// Otherwise, route all requests to index.php
require_once 'index.php';
?>
