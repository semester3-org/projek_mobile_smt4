<?php
/**
 * Jalankan migrasi database + schema PHP (kompatibel MySQL 5.7+).
 * Usage: php database/run_migrations.php
 */
require_once __DIR__ . '/../backend/config/db.php';
require_once __DIR__ . '/../backend/api/merchant_helpers.php';

$files = [
    '2026-05-25-sync-projek-mobile-schema.sql',
    '2026-05-26-order-payment-subscription-address.sql',
    '2026-05-27-payment-methods-catering-improvements.sql',
    '2026-05-28-products-price20-finish.sql',
];

function runSqlFile(mysqli $conn, string $path): array {
    $sql = file_get_contents($path);
    if ($sql === false) {
        return ['ok' => false, 'error' => "Cannot read $path"];
    }

    $sql = preg_replace('/^\s*--.*$/m', '', $sql);
    $statements = array_filter(
        array_map('trim', preg_split('/;\s*[\r\n]+/', $sql)),
        fn($s) => $s !== ''
    );

    $executed = 0;
    $skipped = 0;
    foreach ($statements as $statement) {
        if ($conn->query($statement)) {
            $executed++;
            continue;
        }
        $err = $conn->error;
        if (preg_match('/Duplicate column|already exists|Duplicate key name|syntax/i', $err)) {
            $skipped++;
            continue;
        }
        return ['ok' => false, 'error' => $err, 'statement' => substr($statement, 0, 120)];
    }

    return ['ok' => true, 'executed' => $executed, 'skipped' => $skipped];
}

echo "Database: " . DB_NAME . " @ " . DB_HOST . "\n\n";

foreach ($files as $file) {
    $path = __DIR__ . '/' . $file;
    if (!is_file($path)) {
        echo "[SKIP] $file (file not found)\n";
        continue;
    }
    echo "Running $file ... ";
    $result = runSqlFile($conn, $path);
    if (!$result['ok']) {
        echo "WARN ({$result['error']}) — lanjut schema PHP\n";
    } else {
        echo "OK ({$result['executed']} executed, {$result['skipped']} skipped)\n";
    }
}

echo "\nApplying merchantEnsureSchema() ...\n";
try {
    merchantEnsureSchema($conn);
    echo "Schema PHP: OK\n";
} catch (Throwable $e) {
    echo "Schema PHP FAILED: " . $e->getMessage() . "\n";
    exit(1);
}

// Backfill cancellation window
if (merchantTableExists($conn, 'orders') && merchantColumnExists($conn, 'orders', 'cancellation_window_until')) {
    $conn->query("
        UPDATE orders
        SET cancellation_window_until = DATE_ADD(created_at, INTERVAL 5 SECOND)
        WHERE cancellation_window_until IS NULL AND created_at IS NOT NULL
    ");
}

echo "\nAll migrations completed.\n";
