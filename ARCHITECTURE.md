# KosFinder Architecture & Services Overview

## 🏗️ Project Structure

```
lib/
├── app/
│   └── app_theme.dart (🔵 BLUE THEME - UPDATED)
├── auth/
│   ├── auth_scope.dart
│   └── auth_state.dart
├── core/
│   ├── api_service.dart
│   ├── auth_storage.dart
│   ├── realtime_service.dart (✨ NEW - Real-time Polling)
│   └── payment_methods.dart (✨ NEW - Payment Formatting)
├── data/
│   └── repositories/
│       ├── user_repository.dart
│       ├── merchant_repository.dart
│       └── owner_repository.dart
├── models/
│   ├── order.dart
│   ├── merchant_models.dart
│   ├── billing_record.dart
│   └── ...
├── screens/
│   ├── user/
│   │   ├── user_theme.dart (🔵 BLUE)
│   │   ├── order_detail_page.dart (🔧 PAYMENT FORMATTING)
│   │   ├── merchant_detail_page.dart
│   │   └── ...
│   ├── merchant/
│   │   ├── merchant_ui.dart (🔵 BLUE)
│   │   ├── pages/
│   │   │   ├── shared/
│   │   │   │   ├── merchant_orders_view.dart (🔧 BACK BUTTON FIX)
│   │   │   │   ├── merchant_dashboard_view.dart
│   │   │   │   └── merchant_order_detail_page.dart (🔧 PAYMENT FORMATTING)
│   │   │   ├── laundry/
│   │   │   │   ├── laundry_dashboard_page.dart (🔧 NAVIGATION FIX)
│   │   │   │   └── ...
│   │   │   └── catering/
│   │   │       ├── catering_dashboard_page.dart (🔧 NAVIGATION FIX)
│   │   │       └── ...
│   ├── owner/
│   │   └── pages/
│   │       └── owner_finance_page.dart (🔧 PAYMENT FORMATTING)
│   └── ...
├── main.dart
└── widgets/

backend/
├── api/
│   ├── user_orders.php (Fetch user orders)
│   ├── merchant_orders.php (Fetch merchant orders)
│   ├── merchant_dashboard.php (Fetch dashboard stats)
│   ├── midtrans.php (Payment processing)
│   ├── midtrans_notification.php (Payment callback)
│   └── ... (25+ more endpoints)
├── config/
│   ├── db.php
│   ├── mail.php
│   └── midtrans.php
├── helpers/
│   └── jwt.php
├── utils/
│   ├── mail_service.php
│   └── response.php
└── vendor/

database/
├── projek_kos (fix).sql (Current schema)
├── 2026-05-25-sync-projek-mobile-schema.sql
├── 2026-05-26-order-payment-subscription-address.sql
└── 2026-05-27-payment-methods-catering-improvements.sql (✨ NEW)
```

---

## 🔄 Data Flow Architecture

### User Order Flow
```
User App
  ↓
[OrderDetailPage] → PaymentMethodHelper.getDisplayName()
  ↓
[api/user_orders.php] → Fetch order with payment_method field
  ↓
[Database: orders table]
  ↓
Display with formatted payment method
```

### Real-time Updates Flow
```
[RealtimeService]
  ↓ (periodic polling every 5-8 seconds)
  ↓
[api/user_orders.php] or [api/merchant_dashboard.php]
  ↓ (notifies listeners)
  ↓
[Dashboard/DetailPage] → setState() → Refresh UI
```

### Merchant Operating Hours Flow
```
[Merchant List Page]
  ↓
[OperatingHoursService.isMerchantOpen(merchant)]
  ↓
Check [merchant_operating_hours table] vs current time
  ↓
Show "TUTUP" badge or disable order button
```

---

## 📦 Service Layer

### 1. RealtimeService (NEW)
**Location:** `lib/core/realtime_service.dart`

**Purpose:** Real-time updates without user refresh

**Methods:**
```dart
// Start polling
RealtimeService().startUserOrderPolling(interval: Duration(seconds: 5));
RealtimeService().startMerchantDashboardPolling(interval: Duration(seconds: 8));

// Listen for updates
RealtimeService().addEventListener('order_status_updated', callback);
RealtimeService().addEventListener('dashboard_updated', callback);

// Stop polling
RealtimeService().stopUserOrderPolling();
RealtimeService().stopMerchantDashboardPolling();

// Cleanup
RealtimeService().dispose();
```

**Usage in Screens:**
```dart
@override
void initState() {
  super.initState();
  RealtimeService().startUserOrderPolling();
  RealtimeService().addEventListener('order_status_updated', _refreshOrders);
}

@override
void dispose() {
  RealtimeService().removeEventListener('order_status_updated', _refreshOrders);
  RealtimeService().stopUserOrderPolling();
  super.dispose();
}
```

---

### 2. PaymentMethodHelper (NEW)
**Location:** `lib/core/payment_methods.dart`

**Purpose:** Format and categorize payment methods

**Methods:**
```dart
// Get display name
PaymentMethodHelper.getDisplayName('gopay') → "GoPay"
PaymentMethodHelper.getDisplayName('bank_transfer') → "Bank Transfer"
PaymentMethodHelper.getDisplayName('cod') → "Bayar di Tempat (COD)"

// Get category
PaymentMethodHelper.getCategory('gopay') → "E-Wallet"
PaymentMethodHelper.getCategory('bca') → "Bank"

// Check if COD
PaymentMethodHelper.isCashOnDelivery('cod') → true

// Get grouped methods
PaymentMethodHelper.getGroupedMethods() → {
  'Bank': ['Bank BCA', 'Bank Mandiri', ...],
  'E-Wallet': ['GoPay', 'OVO', ...],
  ...
}
```

