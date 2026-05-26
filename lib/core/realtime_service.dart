import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Service untuk real-time updates tanpa refresh manual
class RealtimeService extends ChangeNotifier {
  static final RealtimeService _instance = RealtimeService._internal();

  factory RealtimeService() {
    return _instance;
  }

  RealtimeService._internal();

  // ── Polling State ──────────────────────────────────────────────────────────
  Timer? _orderStatusPolling;
  Timer? _dashboardPolling;
  Timer? _merchantOrdersPolling;
  int _userPollingClients = 0;
  int _dashboardPollingClients = 0;
  int _merchantOrdersPollingClients = 0;

  // Callback untuk notifikasi update
  final Map<String, List<VoidCallback>> _listeners = {
    'order_status_updated': [],
    'dashboard_updated': [],
    'merchant_order_updated': [],
    'subscription_updated': [],
  };

  /// Register listener untuk event tertentu
  void addEventListener(String event, VoidCallback callback) {
    if (!_listeners.containsKey(event)) {
      _listeners[event] = [];
    }
    _listeners[event]!.add(callback);
  }

  /// Remove listener
  void removeEventListener(String event, VoidCallback callback) {
    _listeners[event]?.remove(callback);
  }

  /// Notify semua listeners untuk event tertentu
  void _notifyListeners(String event) {
    _listeners[event]?.forEach((callback) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error in $event listener: $e');
      }
    });
    notifyListeners();
  }

  /// Start polling untuk user order status
  void startUserOrderPolling({
    Duration interval = const Duration(seconds: 5),
  }) {
    _userPollingClients++;
    if (_orderStatusPolling != null) return;

    _orderStatusPolling = Timer.periodic(interval, (timer) async {
      try {
        await _pollUserOrders();
      } catch (e) {
        debugPrint('Error polling user orders: $e');
      }
    });
  }

  /// Stop polling untuk user orders
  void stopUserOrderPolling() {
    if (_userPollingClients > 0) _userPollingClients--;
    if (_userPollingClients > 0) return;
    _orderStatusPolling?.cancel();
    _orderStatusPolling = null;
  }

  /// Poll user orders status
  Future<void> _pollUserOrders() async {
    try {
      final res = await ApiService.get('api/user_orders');
      if (res.success && res.data != null) {
        _notifyListeners('order_status_updated');
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  /// Start polling untuk merchant dashboard
  void startMerchantDashboardPolling({
    Duration interval = const Duration(seconds: 6),
  }) {
    _dashboardPollingClients++;
    if (_dashboardPolling != null) return;

    _dashboardPolling = Timer.periodic(interval, (timer) async {
      try {
        await _pollMerchantDashboard();
      } catch (e) {
        debugPrint('Error polling merchant dashboard: $e');
      }
    });
  }

  /// Stop polling untuk merchant dashboard
  void stopMerchantDashboardPolling() {
    if (_dashboardPollingClients > 0) _dashboardPollingClients--;
    if (_dashboardPollingClients > 0) return;
    _dashboardPolling?.cancel();
    _dashboardPolling = null;
  }

  /// Polling daftar pesanan merchant (tab pesanan & lihat semua).
  void startMerchantOrdersPolling({
    Duration interval = const Duration(seconds: 6),
  }) {
    _merchantOrdersPollingClients++;
    if (_merchantOrdersPolling != null) return;

    _merchantOrdersPolling = Timer.periodic(interval, (timer) async {
      try {
        final res = await ApiService.get('api/merchant_orders');
        if (res.success && res.data != null) {
          _notifyListeners('merchant_order_updated');
        }
      } catch (e) {
        debugPrint('Error polling merchant orders: $e');
      }
    });
  }

  void stopMerchantOrdersPolling() {
    if (_merchantOrdersPollingClients > 0) _merchantOrdersPollingClients--;
    if (_merchantOrdersPollingClients > 0) return;
    _merchantOrdersPolling?.cancel();
    _merchantOrdersPolling = null;
  }

  /// Poll merchant dashboard
  Future<void> _pollMerchantDashboard() async {
    try {
      final res = await ApiService.get('api/merchant_dashboard');
      if (res.success && res.data != null) {
        _notifyListeners('dashboard_updated');
      }
    } catch (e) {
      debugPrint('Dashboard polling error: $e');
    }
  }

  /// Poll specific merchant order
  Future<void> pollMerchantOrder(String orderId) async {
    try {
      final res = await ApiService.get('api/merchant_orders?id=$orderId');
      if (res.success && res.data != null) {
        _notifyListeners('merchant_order_updated');
      }
    } catch (e) {
      debugPrint('Error polling merchant order: $e');
    }
  }

  /// Poll catering subscription status
  Future<void> pollCateringSubscription(String orderId) async {
    try {
      final res = await ApiService.get('api/user_orders?id=$orderId');
      if (res.success && res.data != null) {
        _notifyListeners('subscription_updated');
      }
    } catch (e) {
      debugPrint('Error polling catering subscription: $e');
    }
  }

  /// Cleanup all timers
  @override
  void dispose() {
    _orderStatusPolling?.cancel();
    _dashboardPolling?.cancel();
    _merchantOrdersPolling?.cancel();
    _userPollingClients = 0;
    _dashboardPollingClients = 0;
    _merchantOrdersPollingClients = 0;
    _listeners.clear();
    super.dispose();
  }
}
