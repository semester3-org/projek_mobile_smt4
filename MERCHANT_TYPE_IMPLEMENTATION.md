# Merchant Type Feature Implementation Summary

## Overview
Successfully implemented merchant type feature for Flutter + PHP project allowing merchants to specify their business type (Laundry or Catering) during registration.

---

## Backend Changes (PHP)

### 1. Database Structure
**Status**: Already existed ✓
- `merchants` table already has `merchant_type` ENUM('catering','cafe','laundry')
- No migration needed

### 2. `backend/api/register.php`
**Changes**:
- Added `merchantType` parameter validation
- Enforces `merchantType` selection for `owner` and `merchant` roles
- Creates `merchants` record automatically when registering owner/merchant with merchant_type
- Returns `merchantType` in response

**Key Logic**:
```php
// Validasi merchant_type untuk role owner/merchant
if (in_array($role, ['owner', 'merchant'])) {
    $allowedMerchantTypes = ['laundry', 'catering'];
    if (empty($merchantType) || !in_array($merchantType, $allowedMerchantTypes)) {
        $errors[] = 'Tipe merchant harus dipilih...';
    }
}

// Insert merchant record
if (in_array($role, ['owner', 'merchant']) && $merchantType) {
    // Create merchants table entry with merchant_type
}
```

### 3. `backend/api/login.php`
**Changes**:
- Updated SQL query to JOIN with `merchants` table
- Retrieves `merchant_type` from merchants table
- Includes `merchantType` in JWT token
- Returns `merchantType` in login response JSON

**Response Example**:
```json
{
  "success": true,
  "data": {
    "token": "...",
    "id": "...",
    "email": "...",
    "displayName": "...",
    "role": "merchant",
    "merchantType": "laundry"
  }
}
```

---

## Frontend Changes (Flutter)

### 1. Auth Models - `lib/auth/roles.dart`
**New Addition**:
- Added `MerchantType` enum with values: `laundry`, `catering`
- Added `MerchantTypeLabel` extension with:
  - `label` getter for UI display
  - `fromString()` static method for parsing from API

### 2. Auth State - `lib/auth/auth_state.dart`
**Changes**:
- Updated `AuthSession` to include optional `merchantType: MerchantType?`
- Updated `loginWithCredentials()` to parse merchantType from API response
- Updated `updateDisplayName()` to preserve merchantType

### 3. API Service - `lib/core/api_service.dart`
**Changes**:
- Added optional `merchantType` parameter to `register()` method
- Conditionally includes merchantType in request body

### 4. Register Page - `lib/screens/auth/register_page.dart`
**Changes**:
- Added merchant type selection UI (Laundry/Catering chips)
- Conditionally displays merchant type picker when role is owner/merchant
- Validates merchant type selection for merchant roles
- Passes merchantType to API call

**UI Flow**:
1. Select role (User/Owner/Merchant)
2. If Owner or Merchant selected → Show "Tipe Layanan" picker
3. User selects Laundry or Catering
4. Submit registration with all data

### 5. New Merchant Shell - `lib/screens/merchant/merchant_shell.dart`
**Features**:
- Reuses shared navigation pattern like OwnerShell
- Dynamically renders pages based on `merchantType`
- Shared bottom navigation with dynamic labels
- Clean separation of concerns

**Page Structure**:
```
Merchant Shell
├── Laundry Branch
│   ├── Laundry Dashboard
│   ├── Laundry Orders
│   └── Laundry Services
└── Catering Branch
    ├── Catering Dashboard
    ├── Catering Orders
    └── Catering Menu
├── Shared Pages (both types)
│   ├── Promo
│   ├── Notifications
│   └── Profile
```

### 6. Merchant Pages

#### Laundry Specific Pages
- `pages/laundry/laundry_dashboard_page.dart` - Dashboard with laundry stats
- `pages/laundry/laundry_orders_page.dart` - Laundry order management
- `pages/laundry/laundry_services_page.dart` - Service/pricing management

#### Catering Specific Pages
- `pages/catering/catering_dashboard_page.dart` - Dashboard with catering stats
- `pages/catering/catering_orders_page.dart` - Catering order management
- `pages/catering/catering_menu_page.dart` - Menu management

