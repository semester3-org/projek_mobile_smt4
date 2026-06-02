# Team Setup

Panduan ini dipakai supaya hasil run antar laptop dan device tetap konsisten tanpa harus saling menimpa file konfigurasi.

## 1. Backend Lokal

Database default:

```text
DB_NAME=projek_kos
DB_HOST=localhost
DB_USER=root
DB_PASS=
```

Jalankan backend dari folder `backend`:

```powershell
php -S 0.0.0.0:8000 router.php
```

Jika konfigurasi database berbeda di laptop teman, jangan edit `backend/config/db.php`. Set environment variable lokal:

```powershell
$env:DB_HOST="localhost"
$env:DB_USER="root"
$env:DB_PASS=""
$env:DB_NAME="projek_kos"
```

## 2. API URL Flutter

Jangan edit `lib/core/api_service.dart` hanya untuk mengganti IP laptop. Pakai `--dart-define`.

Web atau desktop:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

Android emulator:

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

HP fisik satu Wi-Fi dengan laptop:

```powershell
flutter run -d <device-id> --dart-define=API_BASE_URL=http://<IP-LAPTOP>:8000
```

Cek IP laptop dari `ipconfig`, lalu pastikan firewall mengizinkan port `8000`.

## 3. Firebase

File client Firebase boleh sama untuk semua anggota tim:

```text
android/app/google-services.json
lib/firebase_options.dart
firebase.json
web/firebase-messaging-sw.js
```

Gunakan satu project Firebase yang sama untuk Google Login dan FCM agar tidak bentrok.

File private key Firebase Admin tidak boleh di-commit. Simpan lokal, misalnya:

```text
C:\Laragon\etc\firebase\service-account.json
```

Lalu set path credential di konfigurasi lokal backend. File lokal seperti `backend/config/firebase.local.php` sudah di-ignore oleh Git.

## 4. Setelah Pull

Jalankan ini setelah pull:

```powershell
flutter pub get
flutter analyze --no-pub
```

Untuk backend, cek cepat file PHP yang baru berubah:

```powershell
php -l backend/api/nama_file.php
```

## 5. Aturan Anti Conflict

- Jangan commit private key Firebase Admin.
- Jangan ganti IP lokal langsung di `api_service.dart`.
- Jangan edit `pubspec.lock` manual.
- Jika ada perubahan struktur database, simpan SQL/migrasi atau catatan perubahan.
- Gunakan satu `google-services.json` bersama jika project Firebase memang disatukan.
- Setelah resolve conflict, selalu run `flutter analyze --no-pub` sebelum push.

## 6. Permission Notifikasi dan Lokasi

Permission diminta setelah user berhasil login. Kalau permission sudah pernah diblokir permanen di Android, sistem tidak akan menampilkan popup lagi. Aktifkan ulang dari:

```text
Settings > Apps > Ngekos > Permissions
```

Untuk notifikasi background FCM di web, pastikan file ini bisa dibuka dari URL Flutter web:

```text
http://localhost:<flutter-port>/firebase-messaging-sw.js
```
