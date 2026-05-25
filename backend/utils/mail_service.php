<?php
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/mail.php';

function getResetMailConfigError(): ?string {
    if (MAIL_USERNAME === 'emailkamu@gmail.com' || MAIL_FROM_EMAIL === 'emailkamu@gmail.com') {
        return 'Konfigurasi email pengirim belum diganti di backend/config/mail.php';
    }

    $mailPassword = preg_replace('/\s+/', '', MAIL_PASSWORD);

    if (MAIL_PASSWORD === 'abcd efgh ijkl mnop' || $mailPassword === '') {
        return 'App Password Gmail belum diganti di backend/config/mail.php';
    }

    if (MAIL_USERNAME !== MAIL_FROM_EMAIL) {
        return 'MAIL_USERNAME dan MAIL_FROM_EMAIL harus memakai akun Gmail yang sama';
    }

    return null;
}

function sendResetPasswordEmail(string $toEmail, string $toName, string $token): bool {
    $mail = new PHPMailer(true);

    try {
        $configError = getResetMailConfigError();
        if ($configError !== null) {
            error_log('Mailer Config Error: ' . $configError);
            return false;
        }

        $safeName = htmlspecialchars($toName, ENT_QUOTES, 'UTF-8');
        $safeToken = htmlspecialchars($token, ENT_QUOTES, 'UTF-8');

        $mail->isSMTP();
        $mail->Host       = MAIL_HOST;
        $mail->SMTPAuth   = true;
        $mail->Username   = MAIL_USERNAME;
        $mail->Password   = preg_replace('/\s+/', '', MAIL_PASSWORD);
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port       = MAIL_PORT;
        $mail->CharSet    = 'UTF-8';

        $mail->setFrom(MAIL_FROM_EMAIL, MAIL_FROM_NAME);
        $mail->addAddress($toEmail, $toName);

        $mail->isHTML(true);
        $mail->Subject = 'Token Reset Password - KosFinder';
        $mail->Body = "
        <div style='font-family:Arial,sans-serif;max-width:600px;margin:0 auto;'>
            <div style='background:#2e7d32;padding:20px;border-radius:8px 8px 0 0;'>
                <h2 style='color:white;margin:0;'>KosFinder</h2>
            </div>
            <div style='padding:30px;background:#f9f9f9;border-radius:0 0 8px 8px;'>
                <h3>Halo, {$safeName}!</h3>
                <p>Kami menerima permintaan reset password untuk akun Anda.</p>
                <p>Masukkan token berikut di halaman reset password. Token ini berlaku selama <strong>1 jam</strong>.</p>
                <div style='text-align:center;margin:30px 0;'>
                    <div style='display:inline-block;background:#ffffff;border:1px solid #d6d6d6;border-radius:8px;
                                padding:14px 28px;font-size:28px;font-weight:bold;letter-spacing:6px;color:#2e7d32;'>
                        {$safeToken}
                    </div>
                </div>
                <p style='color:#999;font-size:12px;'>
                    Jika Anda tidak meminta reset password, abaikan email ini.
                </p>
            </div>
        </div>";

        $mail->AltBody = "Token reset password KosFinder Anda: {$token}\nToken berlaku selama 1 jam.";
        $mail->send();
        return true;
    } catch (Exception $e) {
        error_log('Mailer Error: ' . $mail->ErrorInfo . ' | Exception: ' . $e->getMessage());
        return false;
    }
}