#### Shared Pages (Merchant-specific)
- `pages/shared/merchant_profile_page.dart` - Profile management
- `pages/shared/merchant_notifications_page.dart` - Notifications
- `pages/shared/merchant_promo_page.dart` - Promotions

### 7. Auth Gate Update - `lib/screens/auth/auth_gate.dart`
**Changes**:
- Merchant role now routes to `MerchantShell` instead of pending page
- Clean switch statement routing

---

## Data Flow

### Registration Flow
```
User fills registration form
  ↓
Select role (Owner/Merchant)
  ↓
If merchant → Select merchant type (Laundry/Catering)
  ↓
Call register API with:
  - email
  - password
  - displayName
  - role
  - merchantType (if owner/merchant)
  ↓
Backend creates user + merchant record
  ↓
Show success message
  ↓
User logs in
```

### Login Flow
```
User enters credentials
  ↓
Backend query users + merchants JOIN
  ↓
Retrieve role + merchantType
  ↓
Generate JWT with merchantType
  ↓
Return to app with merchantType
  ↓
AuthSession stores merchantType
  ↓
AuthGate routes to MerchantShell
  ↓
MerchantShell shows appropriate pages based on merchantType
```

---

## Key Design Decisions

### 1. ✓ Minimal Changes
- Reused existing register/login flow
- No new authentication system
- No duplicate navigation structures

### 2. ✓ Shared Infrastructure
- Both laundry and catering use same shell
- Shared profile, promo, notification pages
- Conditional rendering based on merchantType

### 3. ✓ Scalability
- Easy to add more merchant types (just extend enum + create pages)
- Pattern can be replicated for other roles
- Database structure already supports it

### 4. ✓ User Experience
- Clear merchant type selection during registration
- Dynamic UI based on business type
- Consistent styling across all merchant pages

---

## Testing Checklist

### Backend
- [ ] Register with role='merchant' + merchantType='laundry'
- [ ] Register with role='merchant' + merchantType='catering'
- [ ] Verify merchants table is populated correctly
- [ ] Login returns merchantType in response
- [ ] JWT token includes merchantType

### Frontend
- [ ] Register page shows merchant type picker for owner/merchant roles
- [ ] Merchant type selection is required for merchant roles
- [ ] Login stores merchantType in AuthSession
- [ ] Merchant routes to MerchantShell
- [ ] Laundry merchant shows laundry-specific pages
- [ ] Catering merchant shows catering-specific pages
- [ ] Shared pages work for both types

---

## Future Enhancements

1. **API Endpoints**: Create/update merchant services/menu
2. **Orders System**: Implement laundry/catering order management
3. **Analytics**: Merchant-specific dashboard analytics
4. **Settings**: Per-merchant-type configuration
5. **More Types**: Add cafe, office-space, etc.

---

## Files Modified/Created

### Modified Files (5)
1. `backend/api/register.php`
2. `backend/api/login.php`
3. `lib/auth/roles.dart`
4. `lib/auth/auth_state.dart`
5. `lib/core/api_service.dart`
6. `lib/screens/auth/register_page.dart`
7. `lib/screens/auth/auth_gate.dart`

### Created Files (9)
1. `lib/screens/merchant/merchant_shell.dart`
2. `lib/screens/merchant/pages/laundry/laundry_dashboard_page.dart`
3. `lib/screens/merchant/pages/laundry/laundry_orders_page.dart`
4. `lib/screens/merchant/pages/laundry/laundry_services_page.dart`
5. `lib/screens/merchant/pages/catering/catering_dashboard_page.dart`
6. `lib/screens/merchant/pages/catering/catering_orders_page.dart`
7. `lib/screens/merchant/pages/catering/catering_menu_page.dart`
8. `lib/screens/merchant/pages/shared/merchant_profile_page.dart`
9. `lib/screens/merchant/pages/shared/merchant_notifications_page.dart`
10. `lib/screens/merchant/pages/shared/merchant_promo_page.dart`

---

## Implementation Status

✅ **COMPLETE** - All required features implemented with minimal changes
