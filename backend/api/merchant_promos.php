<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

require_once __DIR__ . '/merchant_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

function merchantPromoProduct(mysqli $conn, string $merchantId, ?string $productId): ?array {
    if (!$productId) return null;
    $stmt = $conn->prepare("SELECT * FROM products WHERE id = ? AND merchant_id = ? AND is_active = 1 LIMIT 1");
    if (!$stmt) return null;
    $stmt->bind_param('ss', $productId, $merchantId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

function merchantNormalizeDate(?string $value): ?string {
    if ($value === null || trim($value) === '') return null;
    $time = strtotime($value);
    return $time ? date('Y-m-d H:i:s', $time) : null;
}

function merchantPromoDateOverlaps(?string $startA, ?string $endA, ?string $startB, ?string $endB): bool {
    $aStart = $startA ? strtotime($startA) : PHP_INT_MIN;
    $aEnd = $endA ? strtotime($endA) : PHP_INT_MAX;
    $bStart = $startB ? strtotime($startB) : PHP_INT_MIN;
    $bEnd = $endB ? strtotime($endB) : PHP_INT_MAX;
    return $aStart <= $bEnd && $bStart <= $aEnd;
}

function merchantPromoResolvedProductIds(mysqli $conn, array $promo): array {
    $promoId = (int)($promo['id'] ?? 0);
    $ids = $promoId > 0 ? merchantPromoProductIds($conn, $promoId) : [];
    $mainProductId = (int)($promo['product_id'] ?? 0);
    if (empty($ids) && $mainProductId > 0) {
        $ids = [(string)$mainProductId];
    }
    return array_values(array_unique(array_map('strval', $ids)));
}

function merchantPromoEnsureNoActiveTargetConflict(
    mysqli $conn,
    string $merchantId,
    string $currentPromoId,
    ?int $nullableProductId,
    array $productIds,
    ?string $startAt,
    ?string $endAt,
    int $isActive,
    string $status
): void {
    if ($isActive !== 1 || $status !== 'active') return;

    $targetIds = array_values(array_unique(array_map('strval', $productIds)));
    if (empty($targetIds) && $nullableProductId !== null && $nullableProductId > 0) {
        $targetIds = [(string)$nullableProductId];
    }
    $targetsAllProducts = empty($targetIds);

    $stmt = $conn->prepare("
        SELECT id, name, product_id, start_at, end_at
        FROM merchant_promos
        WHERE merchant_id = ?
          AND CAST(id AS CHAR) <> ?
          AND is_active = 1
          AND status = 'active'
          AND (end_at IS NULL OR end_at >= NOW())
    ");
    if (!$stmt) {
        merchantSendJson(false, null, 'Gagal memvalidasi promo aktif', 500);
    }
    $stmt->bind_param('ss', $merchantId, $currentPromoId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    foreach ($rows as $row) {
        if (!merchantPromoDateOverlaps($startAt, $endAt, $row['start_at'] ?? null, $row['end_at'] ?? null)) {
            continue;
        }
        $existingTargetIds = merchantPromoResolvedProductIds($conn, $row);
        $existingTargetsAllProducts = empty($existingTargetIds);
        $hasTargetConflict = $targetsAllProducts ||
            $existingTargetsAllProducts ||
            !empty(array_intersect($targetIds, $existingTargetIds));

        if ($hasTargetConflict) {
            $promoName = trim((string)($row['name'] ?? 'promo aktif'));
            merchantSendJson(
                false,
                null,
                'Produk ini sudah memiliki promo aktif (' . $promoName . '). Nonaktifkan promo tersebut sebelum membuat promo baru untuk target yang sama.',
                409
            );
        }
    }
}

try {
    $payload = merchantRequireMerchant();
    $merchant = merchantCurrent($conn, $payload);
    $merchantId = (string)$merchant['id'];
    merchantExpirePromos($conn, $merchantId);

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $id = trim($_GET['id'] ?? '');
        $where = 'mp.merchant_id = ?';
        $types = 's';
        $params = [$merchantId];
        if ($id !== '') {
            $where .= ' AND CAST(mp.id AS CHAR) = ?';
            $types .= 's';
            $params[] = $id;
        }

        $stmt = $conn->prepare("
            SELECT mp.*, p.nama_produk
            FROM merchant_promos mp
            LEFT JOIN products p ON p.id = mp.product_id
            WHERE $where
            ORDER BY mp.is_active DESC, mp.end_at DESC, mp.id DESC
        ");
        if (!$stmt) {
            merchantSendJson(false, null, 'Gagal memproses promo. Silakan coba lagi.', 500);
        }
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();

        $data = array_map(function ($row) use ($conn) {
            $payload = merchantPromoPayload($row);
            $payload['productIds'] = merchantPromoProductIds($conn, (int)($row['id'] ?? 0));
            if (empty($payload['productIds']) && !empty($payload['productId'])) {
                $payload['productIds'] = [(string)$payload['productId']];
            }
            if (count($payload['productIds']) === 1 && empty($payload['productId'])) {
                $prod = merchantPromoProduct($conn, $row['merchant_id'], $payload['productIds'][0]);
                if ($prod) {
                    $payload['productId'] = (string)$prod['id'];
                    $payload['productName'] = $prod['nama_produk'];
                }
            }
            return $payload;
        }, $rows);
        if ($id !== '') {
            if (empty($data)) {
                merchantSendJson(false, null, 'Promo tidak ditemukan', 404);
            }
            merchantSendJson(true, $data[0], 'Promo berhasil dimuat');
        }
        merchantSendJson(true, $data, 'Promo merchant berhasil dimuat');
    }

    $body = merchantBody();
    $id = trim((string)($body['id'] ?? $_GET['id'] ?? ''));
    $name = trim((string)($body['name'] ?? ''));
    $description = trim((string)($body['description'] ?? ''));
    $productId = trim((string)($body['productId'] ?? ''));
    $discountType = strtolower(trim((string)($body['discountType'] ?? 'percentage')));
    $discountValue = (float)($body['discountValue'] ?? 0);
    $minOrder = (float)($body['minOrderAmount'] ?? 0);
    $maxDiscount = (float)($body['maxDiscountAmount'] ?? 0);
    $startAt = merchantNormalizeDate($body['startAt'] ?? null);
    $endAt = merchantNormalizeDate($body['endAt'] ?? null);
    $isActive = !array_key_exists('isActive', $body) || !empty($body['isActive']) ? 1 : 0;
    $requestedStatus = strtolower(trim((string)($body['status'] ?? '')));
    if (!in_array($requestedStatus, ['draft', 'active', 'inactive'], true)) {
        $requestedStatus = $isActive ? 'active' : 'draft';
    }
    if ($requestedStatus === 'active') {
        $isActive = 1;
    } elseif ($requestedStatus === 'inactive' || $requestedStatus === 'draft') {
        $isActive = 0;
    }
    $usageLimit = isset($body['usageLimit']) && $body['usageLimit'] !== '' ? (int)$body['usageLimit'] : null;
    $perUserUsageLimit = max(1, (int)($body['perUserUsageLimit'] ?? 1));
    $productIds = [];
    $rawProductIds = $body['productIds'] ?? [];
    if (is_array($rawProductIds)) {
        foreach ($rawProductIds as $rawId) {
            $pid = (int)(is_array($rawId) ? ($rawId['id'] ?? $rawId['productId'] ?? 0) : $rawId);
            if ($pid > 0) {
                $productIds[] = $pid;
            }
        }
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST' || $_SERVER['REQUEST_METHOD'] === 'PUT') {
        if ($requestedStatus !== 'draft') {
            if ($name === '') {
                merchantSendJson(false, null, 'Nama promo wajib diisi', 400);
            }
            if (!in_array($discountType, ['percentage', 'fixed'], true)) {
                merchantSendJson(false, null, 'Tipe diskon tidak valid', 400);
            }
            if ($discountValue <= 0) {
                merchantSendJson(false, null, 'Nilai promo wajib lebih dari 0', 400);
            }
            if ($discountType === 'percentage' && $discountValue > 100) {
                merchantSendJson(false, null, 'Diskon persentase maksimal 100%', 400);
            }
            if ($discountType === 'percentage' && $maxDiscount <= 0) {
                merchantSendJson(false, null, 'Maksimal potongan wajib diisi untuk promo persentase', 400);
            }
            if ($endAt !== null && $startAt !== null && strtotime($endAt) <= strtotime($startAt)) {
                merchantSendJson(false, null, 'Tanggal berakhir harus setelah tanggal mulai', 400);
            }
    
            if (!empty($productIds)) {
                foreach ($productIds as $pid) {
                    $validProduct = merchantPromoProduct($conn, $merchantId, (string)$pid);
                    if (!$validProduct) {
                        merchantSendJson(false, null, 'Ada produk promo yang tidak valid', 400);
                    }
                }
            }
        } else {
            if ($name === '') $name = 'Draft Promo';
        }
        
        if (!empty($productIds)) {
            $nullableProductId = count($productIds) === 1 ? (int)$productIds[0] : null;
        } else {
            $product = merchantPromoProduct($conn, $merchantId, $productId !== '' ? $productId : null);
            if ($productId !== '' && !$product) {
                merchantSendJson(false, null, 'Produk promo tidak ditemukan', 404);
            }
            if ($product && $minOrder < (float)$product['harga']) {
                merchantSendJson(false, null, 'Minimal transaksi harus setidaknya sama dengan harga produk yang dipilih', 400);
            }
            $nullableProductId = $product ? (int)$product['id'] : null;
        }

        $wasActiveBeforeUpdate = false;
        $wasExpiredBeforeUpdate = false;
        $hasBroadcastedBefore = false;
        if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
            $prev = $conn->prepare("
                SELECT is_active, status, start_at, end_at, product_id,
                       used_count,
                       discount_type, discount_value, max_discount_amount,
                       per_user_usage_limit, first_broadcast_at
                FROM merchant_promos
                WHERE id = ? AND merchant_id = ?
                LIMIT 1
            ");
            if ($prev) {
                $prev->bind_param('ss', $id, $merchantId);
                $prev->execute();
                $prevRow = $prev->get_result()->fetch_assoc();
                $prev->close();
                if ($prevRow) {
                    $now = time();
                    $prevStartAt = $prevRow['start_at'] ?? null;
                    $prevEndAt = $prevRow['end_at'] ?? null;
                    $wasActiveBeforeUpdate = (int)($prevRow['is_active'] ?? 0) === 1
                        && (!$prevStartAt || strtotime((string)$prevStartAt) <= $now)
                        && (!$prevEndAt || strtotime((string)$prevEndAt) >= $now);
                    $hasBroadcastedBefore = !empty($prevRow['first_broadcast_at']);
                    $prevStatus = strtolower(trim((string)($prevRow['status'] ?? '')));
                    $wasExpiredBeforeUpdate = $prevStatus === 'expired'
                        || ($prevEndAt && strtotime((string)$prevEndAt) < $now);

                    if ($wasExpiredBeforeUpdate) {
                        merchantSendJson(false, null, 'Promo expired tidak dapat diubah.', 409);
                    }

                    $prevDiscountType = strtolower(trim((string)($prevRow['discount_type'] ?? 'percentage')));
                    $prevDiscountValue = (float)($prevRow['discount_value'] ?? 0);
                    $prevMaxDiscount = (float)($prevRow['max_discount_amount'] ?? 0);
                    $discountChanged = $prevDiscountType !== $discountType
                        || abs($prevDiscountValue - $discountValue) > 0.0001
                        || abs($prevMaxDiscount - $maxDiscount) > 0.0001;

                    $prevProductIds = merchantPromoProductIds($conn, (int)$id);
                    if (empty($prevProductIds) && (int)($prevRow['product_id'] ?? 0) > 0) {
                        $prevProductIds = [(string)((int)$prevRow['product_id'])];
                    }
                    $newProductIds = array_map('strval', $productIds);
                    if (empty($newProductIds) && (int)($nullableProductId ?? 0) > 0) {
                        $newProductIds = [(string)((int)$nullableProductId)];
                    }
                    sort($prevProductIds);
                    sort($newProductIds);
                    $productChanged = $prevProductIds !== $newProductIds;
                    $startChanged = (string)($prevRow['start_at'] ?? '') !== (string)($startAt ?? '');
                    $perUserChanged = (int)($prevRow['per_user_usage_limit'] ?? 1) !== $perUserUsageLimit;

                    if ($wasActiveBeforeUpdate && $isActive === 1 && $discountChanged) {
                        merchantSendJson(false, null, 'Promo yang sudah aktif tidak dapat mengubah jenis dan nilai diskon.', 409);
                    }
                    if ($wasActiveBeforeUpdate && $isActive === 1 && ($productChanged || $startChanged || $perUserChanged)) {
                        merchantSendJson(false, null, 'Promo aktif hanya dapat mengubah nama, deskripsi, tanggal akhir, total kuota, dan status.', 409);
                    }
                }
            }
        }

        merchantPromoEnsureNoActiveTargetConflict(
            $conn,
            $merchantId,
            $id,
            $nullableProductId,
            $productIds,
            $startAt,
            $endAt,
            $isActive,
            $requestedStatus
        );

        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $stmt = $conn->prepare("
                INSERT INTO merchant_promos
                    (merchant_id, product_id, name, description, discount_type, discount_value,
                     min_order_amount, max_discount_amount, start_at, end_at, is_active, status, usage_limit,
                     per_user_usage_limit, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Gagal memproses promo. Silakan coba lagi.', 500);
            }
            $stmt->bind_param(
                'sisssdddssisii',
                $merchantId,
                $nullableProductId,
                $name,
                $description,
                $discountType,
                $discountValue,
                $minOrder,
                $maxDiscount,
                $startAt,
                $endAt,
                $isActive,
                $requestedStatus,
                $usageLimit,
                $perUserUsageLimit
            );
            $stmt->execute();
            $id = (string)$conn->insert_id;
            $stmt->close();
        } else {
            if ($id === '') {
                merchantSendJson(false, null, 'ID promo wajib diisi', 400);
            }
            $stmt = $conn->prepare("
                UPDATE merchant_promos
                SET product_id = ?,
                    name = ?,
                    description = ?,
                    discount_type = ?,
                    discount_value = ?,
                    min_order_amount = ?,
                    max_discount_amount = ?,
                    start_at = ?,
                    end_at = ?,
                    is_active = ?,
                    status = ?,
                    usage_limit = ?,
                    per_user_usage_limit = ?,
                    updated_at = NOW()
                WHERE id = ? AND merchant_id = ?
            ");
            if (!$stmt) {
                merchantSendJson(false, null, 'Gagal memproses promo. Silakan coba lagi.', 500);
            }
            $stmt->bind_param(
                'isssdddssisiiss',
                $nullableProductId,
                $name,
                $description,
                $discountType,
                $discountValue,
                $minOrder,
                $maxDiscount,
                $startAt,
                $endAt,
                $isActive,
                $requestedStatus,
                $usageLimit,
                $perUserUsageLimit,
                $id,
                $merchantId
            );
            $stmt->execute();
            $stmt->close();
        }

        merchantPromoSyncProducts($conn, (int)$id, $productIds);

        $stmt = $conn->prepare("
            SELECT mp.*, p.nama_produk
            FROM merchant_promos mp
            LEFT JOIN products p ON p.id = mp.product_id
            WHERE mp.id = ? AND mp.merchant_id = ?
            LIMIT 1
        ");
        $stmt->bind_param('ss', $id, $merchantId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        $promo = merchantPromoPayload($row ?? []);
        $promo['productIds'] = merchantPromoProductIds($conn, (int)$id);
        if (empty($promo['productIds']) && !empty($promo['productId'])) {
            $promo['productIds'] = [(string)$promo['productId']];
        }
        if (count($promo['productIds']) === 1 && empty($promo['productId'])) {
            $prod = merchantPromoProduct($conn, $merchantId, $promo['productIds'][0]);
            if ($prod) {
                $promo['productId'] = (string)$prod['id'];
                $promo['productName'] = $prod['nama_produk'];
            }
        }

        $shouldBroadcastPromo = $promo['status'] === 'active'
            && ($_SERVER['REQUEST_METHOD'] === 'POST' || !$hasBroadcastedBefore);
        if ($shouldBroadcastPromo) {
            $users = $conn->query("SELECT id FROM users WHERE role = 'user'");
            $promoTitle = $name !== '' ? $name : 'Promo baru';
            $promoMessage = $description !== ''
                ? $description
                : 'Promo sudah aktif. Cek produk yang sedang promo sebelum periode berakhir.';
            if ($users) {
                while ($user = $users->fetch_assoc()) {
                    merchantCreateNotification(
                        $conn,
                        (string)$user['id'],
                        $promoTitle,
                        $promoMessage,
                        'promo',
                        'Lihat Promo',
                        'promo:' . $merchantId,
                        'high'
                    );
                }
            }
            $broadcastStmt = $conn->prepare("
                UPDATE merchant_promos
                SET first_broadcast_at = COALESCE(first_broadcast_at, NOW())
                WHERE id = ? AND merchant_id = ?
            ");
            if ($broadcastStmt) {
                $broadcastStmt->bind_param('ss', $id, $merchantId);
                $broadcastStmt->execute();
                $broadcastStmt->close();
            }
        }

        merchantSendJson(true, $promo, 'Promo berhasil disimpan');
    }

    if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        if ($id === '') {
            merchantSendJson(false, null, 'ID promo wajib diisi', 400);
        }
        $current = $conn->prepare("SELECT status, used_count FROM merchant_promos WHERE id = ? AND merchant_id = ? LIMIT 1");
        if (!$current) {
            merchantSendJson(false, null, 'Gagal memproses promo. Silakan coba lagi.', 500);
        }
        $current->bind_param('ss', $id, $merchantId);
        $current->execute();
        $row = $current->get_result()->fetch_assoc();
        $current->close();
        if (!$row) {
            merchantSendJson(false, null, 'Promo tidak ditemukan', 404);
        }

        $status = strtolower(trim((string)($row['status'] ?? '')));
        $usedCount = (int)($row['used_count'] ?? 0);
        if ($status === 'draft' && $usedCount === 0) {
            merchantPromoSyncProducts($conn, (int)$id, []);
            $stmt = $conn->prepare("DELETE FROM merchant_promos WHERE id = ? AND merchant_id = ?");
            if (!$stmt) {
                merchantSendJson(false, null, 'Gagal memproses promo. Silakan coba lagi.', 500);
            }
            $stmt->bind_param('ss', $id, $merchantId);
            $stmt->execute();
            $affected = $stmt->affected_rows;
            $stmt->close();
            if ($affected <= 0) {
                merchantSendJson(false, null, 'Promo tidak ditemukan', 404);
            }
            merchantSendJson(true, ['id' => $id], 'Draft promo berhasil dihapus');
        }

        $stmt = $conn->prepare("UPDATE merchant_promos SET is_active = 0, status = 'inactive', updated_at = NOW() WHERE id = ? AND merchant_id = ? AND status <> 'expired'");
        if (!$stmt) {
            merchantSendJson(false, null, 'Gagal memproses promo. Silakan coba lagi.', 500);
        }
        $stmt->bind_param('ss', $id, $merchantId);
        $stmt->execute();
        $affected = $stmt->affected_rows;
        $stmt->close();
        if ($affected <= 0) {
            merchantSendJson(false, null, 'Promo tidak ditemukan atau sudah nonaktif', 404);
        }
        merchantSendJson(true, ['id' => $id], 'Promo berhasil dinonaktifkan');
    }

    merchantSendJson(false, null, 'Method tidak didukung', 405);
} catch (Throwable $e) {
    merchantSendJson(false, null, 'Gagal memproses promo. Silakan coba lagi.', 500);
}

?>
