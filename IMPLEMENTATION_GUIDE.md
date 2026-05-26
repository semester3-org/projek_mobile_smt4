# Comprehensive Implementation Guide: KosFinder Mobile App Bug Fixes & Features

**Document Version:** 1.0  
**Last Updated:** May 27, 2026  
**Scope:** 28 Major Bug Fixes & Feature Implementations

---

## COMPLETED TASKS ✅

### 1. Color Theme Update (Green → Blue & White) - ✅ COMPLETED
**File:** `lib/app/app_theme.dart`
- Changed primary color from `#2E7D32` (Green) to `#0B63B6` (Blue)
- Changed light accent from `#4CAF50` to `#1B7FD8`
- Changed surface tint from `#F1F8F4` to `#F5F7FB`
- Both `merchant_ui.dart` and `user_theme.dart` already use blue colors

**Status:** Ready for Testing
**Test Cases:**
- [ ] Verify all UI elements display in blue theme
- [ ] Check consistency across all screens
- [ ] Verify card shadows and borders look natural with new color

---

### 2. Real-time Order Status Service - ✅ COMPLETED
**File:** `lib/core/realtime_service.dart`
- Created `RealtimeService` singleton with polling capabilities
- Implements automatic polling for user orders and merchant dashboards
- Supports custom polling intervals (default: 5s for orders, 8s for dashboard)
- Event listeners for order_status_updated, dashboard_updated, etc.

**Integration Points:**
- Import in order detail pages for real-time updates
- Add to merchant dashboard pages for live order count
- Connect to user home for real-time subscription status

**Status:** Ready for Integration
**Next Step:** See Task #8 (Real-time Dashboard Updates)

---

### 3. Payment Method Formatting Helper - ✅ CREATED
**File:** `lib/core/payment_methods.dart`
- Converts raw payment method strings to display names
- Maps payment methods to categories (Bank, E-Wallet, QRIS, Cards, COD)
- Helper functions: `getDisplayName()`, `getCategory()`, `isCashOnDelivery()`

**Integration Status:**
- ✅ Integrated in `lib/screens/user/order_detail_page.dart`
- ✅ Integrated in `lib/screens/merchant/pages/shared/merchant_order_detail_page.dart`
- ✅ Integrated in `lib/screens/owner/pages/owner_finance_page.dart`

**Remaining Integration Points:**
- [ ] Billing detail page
- [ ] Order history page
- [ ] Backend merchant_orders API response formatting

**Status:** Ready for Additional Integration

---

### 4. Merchant Dashboard Bug Fix - ✅ COMPLETED
**Issue:** Missing back button and bottom navbar when clicking "Lihat Semua" (View All Orders)

**Solution:**
- Updated `MerchantOrdersView` to accept `showBack` parameter
- Modified `laundry_dashboard_page.dart` to pass `showBack: true`
- Modified `catering_dashboard_page.dart` to pass `showBack: true`
- Set back button visibility in top bar based on parameter

**Files Modified:**
- `lib/screens/merchant/pages/shared/merchant_orders_view.dart`
- `lib/screens/merchant/pages/laundry/laundry_dashboard_page.dart`
- `lib/screens/merchant/pages/catering/catering_dashboard_page.dart`

**Status:** Complete - Ready for Testing

---

## PRIORITY TASKS (In Order of Implementation)

### PRIORITY 1: Real-time Updates Integration (Task #2, #8, #14)

#### Task #8: Real-time Pesanan Terbaru Dashboard
**Status:** NOT STARTED
**Files to Modify:**
- `lib/screens/merchant/pages/shared/merchant_dashboard_view.dart`
- `lib/screens/user/user_home_page.dart`

**Implementation:**
```dart
// In _MerchantDashboardViewState.initState()
@override
void initState() {
  super.initState();
  _load();
  
  // Start real-time polling
  RealtimeService().startMerchantDashboardPolling();
  RealtimeService().addEventListener('dashboard_updated', _load);
}

@override
void dispose() {
  RealtimeService().removeEventListener('dashboard_updated', _load);
  RealtimeService().stopMerchantDashboardPolling();
  super.dispose();
}
```