---

### 3. OperatingHoursService (TO BE CREATED)
**Location:** `lib/core/operating_hours_service.dart` (Not yet created)

**Purpose:** Check merchant operating hours

**Methods (Planned):**
```dart
OperatingHoursService.isMerchantOpen(merchant) → bool
OperatingHoursService.getOperatingStatus(merchant) → "BUKA" | "TUTUP"
OperatingHoursService.getNextOpeningTime(merchant) → DateTime
```

---

### 4. DistanceService (TO BE CREATED)
**Location:** `lib/core/distance_service.dart` (Not yet created)

**Purpose:** Calculate distance and estimate delivery time

**Methods (Planned):**
```dart
DistanceService.calculateDistance(lat1, lon1, lat2, lon2) → double (meters)
DistanceService.estimateDeliveryTime(distance, merchantType) → Duration
```

---

## 🔐 Authentication Flow

```
User Login
  ↓
[api/login.php]
  ↓ JWT Token generated
  ↓
[AuthStorage.setToken()] → Store in SharedPreferences
  ↓
[AuthScope] → Provides session to app
  ↓
[ApiService] → Auto-inject token in Authorization header
```

---

## 📡 API Endpoints Structure

### User Endpoints
```
GET  /api/user_orders              → List user orders (with filters)
GET  /api/user_orders?id={id}      → Get specific order
POST /api/user_orders              → Create order
PUT  /api/user_orders/{id}         → Update order
GET  /api/user_merchants           → List merchants
GET  /api/user_merchants/{id}      → Merchant detail
POST /api/user_ratings             → Submit rating
GET  /api/user_profile             → Get profile
```

### Merchant Endpoints
```
GET  /api/merchant_orders          → List orders (filtered)
GET  /api/merchant_orders?id={id}  → Order detail
PUT  /api/merchant_orders/{id}     → Update order status
GET  /api/merchant_dashboard       → Dashboard stats
GET  /api/merchant_products        → List products
POST /api/merchant_products        → Create product
PUT  /api/merchant_products/{id}   → Update product
GET  /api/merchant_profile         → Get profile
PUT  /api/merchant_profile         → Update profile
```

### Payment Endpoints
```
POST /api/midtrans                 → Create payment (Midtrans token)
POST /api/midtrans_notification    → Receive payment callback
GET  /api/midtrans?action=sync     → Sync payment status
```

---

## 📱 State Management Pattern

**Current Approach:** StatefulWidget + setState()

**Flow:**
```
State.initState()
  ↓
Load data via Repository.fetch()
  ↓
setState() → Rebuild UI with data
  ↓
User interaction
  ↓
Call Repository.update()
  ↓
setState() → Refresh UI
  ↓
State.dispose() → Cleanup
```

---

## 🎨 Theme System

### App Theme Colors (UPDATED TO BLUE)
```dart
// Global theme (app_theme.dart)
primaryColor: #0B63B6 (Dark Blue)
primaryLight: #1B7FD8 (Medium Blue)
surface: #FFFFFF (White)
background: #F5F7FB (Light Blue-Gray)

// User theme (user_theme.dart)
primary: #0B63B6
primaryDark: #00508F
accent: #1D4ED8
background: #F5F7FB

// Merchant theme (merchant_ui.dart)
primary: #00508F
primaryLight: #0B63B6
background: #F6F8FC
```

---

## 🗄️ Database Schema Highlights

### Core Tables
- `users` - User accounts
- `merchants` - Merchant/business accounts
- `products` - Layanan/Produk (laundry services, catering packages)
- `orders` - Pesanan (laundry orders, catering orders, kos registration)
- `payment_history` - Payment records for kos billing
- `payment_methods` - Available payment options

### New Tables (Task #24)
- `catering_package_categories` - Package type templates
- `catering_subscribers` - Subscription tracking
- `merchant_operating_hours` - Store operating hours
- `laundry_service_estimates` - Service time estimates
- `transaction_receipts` - Receipt storage

---

## 🚀 Deployment Checklist

- [ ] Database migrations applied
- [ ] Theme colors verified across all screens
- [ ] Payment methods formatting tested
- [ ] Real-time service integrated in key screens
- [ ] Back button navigation verified
- [ ] Operating hours system implemented
- [ ] Distance calculation working
- [ ] PDF receipts generating
- [ ] All endpoints returning correct data format
- [ ] App performance tested (battery drain, memory leaks)
- [ ] QA testing completed
- [ ] Release build tested on multiple devices

---

## 📚 Key Files to Know

| File | Purpose | Last Modified |
|------|---------|----------------|
| `lib/app/app_theme.dart` | Global app theme | ✅ Updated to blue |
| `lib/core/api_service.dart` | API communication | Base service |
| `lib/core/realtime_service.dart` | Real-time updates | ✨ New |
| `lib/core/payment_methods.dart` | Payment formatting | ✨ New |
| `backend/api/midtrans.php` | Midtrans integration | Core payment logic |
| `database/*.sql` | Schema definitions | Multiple versions |

---

**Version:** 1.0  
**Last Updated:** May 27, 2026  
**Next Update:** After implementation of Phase 2
