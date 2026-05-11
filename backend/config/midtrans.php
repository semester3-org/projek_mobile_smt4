<?php
// backend/config/midtrans.php

// Anda bisa menyimpan kredensial di environment variable untuk produksi.
// Untuk development, default sandbox ditetapkan di sini.

define('MIDTRANS_MERCHANT_ID', getenv('MIDTRANS_MERCHANT_ID') ?: 'M653801794');
define('MIDTRANS_SERVER_KEY', getenv('MIDTRANS_SERVER_KEY') ?: 'Mid-server-eWiAS5ij_4cexF7hnHVUxMHQ');
define('MIDTRANS_CLIENT_KEY', getenv('MIDTRANS_CLIENT_KEY') ?: 'Mid-client-wSNPcqKn7PAy8W0Z');
define('MIDTRANS_IS_PRODUCTION', filter_var(getenv('MIDTRANS_IS_PRODUCTION') ?: 'false', FILTER_VALIDATE_BOOLEAN));
define('MIDTRANS_IS_SANITIZED', filter_var(getenv('MIDTRANS_IS_SANITIZED') ?: 'true', FILTER_VALIDATE_BOOLEAN));
define('MIDTRANS_IS_3DS', filter_var(getenv('MIDTRANS_IS_3DS') ?: 'true', FILTER_VALIDATE_BOOLEAN));

function midtransConfig(): void {
    \Midtrans\Config::$isProduction = MIDTRANS_IS_PRODUCTION;
    \Midtrans\Config::$serverKey = MIDTRANS_SERVER_KEY;
    \Midtrans\Config::$clientKey = MIDTRANS_CLIENT_KEY;
    \Midtrans\Config::$isSanitized = MIDTRANS_IS_SANITIZED;
    \Midtrans\Config::$is3ds = MIDTRANS_IS_3DS;
}

function midtransSandboxInfo(): array {
    return [
        'merchant_id' => MIDTRANS_MERCHANT_ID,
        'is_production' => MIDTRANS_IS_PRODUCTION,
        'is_sanitized' => MIDTRANS_IS_SANITIZED,
        'is_3ds' => MIDTRANS_IS_3DS,
    ];
}