**Estimated Time:** 1-2 hours

---

#### Task #14: Global Real-time Updates
**Status:** NOT STARTED
**Scope:** Apply RealtimeService to all screens that show dynamic data

**Screens to Update:**
- [ ] User home page (catering/laundry recommendations)
- [ ] Merchant dashboard (order counts)
- [ ] User order detail (subscription status)
- [ ] Merchant order detail (payment status)
- [ ] Profile pages (billing status)

**Estimated Time:** 4-6 hours

---

### PRIORITY 2: Operating Hours System (Task #3)

#### Task #3: Sistem Jam Operasional Real-time
**Status:** NOT STARTED
**Database:** Use new `merchant_operating_hours` table

**Implementation Steps:**

1. **Backend API Endpoint** (`backend/api/merchant_operating_hours.php`):
```php
// GET - Retrieve operating hours
// POST - Update operating hours (for merchant profile)
// Check if merchant is currently open based on current time
```

2. **Flutter Integration** (`lib/core/operating_hours_service.dart`):
```dart
class OperatingHoursService {
  static bool isMerchantOpen(MerchantInfo merchant) {
    // Check current time against operating hours
    // Return true if open, false if closed
  }
  
  static String getOperatingStatus(MerchantInfo merchant) {
    // Return "TUTUP", "BUKA", or next opening time
  }
}
```

3. **UI Changes**:
- Add "TUTUP" label on merchant cards when closed
- Disable order button when merchant is closed
- Show estimated opening time when closed
- On user merchant detail page: disable all product interactions

**Files to Create:**
- `backend/api/merchant_operating_hours.php`
- `lib/core/operating_hours_service.dart`

**Estimated Time:** 6-8 hours

---

### PRIORITY 3: Edit Profile Redirect Fix (Task #4)

#### Task #4: Fix Edit Profil - Redirect ke Top Page
**Status:** NOT STARTED

**Current Behavior:** Edit profile page stays on same position after save
**Desired Behavior:** Redirect to top of profile page

**Implementation:**
```dart
// In profile edit page after successful save:
Navigator.pop(context);
Navigator.pushNamedAndRemoveUntil(context, '/profile', (route) => true);

// OR simpler:
Navigator.pop(context);
await Future.delayed(Duration(milliseconds: 300));
if (mounted) {
  // Scroll to top if using ScrollController
  _scrollController.animateTo(0, duration: Duration(milliseconds: 300), curve: Curves.easeOut);
}
```

**Files to Modify:**
- `lib/screens/user/profile_edit_page.dart` (if exists)
- `lib/screens/merchant/pages/shared/merchant_profile_page.dart`

**Estimated Time:** 1 hour

---

### PRIORITY 4: UI/UX Improvements

#### Task #5: Remove Icon Tambah Promo (Task #5)
**Status:** NOT STARTED
**Files to Modify:** `lib/screens/merchant/pages/shared/merchant_promo_page.dart`

**Implementation:**
- Find and remove the FAB or top-right icon button for adding promo
- Keep only the main add button in the page content

**Estimated Time:** 30 minutes

---

#### Task #16: Reposisi Form Pemesanan - Alamat & Catatan ke Bawah
**Status:** NOT STARTED
**Files to Modify:** `lib/screens/user/merchant_detail_page.dart` (checkout section)

**Current Order:**
1. Product selection
2. Quantity/variants
3. Delivery address
4. Notes
5. Payment method
6. Order button

**New Order:**
1. Product selection
2. Quantity/variants
3. Payment method
4. Delivery address (moved down)
5. Notes (moved down)
6. Order button

**Implementation:** Reorder widgets in `_buildCheckoutForm()` method

**Estimated Time:** 1 hour

---

#### Task #17: Catatan Form - Hanya untuk Laundry
**Status:** NOT STARTED
**Files to Modify:** `lib/screens/user/merchant_detail_page.dart`

**Implementation:**
```dart
if (_isLaundry)
  _CheckoutField(
    controller: _notesCtrl,
    label: 'Catatan tambahan untuk laundry',
    icon: Icons.notes_outlined,
    maxLines: 3,
  ),
// Hide notes for catering
```

