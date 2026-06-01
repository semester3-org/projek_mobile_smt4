import 'dart:async';

import '../../core/api_service.dart';

class OwnerRepository {
  OwnerRepository._();

  static const Duration _notificationCountCacheTtl = Duration(seconds: 2);
  static int? _unreadNotificationCountCache;
  static DateTime? _unreadNotificationCountCachedAt;
  static final StreamController<void> _notificationCountController =
      StreamController<void>.broadcast();

  static Stream<void> get notificationCountChanges =>
      _notificationCountController.stream;

  static void _notifyNotificationCountChanged() {
    if (!_notificationCountController.isClosed) {
      _notificationCountController.add(null);
    }
  }

  static void invalidateNotificationCountCache() {
    _unreadNotificationCountCache = null;
    _unreadNotificationCountCachedAt = null;
    _notifyNotificationCountChanged();
  }

  static void setUnreadNotificationCount(int count) {
    _unreadNotificationCountCache = count < 0 ? 0 : count;
    _unreadNotificationCountCachedAt = DateTime.now();
    _notifyNotificationCountChanged();
  }

  static Future<int> unreadNotificationCount() async {
    final cachedAt = _unreadNotificationCountCachedAt;
    final cached = _unreadNotificationCountCache;
    if (cachedAt != null &&
        cached != null &&
        DateTime.now().difference(cachedAt) < _notificationCountCacheTtl) {
      return cached;
    }

    final result = await ApiService.get(
      'api/owner_notifications',
      queryParams: const {'count': '1'},
    );
    final payload = result.data?['data'];
    final count = result.success && payload is Map<String, dynamic>
        ? (payload['count'] as num?)?.toInt() ?? 0
        : 0;

    _unreadNotificationCountCache = count;
    _unreadNotificationCountCachedAt = DateTime.now();
    return count;
  }
}
