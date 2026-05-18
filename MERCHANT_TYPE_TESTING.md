# Merchant Type Feature - Quick Start Guide

## How to Test the Feature

### 1. Register as Laundry Merchant

**Frontend Steps**:
1. Navigate to Register page
2. Fill in:
   - Nama: "Laundry Jaya"
   - Email: "laundry@test.com"
   - Password: "password123"
3. Select Role: **Merchant**
4. Select Tipe Layanan: **Laundry**
5. Click "Daftar"

**Expected Result**:
- Success message
- Backend creates user + merchants record with merchant_type='laundry'

### 2. Register as Catering Merchant

**Frontend Steps**:
1. Navigate to Register page
2. Fill in:
   - Nama: "Catering Harian"
   - Email: "catering@test.com"
   - Password: "password123"
3. Select Role: **Merchant**
4. Select Tipe Layanan: **Catering**
5. Click "Daftar"

**Expected Result**:
- Success message
- Backend creates user + merchants record with merchant_type='catering'

### 3. Login as Merchant

**Frontend Steps**:
1. Login with laundry merchant credentials
2. Should see Laundry Dashboard with:
   - "Selamat datang, Laundry Master! 👋"
   - Laundry-specific stats
   - Bottom nav shows "Laundry, Pesanan, Layanan, Promo, Notifikasi, Profil"

**Or login with catering merchant**:
1. Login with catering merchant credentials
2. Should see Catering Dashboard with:
   - "Selamat datang, Chef Catering! 👋"
   - Catering-specific stats
   - Bottom nav shows "Catering, Pesanan, Menu, Promo, Notifikasi, Profil"

### 4. Test Backend API Directly

**Register Laundry Merchant**:
```bash
curl -X POST http://your-api/api/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "laundry123@test.com",
    "password": "password123",
    "displayName": "Laundry Test",
    "role": "merchant",
    "merchantType": "laundry"
  }'
```

**Expected Response**:
```json
{
  "success": true,
  "message": "Akun berhasil dibuat",
  "data": {
    "id": "uuid-here",
    "email": "laundry123@test.com",
    "displayName": "Laundry Test",
    "role": "merchant",
    "merchantType": "laundry"
  }
}
```

**Login**:
```bash
curl -X POST http://your-api/api/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "laundry123@test.com",
    "password": "password123"
  }'
```

**Expected Response**:
```json
{
  "success": true,
  "message": "Login berhasil",
  "data": {
    "token": "jwt-token-here",
    "id": "uuid-here",
    "email": "laundry123@test.com",
    "displayName": "Laundry Test",
    "role": "merchant",
    "merchantType": "laundry"
  }
}
```

---

## Database Verification

### Check Registered Merchants

```sql
SELECT u.id, u.email, u.display_name, u.role, m.merchant_type 
FROM users u 
LEFT JOIN merchants m ON u.id = m.user_id 
WHERE u.role = 'merchant';
```

**Expected Output**:
```
id                                  | email               | display_name    | role     | merchant_type
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | laundry@test.com    | Laundry Jaya    | merchant | laundry
yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy | catering@test.com   | Catering Harian | merchant | catering
```

---

## UI Navigation Test

### Laundry Merchant Navigation
```
Bottom Tab 1: Laundry (Dashboard) ← Dashboard page
Bottom Tab 2: Pesanan (Orders)
Bottom Tab 3: Layanan (Services)
Bottom Tab 4: Promo
Bottom Tab 5: Notifikasi (Notifications)
Bottom Tab 6: Profil (Profile)
```

### Catering Merchant Navigation
```
Bottom Tab 1: Catering (Dashboard) ← Dashboard page
Bottom Tab 2: Pesanan (Orders)
Bottom Tab 3: Menu
Bottom Tab 4: Promo
Bottom Tab 5: Notifikasi (Notifications)
Bottom Tab 6: Profil (Profile)
```

---

## What Gets Stored

### User Table
```
id: UUID
email: user@test.com
password: bcrypt hash
display_name: User Name
role: 'merchant'
created_at: timestamp
updated_at: timestamp
```

### Merchants Table
```
id: UUID
user_id: UUID (FK -> users.id)
business_name: User Name (auto-filled from display_name)
merchant_type: ENUM('laundry','catering')
phone: null (for future use)
address: null (for future use)
created_at: timestamp
updated_at: timestamp
```

---

## Common Issues & Solutions

### Issue: Merchant type picker not showing
**Solution**: Ensure role is set to 'merchant' or 'owner'. The picker only shows when role changes to these values.

### Issue: Error "Tipe merchant harus dipilih"
**Solution**: Make sure to select either Laundry or Catering from the Tipe Layanan chips.

### Issue: merchantType is null in auth_state
**Solution**: Login response must include merchantType from backend. Check that login.php has been updated.

### Issue: Merchant routes to wrong shell
**Solution**: Clear app cache/reinstall. AuthGate uses session.role to determine routing.

---

## Next Steps (Future Development)

1. **Implement Laundry Services CRUD**
   - Create/Edit/Delete laundry services
   - Set pricing and capacity

2. **Implement Catering Menu CRUD**
   - Create/Edit/Delete menu items
   - Set pricing and serving size

3. **Orders Management**
   - View incoming orders
   - Accept/Reject/Update order status
   - Print invoice

4. **Dashboard Analytics**
   - Revenue charts
   - Order statistics
   - Customer ratings

5. **Settings**
   - Merchant information
   - Operating hours
   - Payment methods

---

## Code Examples for Developers

### Adding Another Merchant Type

**1. Update enum** (`lib/auth/roles.dart`):
```dart
enum MerchantType {
  laundry,
  catering,
  pharmacy,  // New type
}

extension MerchantTypeLabel on MerchantType {
  String get label {
    switch (this) {
      case MerchantType.laundry:
        return 'Laundry';
      case MerchantType.catering:
        return 'Catering';
      case MerchantType.pharmacy:
        return 'Pharmacy';
    }
  }
  // ... rest of implementation
}
```

**2. Create pages**:
```
lib/screens/merchant/pages/pharmacy/
├── pharmacy_dashboard_page.dart
├── pharmacy_orders_page.dart
└── pharmacy_products_page.dart
```

**3. Update merchant_shell.dart**:
```dart
if (merchantType == MerchantType.pharmacy) {
  pages = [
    const PharmacyDashboardPage(),
    const PharmacyOrdersPage(),
    const PharmacyProductsPage(),
    // ... shared pages
  ];
  mainLabel = 'Pharmacy';
  serviceLabel = 'Produk';
}
```

---

## Support

For issues or questions, refer to:
- [Main Implementation Docs](./MERCHANT_TYPE_IMPLEMENTATION.md)
- Backend: `backend/api/register.php` and `backend/api/login.php`
- Frontend: `lib/screens/merchant/merchant_shell.dart`