**Estimated Time:** 30 minutes

---

#### Task #19: Remove Rating/Ulasan di Form Detail Pesanan
**Status:** NOT STARTED
**Files to Modify:** `lib/screens/user/order_detail_page.dart` or checkout flow

**Implementation:** Find and remove any rating/review widget from order form

**Estimated Time:** 30 minutes

---

### PRIORITY 5: Catering-specific Features

#### Task #6: Kategori Paket Catering
**Status:** NOT STARTED
**Database:** Use new `catering_package_categories` table

**Implementation Steps:**

1. **Backend API** (`backend/api/catering_package_categories.php`):
```php
// GET - List all categories for merchant
// POST - Create new category
// PUT - Update category
// DELETE - Delete category
```

2. **Flutter UI** (`lib/screens/merchant/pages/catering/catering_package_manager_page.dart`):
- List of categories
- Add/Edit/Delete category dialog
- Reference categories when creating products

3. **Integration with Products:**
- Add `catering_package_category_id` to products table
- When creating catering product, select from saved categories
- Display category info in product card

**Estimated Time:** 8 hours

---

#### Task #12: Catering Subscription - No Milestone
**Status:** NOT STARTED

**Current:** Catering uses milestone system (pending → active → expired)
**New:** Simple card showing subscription is active

**Implementation:**
- Remove milestone status from catering orders
- Create simple subscription card showing:
  - Service/Product name
  - Merchant name
  - Start date - End date
  - Status (Active/Expired)
  - Cancel button (if within window)

**Files to Create/Modify:**
- `lib/screens/user/catering_subscription_card.dart` (new)
- `lib/screens/user/order_detail_page.dart` (update)

**Estimated Time:** 4 hours

---

#### Task #13: Pembatalan Catering Subscription
**Status:** NOT STARTED

**Current:** Cancel immediately
**New:** Cancel with delayed effect (remains active until end of billing cycle)

**Implementation:**
```
User clicks "Batalkan Paket"
  → Request cancellation (set subscription_status = 'cancelled_requested')
  → Show message: "Paket akan dihentikan setelah periode ini berakhir"
  → On next billing cycle: Auto set to inactive

Backend Cron/Job:
  → Every day, check if end_date has passed
  → If subscription_status = 'cancelled_requested' AND end_date < today
  → Set subscription_status = 'expired'
```

**Database Update:**
```sql
ALTER TABLE orders
ADD COLUMN cancellation_requested_at DATETIME;
```

**Estimated Time:** 3 hours

---

#### Task #21: Update Form Deskripsi - Detail Catering & Laundry
**Status:** NOT STARTED

**For Catering:**
- Title: "Menu & Jadwal Catering"
- Content should show:
  - [ ] Nama lauk pauk
  - [ ] Jadwal antar per hari
  - [ ] Jadwal dalam satu bulan

**For Laundry:**
- Title: "Estimasi Waktu Layanan"
- Content should show:
  - [ ] Service type
  - [ ] Estimated time (1-2 jam, 1-2 hari, etc.)

**Files to Modify:**
- `lib/screens/user/merchant_detail_page.dart` (description section)

**Estimated Time:** 2 hours

---

### PRIORITY 6: Distance & Time Estimation (Task #11)

#### Task #11: Real-time Distance & Time Estimation
**Status:** NOT STARTED

**Implementation:**
1. When user selects address (provides latitude/longitude)
2. App calculates distance to merchant location
3. Show estimated delivery time based on distance

**Flutter Integration:**
```dart
// Using Geolocator package (already in pubspec.yaml)
// Calculate distance using Haversine formula or Google Maps API

double distanceInMeters = Geolocator.distanceBetween(
  userLat, userLon,
  merchantLat, merchantLon
);

// Convert to minutes based on merchant type
// Laundry: ~1km = 5-10 mins
// Catering: ~1km = 3-5 mins
```

**Files to Create:**
- `lib/core/distance_service.dart`

**Estimated Time:** 3 hours

---

### PRIORITY 7: Cancellation Window (Task #18)

