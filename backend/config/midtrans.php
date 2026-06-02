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
define('MIDTRANS_FINISH_URL', getenv('MIDTRANS_FINISH_URL') ?: '');

function midtransCaBundlePath(): ?string {
    $path = realpath(__DIR__ . '/../vendor/midtrans/midtrans-php/data/cacert.pem');
    if ($path !== false && is_readable($path)) {
        return $path;
    }

    return null;
}

function midtransConfig(): void {
    \Midtrans\Config::$isProduction = MIDTRANS_IS_PRODUCTION;
    \Midtrans\Config::$serverKey = MIDTRANS_SERVER_KEY;
    \Midtrans\Config::$clientKey = MIDTRANS_CLIENT_KEY;
    \Midtrans\Config::$isSanitized = MIDTRANS_IS_SANITIZED;
    \Midtrans\Config::$is3ds = MIDTRANS_IS_3DS;

    $caBundle = midtransCaBundlePath();
    if ($caBundle !== null) {
        @ini_set('curl.cainfo', $caBundle);
        @ini_set('openssl.cafile', $caBundle);
        \Midtrans\Config::$curlOptions[\CURLOPT_CAINFO] = $caBundle;
        \Midtrans\Config::$curlOptions[\CURLOPT_SSL_VERIFYPEER] = true;
        \Midtrans\Config::$curlOptions[\CURLOPT_SSL_VERIFYHOST] = 2;
    }
}

function midtransSandboxInfo(): array {
    return [
        'merchant_id' => MIDTRANS_MERCHANT_ID,
        'is_production' => MIDTRANS_IS_PRODUCTION,
        'is_sanitized' => MIDTRANS_IS_SANITIZED,
        'is_3ds' => MIDTRANS_IS_3DS,
    ];
}

function midtransCallbackUrls(): array {
    $finishUrl = trim((string)MIDTRANS_FINISH_URL);
    if ($finishUrl === '') {
        $finishUrl = midtransDefaultReturnUrl();
    }
    if ($finishUrl === '') {
        return [];
    }

    return [
        'finish' => $finishUrl,
        'unfinish' => $finishUrl,
        'error' => $finishUrl,
    ];
}

function midtransDefaultReturnUrl(): string {
    $host = trim((string)($_SERVER['HTTP_HOST'] ?? ''));
    if ($host === '') {
        return '';
    }

    $https = strtolower((string)($_SERVER['HTTPS'] ?? ''));
    $scheme = ($https !== '' && $https !== 'off') ? 'https' : 'http';
    $scriptName = str_replace('\\', '/', (string)($_SERVER['SCRIPT_NAME'] ?? ''));
    if (substr($scriptName, -strlen('/api/midtrans.php')) === '/api/midtrans.php') {
        $basePath = rtrim(str_replace('\\', '/', dirname(dirname($scriptName))), '/');
    } else {
        $basePath = rtrim(str_replace('\\', '/', dirname($scriptName)), '/');
    }
    if ($basePath === '.' || $basePath === '/') {
        $basePath = '';
    }
    if (substr($basePath, -4) === '/api') {
        $basePath = substr($basePath, 0, -4);
    }

    return $scheme . '://' . $host . $basePath . '/api/midtrans_return';
}
