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

$now = time();
$notifications = [
    [
        'id' => 'notif-1',
        'title' => 'Pembayaran Laundry Berhasil',
        'message' => 'Pembayaran untuk layanan laundry #L-9928 senilai Rp 45.000 telah kami terima. Pakaian Anda sedang diproses.',
        'type' => 'payment',
        'status' => 'baru',
        'createdAt' => date(DATE_ATOM, $now - 20 * 60),
        'hasAction' => true,
        'actionButtonText' => 'Lihat Detail',
    ],
    [
        'id' => 'notif-2',
        'title' => 'Pesanan Catering Gagal',
        'message' => 'Maaf, pesanan katering untuk makan siang hari ini dibatalkan karena ketersediaan menu. Saldo Anda telah dikembalikan.',
        'type' => 'catering',
        'status' => 'dibaca',
        'createdAt' => date(DATE_ATOM, $now - 2 * 60 * 60),
        'hasAction' => true,
        'actionButtonText' => 'Lihat Detail',
    ],
    [
        'id' => 'notif-3',
        'title' => 'Tagihan Kos Menunggu',
        'message' => 'Halo! Masa sewa kamar Anda akan berakhir dalam 3 hari. Segera lakukan pembayaran untuk bulan depan.',
        'type' => 'room',
        'status' => 'dibaca',
        'createdAt' => date(DATE_ATOM, $now - 24 * 60 * 60),
        'hasAction' => true,
        'actionButtonText' => 'Bayar Sekarang',
    ],
    [
        'id' => 'notif-4',
        'title' => 'Promo Khusus Member',
        'message' => 'Dapatkan diskon 20% untuk layanan cleaning service setiap akhir pekan selama bulan ini.',
        'type' => 'promo',
        'status' => 'dibaca',
        'createdAt' => date(DATE_ATOM, $now - 2 * 24 * 60 * 60),
        'hasAction' => false,
        'actionButtonText' => null,
    ],
];

echo json_encode([
    'success' => true,
    'message' => 'Notifikasi user berhasil dimuat',
    'data' => $notifications,
], JSON_UNESCAPED_UNICODE);
?>