#### Task #18: Pembatalan Pesanan - Window 5 Detik
**Status:** NOT STARTED

**Implementation:**
```dart
// After order created, start countdown
void _startCancellationWindow() {
  final createdAt = order.createdAt;
  final deadline = createdAt.add(Duration(seconds: 5));
  
  Timer.periodic(Duration(milliseconds: 100), (timer) {
    final remaining = deadline.difference(DateTime.now()).inMilliseconds;
    
    if (remaining <= 0) {
      setState(() => _canCancel = false);
      timer.cancel();
      return;
    }
    
    setState(() => _cancelCountdown = '${(remaining / 1000).toStringAsFixed(1)}s');
  });
}

// Show cancel button only if _canCancel is true
if (_canCancel)
  ElevatedButton.icon(
    onPressed: _cancelOrder,
    icon: Icon(Icons.close),
    label: Text('Batalkan (${_cancelCountdown})'),
  )
```

**Files to Modify:**
- `lib/screens/user/order_detail_page.dart`

**Estimated Time:** 2 hours

---

### PRIORITY 8: Admin Features (Tasks #10, #22, #24, #25, #26, #27, #28)

#### Task #10: Detail Catering Subscription - Siapa Subscribe
**Status:** NOT STARTED
**Files to Create:** `lib/screens/merchant/pages/catering/catering_subscribers_page.dart`

**Features:**
- List all active subscribers for merchant's catering packages
- Show: User name, Package type, Start date, End date, Status
- Filter by status (active/expired)
- Sort by start date

**Estimated Time:** 4 hours

---

#### Task #22: Remove Ulasan di Card Detail Merchant
**Status:** NOT STARTED
**Files to Modify:** `lib/screens/user/merchant_detail_page.dart`

**Implementation:** Find and remove reviews/ratings section from merchant detail card

**Estimated Time:** 1 hour

---

#### Task #24: Database Schema Sesuaikan
**Status:** NOT STARTED
**File:** `database/2026-05-27-payment-methods-catering-improvements.sql`

**Already Created:**
- catering_package_categories table
- catering_subscribers table
- merchant_operating_hours table
- laundry_service_estimates table
- transaction_receipts table

**Remaining Checks:**
- [ ] Verify all foreign keys
- [ ] Create indexes for performance
- [ ] Run migration on test database

**Estimated Time:** 2 hours

---

#### Task #25: Fix Midtrans Payment - Direct Return
**Status:** NOT STARTED

**Issue:** After Midtrans payment, app doesn't return directly / shows "expansion domain" error

**Solution:**
- Update Midtrans callback handling
- Remove deep linking issues
- Direct return to app after payment completion

**Files to Check/Modify:**
- `backend/api/midtrans.php`
- `backend/api/midtrans_notification.php`
- `lib/screens/user/order_detail_page.dart` (payment handling)

**Estimated Time:** 3 hours

---

#### Task #26: Download Bukti/Struk PDF
**Status:** NOT STARTED

**Implementation:**
1. Generate PDF receipt for each transaction
2. Add download button on order/billing detail page
3. Store receipt URL in transaction_receipts table

**Libraries Needed:**
- `pdf` package
- `path_provider` package (for file storage)
- `share_plus` package (for sharing receipt)

**Estimated Time:** 6 hours

---

#### Task #27: Fix Bug Lihat Semua Rekomendasi
**Status:** NOT STARTED

**Issue:** "Lihat Semua" button on recommendations navigates to catering page instead of recommendations page

**Solution:**
- Find where "Lihat Semua" button is defined
- Create dedicated recommendations page
- Ensure navigation is correct

**Files to Find/Modify:**
- `lib/screens/user/user_home_page.dart` (line 154)
- Create `lib/screens/user/recommendations_page.dart`

**Estimated Time:** 2 hours

---

#### Task #28: Filter Rekomendasi - Frequency & Rating
**Status:** NOT STARTED

**Implementation:**
- Get list of all merchants user has ordered from
- Filter by highest rating and frequency of use
- Show top 3-5 merchants as recommendations

