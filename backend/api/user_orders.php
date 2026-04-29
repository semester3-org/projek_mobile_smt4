<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Only GET method allowed']);
    exit();
}

$orders = [
    [
        'id' => 'SR-CATER-88219',
        'merchantName' => 'Dapur Nusantara',
        'service' => 'catering',
        'orderDate' => '2023-10-24T14:20:00',
        'deliveryDate' => '2023-10-24T18:00:00',
        'totalAmount' => 90000,
        'status' => 'pending',
        'paymentMethod' => 'GOPAY',
        'items' => [
            [
                'name' => 'Nasi Goreng Spesial Nusantara',
                'quantity' => 2,
                'price' => 35000,
                'subtotal' => 70000,
            ],
            [
                'name' => 'Es Jeruk Peras Murni',
                'quantity' => 1,
                'price' => 15000,
                'subtotal' => 15000,
            ],
        ],
    ],
    [
        'id' => 'SR-LAUNDRY-001',
        'merchantName' => 'Clean & Fresh Laundry Express',
        'service' => 'laundry',
        'orderDate' => '2023-10-24T14:20:00',
        'deliveryDate' => null,
        'totalAmount' => 70000,
        'status' => 'pending',
        'paymentMethod' => 'GOPAY',
        'items' => [
            [
                'name' => 'Cuci Lipat (Regular)',
                'quantity' => 5,
                'price' => 8000,
                'subtotal' => 40000,
            ],
            [
                'name' => 'Cuci Satuan - Jaket',
                'quantity' => 1,
                'price' => 25000,
                'subtotal' => 25000,
            ],
        ],
    ],
];

echo json_encode([
    'success' => true,
    'message' => 'Pesanan user berhasil dimuat',
    'data' => $orders,
], JSON_UNESCAPED_UNICODE);
?>
