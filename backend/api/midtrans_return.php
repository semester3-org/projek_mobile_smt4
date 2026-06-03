<?php
$status = htmlspecialchars((string)($_GET['transaction_status'] ?? $_GET['status_code'] ?? ''), ENT_QUOTES, 'UTF-8');
$orderId = htmlspecialchars((string)($_GET['order_id'] ?? ''), ENT_QUOTES, 'UTF-8');
$deepLinkQuery = http_build_query($_GET);
$deepLink = 'ngekos://payment' . ($deepLinkQuery === '' ? '' : '?' . $deepLinkQuery);
$deepLinkEscaped = htmlspecialchars($deepLink, ENT_QUOTES, 'UTF-8');

header('Content-Type: text/html; charset=utf-8');
?>
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Pembayaran NgeKos</title>
  <style>
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      font-family: Arial, sans-serif;
      background: #eef6ff;
      color: #162033;
    }
    .card {
      width: min(88vw, 420px);
      padding: 28px;
      border-radius: 20px;
      background: #fff;
      box-shadow: 0 18px 45px rgba(15, 23, 42, .12);
    }
    h1 {
      margin: 0 0 10px;
      color: #005b96;
      font-size: 24px;
    }
    p {
      margin: 8px 0;
      line-height: 1.5;
      color: #516179;
    }
    .meta {
      margin-top: 16px;
      padding: 12px;
      border-radius: 12px;
      background: #f3f7fb;
      font-size: 13px;
    }
    a.button {
      display: block;
      margin-top: 18px;
      padding: 14px 16px;
      border-radius: 12px;
      background: #005b96;
      color: #fff;
      text-align: center;
      text-decoration: none;
      font-weight: 700;
    }
  </style>
  <script>
    window.setTimeout(function () {
      window.location.href = <?= json_encode($deepLink) ?>;
    }, 600);
  </script>
</head>
<body>
  <main class="card">
    <h1>Pembayaran diproses</h1>
    <p>Status pembayaran sedang disinkronkan. Jika aplikasi tidak terbuka otomatis, tekan tombol di bawah.</p>
    <?php if ($orderId !== '' || $status !== ''): ?>
      <div class="meta">
        <?php if ($orderId !== ''): ?><p>Order: <?= $orderId ?></p><?php endif; ?>
        <?php if ($status !== ''): ?><p>Status: <?= $status ?></p><?php endif; ?>
      </div>
    <?php endif; ?>
    <a class="button" href="<?= $deepLinkEscaped ?>">Kembali ke aplikasi</a>
  </main>
</body>
</html>