**Backend Logic:**
```sql
SELECT m.*, COUNT(o.id) as order_count, AVG(r.rating) as avg_rating
FROM merchants m
LEFT JOIN orders o ON m.id = o.merchant_id AND o.user_id = ?
LEFT JOIN ratings r ON m.id = r.merchant_id
WHERE m.is_active = 1
GROUP BY m.id
ORDER BY avg_rating DESC, order_count DESC
LIMIT 5
```

**Estimated Time:** 4 hours

---

#### Task #7: Remove Satuan dari Catering
**Status:** NOT STARTED

**Implementation:**
- Check product form/table
- Remove "satuan" (unit) field display for catering products
- Keep satuan only for laundry products

**Estimated Time:** 1 hour

---

#### Task #9: Clean Up & Group Payment Methods
**Status:** PARTIALLY COMPLETE (Frontend formatting done)

**Remaining:** Backend API response formatting

**Implementation:**
- Update `merchant_orders.php` to return formatted payment method names
- Update `user_orders.php` to return formatted payment method names
- Ensure payment method categories are clear

**Estimated Time:** 2 hours

---

#### Task #15: Harga Catering 20/30 Hari - Merchant Input Sendiri
**Status:** NOT STARTED

**Current:** 20-day price auto-calculated from 30-day price
**New:** Merchant sets price for each duration independently

**Implementation:**
- Add fields in catering product form:
  - Price for 20 days
  - Price for 30 days
- Store both prices in products table
- Display both options during checkout

**Database Change:**
```sql
ALTER TABLE products
ADD COLUMN IF NOT EXISTS price_20_days DECIMAL(15,2),
ADD COLUMN IF NOT EXISTS price_30_days DECIMAL(15,2);
```

**Estimated Time:** 3 hours

---

## TESTING & QA CHECKLIST

### Functional Testing
- [ ] Real-time order updates appear without refresh
- [ ] Operating hours restrict orders correctly
- [ ] Payment methods display with proper formatting
- [ ] Catering subscriptions display correctly
- [ ] Distance/time estimation calculates accurately
- [ ] 5-second cancellation window works
- [ ] Profile edits redirect to top
- [ ] Merchant dashboard back button works
- [ ] PDF receipts generate successfully

### Visual Testing
- [ ] Blue theme applied consistently
- [ ] Form fields repositioned correctly
- [ ] Catatan field hidden for catering
- [ ] All colors contrast properly
- [ ] Typography remains legible

### Performance Testing
- [ ] Real-time polling doesn't drain battery
- [ ] Large order lists load quickly
- [ ] Distance calculations complete in <1s
- [ ] PDF generation doesn't freeze UI

---

## DEPLOYMENT NOTES

1. **Database Migrations**
   - Run: `2026-05-27-payment-methods-catering-improvements.sql`
   - Verify all tables created successfully
   - Check existing data is preserved

2. **Backend Updates**
   - Create new API endpoints for operating hours
   - Update existing payment method handling
   - Add subscription management logic

3. **Flutter App**
   - Update pubspec.yaml with new dependencies (pdf, path_provider, share_plus)
   - Test on Android emulator, iOS simulator, and physical devices
   - Verify real-time updates across all screens

4. **Testing Environment**
   - Run full QA cycle in test environment first
   - Verify Midtrans integration works correctly
   - Test database migrations don't break existing data

---

## ESTIMATED TOTAL TIME

- **Already Completed:** ~6 hours
- **Remaining Tasks:** ~60-75 hours
- **Total Project Duration:** ~70-80 hours
- **Recommended Timeline:** 2-3 weeks with daily 4-6 hour development sprints

---

## PRIORITY ROADMAP

**Week 1:**
- Integrate RealtimeService across dashboards
- Implement operating hours system
- Fix edit profile redirect
- Remove promo icon

**Week 2:**
- Implement catering package categories
- Add subscription management (cancel/extend)
- Fix form repositioning
- Implement distance/time estimation

**Week 3:**
- Add PDF receipt generation
- Implement subscriber list page
- Fix remaining bugs (recommendations, catering satuan)
- QA and testing

---

**Document Prepared By:** AI Assistant  
**Review Date:** May 27, 2026  
**Next Review:** After completion of Week 1 tasks
