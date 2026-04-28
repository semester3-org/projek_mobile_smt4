<?php

class JWT {
    // Ganti dengan string panjang & acak di production
    private static string $secret = 'GANTI_DENGAN_SECRET_KEY_YANG_PANJANG_DAN_AMAN';
    private static int $expireSeconds = 60 * 60 * 24 * 7; // 7 hari

    public static function generate(array $payload): string {
        $header = self::base64UrlEncode(json_encode([
            'alg' => 'HS256',
            'typ' => 'JWT'
        ]));

        $payload['iat'] = time();
        $payload['exp'] = time() + self::$expireSeconds;

        $payloadEncoded = self::base64UrlEncode(json_encode($payload));
        $signature = self::base64UrlEncode(
            hash_hmac('sha256', "$header.$payloadEncoded", self::$secret, true)
        );

        return "$header.$payloadEncoded.$signature";
    }

    public static function verify(string $token): ?array {
        $parts = explode('.', $token);
        if (count($parts) !== 3) return null;

        [$header, $payload, $signature] = $parts;

        $expectedSig = self::base64UrlEncode(
            hash_hmac('sha256', "$header.$payload", self::$secret, true)
        );

        if (!hash_equals($expectedSig, $signature)) return null;

        $data = json_decode(self::base64UrlDecode($payload), true);
        if (!$data) return null;

        // Cek expiry
        if (isset($data['exp']) && $data['exp'] < time()) return null;

        return $data;
    }

    // Ambil payload dari Authorization header, return null jika invalid
    public static function getPayloadFromRequest(): ?array {
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        if (!str_starts_with($authHeader, 'Bearer ')) return null;

        $token = substr($authHeader, 7);
        return self::verify($token);
    }

    private static function base64UrlEncode(string $data): string {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    private static function base64UrlDecode(string $data): string {
        return base64_decode(strtr($data, '-_', '+/'));
    }
}