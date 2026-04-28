# Backend API - KosFinder

Backend PHP untuk aplikasi KosFinder menggunakan MySQL database dan REST API untuk autentikasi.

## Setup Requirements

- PHP 7.4+ dengan ekstensi MySQLi
- MySQL 5.7+
- Apache dengan mod_rewrite enabled

## Struktur Folder

```
backend/
├── config/
│   └── db.php          # Database connection configuration
├── api/
│   ├── login.php       # POST /api/login endpoint
│   └── register.php    # POST /api/register endpoint
├── utils/
│   └── response.php    # Helper functions untuk response
├── .htaccess           # CORS dan routing configuration
└── index.php           # Main router
```

## Setup Instructions

### 1. Pastikan Database Sudah Dibuat

```bash
# Import database schema
mysql -u root < database/projek_kos_schema.sql
mysql -u root < database/projek_kos_dummy_data.sql
```

### 2. Konfigurasi Database (config/db.php)

Pastikan kredensial database sudah sesuai:

```php
define('DB_HOST', 'localhost');
define('DB_USER', 'root');
define('DB_PASS', '');           // Ubah sesuai password Anda
define('DB_NAME', 'projek_kos');
```

### 3. Setup Web Server

**Opsi A: Menggunakan XAMPP/WAMP**

- Letakkan folder `backend` di `htdocs` atau `www`
- Access via: `http://localhost/backend`

**Opsi B: Menggunakan Built-in PHP Server (untuk development)**

```bash
cd backend
php -S localhost:8000
```

- Access via: `http://localhost:8000`

### 4. Konfigurasi URL di Flutter

Update `lib/services/api_service.dart` sesuai base URL:

```dart
static const String _baseUrl = 'http://localhost/backend';  // Untuk XAMPP
// atau
static const String _baseUrl = 'http://localhost:8000';     // Untuk PHP Server
```

## API Endpoints

### Login

**POST** `/api/login`

Request:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

Response (Success - 200):
```json
{
  "status": "success",
  "message": "Login berhasil",
  "data": {
    "id": 1,
    "email": "user@example.com",
    "displayName": "John Doe",
    "role": "user"
  }
}
```

Response (Error - 401):
```json
{
  "status": "error",
  "message": "Email atau password tidak cocok"
}
```

### Register

**POST** `/api/register`

Request:
```json
{
  "email": "newuser@example.com",
  "password": "password123",
  "displayName": "Jane Doe",
  "role": "user"
}
```

Response (Success - 201):
```json
{
  "status": "success",
  "message": "Akun berhasil dibuat",
  "data": {
    "id": 2,
    "email": "newuser@example.com",
    "displayName": "Jane Doe",
    "role": "user"
  }
}
```

Response (Error - 409):
```json
{
  "status": "error",
  "message": "Email sudah terdaftar"
}
```

## Dummy Data

Tersedia akun dummy untuk testing:

| Email | Password | Role |
|-------|----------|------|
| admin@example.com | password123 | admin |
| merchant@example.com | password123 | merchant |
| user@example.com | password123 | user |
| owner@example.com | password123 | owner |

## Troubleshooting

### Database Connection Error
- Cek kredensial database di `config/db.php`
- Pastikan MySQL service berjalan
- Cek permissions database user

### 404 Endpoints Not Found
- Pastikan `.htaccess` file ada di root backend folder
- Pastikan Apache mod_rewrite enabled: `a2enmod rewrite`
- Restart Apache: `sudo systemctl restart apache2`

### CORS Errors
- Headers CORS sudah dikonfigurasi di `.htaccess` dan `index.php`
- Pastikan `Access-Control-Allow-Origin: *` di response

### POST Data Tidak Terterima
- Pastikan request headers `Content-Type: application/json`
- Cek request body format JSON

## Security Notes

⚠️ **Important - Jangan gunakan di Production tanpa security hardening:**

- Update database credentials
- Implement JWT tokens untuk session management
- Validate dan sanitize semua input
- Gunakan HTTPS
- Implement rate limiting
- Add CSRF protection
- Proper error handling tanpa expose technical details

