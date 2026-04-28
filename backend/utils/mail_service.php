<?php
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/mail.php';

function sendResetPasswordEmail(string $toEmail, string $toName, string $token): bool {
    $mail = new PHPMailer(true);
    try {
        $mail->isSMTP();
        $mail->Host       = MAIL_HOST;
        $mail->SMTPAuth   = true;
        $mail->Username   = MAIL_USERNAME;
        $mail->Password   = MAIL_PASSWORD;
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port       = MAIL_PORT;
        $mail->CharSet    = 'UTF-8';

        $mail->setFrom(MAIL_FROM_EMAIL, MAIL_FROM_NAME);
        $mail->addAddress($toEmail, $toName);

        // Deep link → buka Flutter app langsung
        $resetLink = "kosfinder://reset-password?token={$token}&email=" . urlencode($toEmail);

        $mail->isHTML(true);
        $mail->Subject = 'Reset Password - KosFinder';
        $mail->Body = "
        <div style='font-family:Arial,sans-serif;max-width:600px;margin:0 auto;'>
            <div style='background:#2e7d32;padding:20px;border-radius:8px 8px 0 0;'>
                <h2 style='color:white;margin:0;'>🏠 KosFinder</h2>
            </div>
            <div style='padding:30px;background:#f9f9f9;border-radius:0 0 8px 8px;'>
                <h3>Halo, {$toName}!</h3>
                <p>Kami menerima permintaan reset password untuk akun Anda.</p>
                <p>Klik tombol di bawah untuk membuat password baru. 
                   Link ini berlaku selama <strong>1 jam</strong>.</p>
                <div style='text-align:center;margin:30px 0;'>
                    <a href='{$resetLink}'
                       style='background:#2e7d32;color:white;padding:14px 32px;
                              border-radius:8px;text-decoration:none;font-size:16px;'>
                        Reset Password
                    </a>
                </div>
                <p style='color:#999;font-size:12px;'>
                    Jika Anda tidak meminta reset password, abaikan email ini.<br>
                    Token: <code>{$token}</code>
                </p>
            </div>
        </div>";

        $mail->AltBody = "Reset password KosFinder Anda: {$resetLink}\nToken: {$token}";
        $mail->send();
        return true;
    } catch (Exception $e) {
        error_log('Mailer Error: ' . $mail->ErrorInfo);
        return false;
    }
}