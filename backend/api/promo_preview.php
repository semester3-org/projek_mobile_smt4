<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    merchantSendJson(false, null, 'Only POST method allowed', 405);
}

try {
    merchantEnsureSchema($conn);
    $payload = merchantRequireAuth();
    $body = merchantBody();

    $subtotal = (float)($body['subtotal'] ?? 0);
    $merchantId = trim((string)($body['merchantId'] ?? ''));
    if ($merchantId === '' && (($payload['role'] ?? '') === 'merchant')) {
        $merchant = merchantCurrent($conn, $payload);
        $merchantId = (string)($merchant['id'] ?? '');
    }

    if ($merchantId === '') {
        merchantSendJson(false, null, 'Merchant tidak valid', 400);
    }

    $itemInputs = $body['items'] ?? [];
    $items = [];
    if (is_array($itemInputs)) {
        foreach ($itemInputs as $item) {
            if (!is_array($item)) continue;
            $productId = (int)($item['productId'] ?? 0);
            if ($productId > 0) {
                $items[] = ['productId' => $productId];
            }
        }
    }

    $draftType = strtolower(trim((string)($body['discountType'] ?? '')));
    $draftValue = (float)($body['discountValue'] ?? 0);
    $draftMinOrder = (float)($body['minOrderAmount'] ?? 0);
    $draftMaxDiscount = (float)($body['maxDiscountAmount'] ?? 0);
    $isDraftPreview = $draftType !== '' && $draftValue > 0;

    if ($subtotal <= 0) {
        merchantSendJson(true, [
            'subtotal' => 0,
            'discountAmount' => 0,
            'total' => 0,
            'eligible' => false,
            'message' => 'Subtotal simulasi belum diisi',
        ], 'Preview promo kosong');
    }

    if ($isDraftPreview) {
        if ($draftMinOrder > 0 && $subtotal < $draftMinOrder) {
            merchantSendJson(true, [
                'subtotal' => round($subtotal, 2),
                'discountAmount' => 0,
                'total' => round($subtotal, 2),
                'eligible' => false,
                'message' => 'Minimum transaksi belum terpenuhi untuk preview ini',
            ], 'Preview promo tidak memenuhi syarat');
        }

        $draftPromo = [
            'discount_type' => in_array($draftType, ['percentage', 'fixed'], true) ? $draftType : 'percentage',
            'discount_value' => $draftValue,
            'max_discount_amount' => $draftMaxDiscount,
        ];
        $applied = merchantPromoApply($subtotal, $draftPromo);
        merchantSendJson(true, [
            'subtotal' => round($subtotal, 2),
            'discountAmount' => round((float)$applied['discount'], 2),
            'total' => round((float)$applied['total'], 2),
            'eligible' => (float)$applied['discount'] > 0,
            'message' => (float)$applied['discount'] > 0
                ? 'Simulasi konfigurasi promo saat ini'
                : 'Konfigurasi promo belum menghasilkan potongan',
            'promo' => [
                'name' => trim((string)($body['name'] ?? 'Draft Promo')),
                'discountType' => $draftPromo['discount_type'],
                'discountValue' => $draftValue,
                'maxDiscountAmount' => $draftMaxDiscount,
                'minOrderAmount' => $draftMinOrder,
            ],
        ], 'Preview promo berhasil');
    }

    if (empty($items)) {
        merchantSendJson(true, [
            'subtotal' => round($subtotal, 2),
            'discountAmount' => 0,
            'total' => round($subtotal, 2),
            'eligible' => false,
            'message' => 'Pilih produk untuk simulasi promo',
        ], 'Preview promo kosong');
    }

    $userId = (string)($payload['sub'] ?? '');
    $best = merchantBestPromoForCheckout($conn, $merchantId, $userId, $subtotal, $items);
    if ($best === null) {
        merchantSendJson(true, [
            'subtotal' => round($subtotal, 2),
            'discountAmount' => 0,
            'total' => round($subtotal, 2),
            'eligible' => false,
            'message' => 'Tidak ada promo aktif yang memenuhi syarat',
        ], 'Preview promo tidak memenuhi syarat');
    }

    $promo = $best['promo'];
    merchantSendJson(true, [
        'subtotal' => round($subtotal, 2),
        'discountAmount' => round((float)$best['discount'], 2),
        'total' => round((float)$best['total'], 2),
        'eligible' => true,
        'message' => 'Menggunakan promo aktif terbaik di sistem',
        'promo' => [
            'id' => (string)$promo['id'],
            'name' => (string)($promo['name'] ?? ''),
            'discountType' => (string)($promo['discount_type'] ?? 'percentage'),
            'discountValue' => (float)($promo['discount_value'] ?? 0),
            'maxDiscountAmount' => (float)($promo['max_discount_amount'] ?? 0),
            'minOrderAmount' => (float)($promo['min_order_amount'] ?? 0),
        ],
    ], 'Preview promo berhasil');
} catch (Throwable $e) {
    merchantSendJson(false, null, $e->getMessage(), 500);
}

?>
