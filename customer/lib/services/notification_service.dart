import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

class CustomerNotification {
  final int id;
  final String title;
  final String body;
  final String? triggerEvent;
  final String? entityType;
  final int? entityId;
  final bool isRead;
  final DateTime createdAt;

  CustomerNotification({
    required this.id,
    required this.title,
    required this.body,
    this.triggerEvent,
    this.entityType,
    this.entityId,
    required this.isRead,
    required this.createdAt,
  });

  factory CustomerNotification.fromJson(Map<String, dynamic> json) {
    return CustomerNotification(
      id: (json['id'] as num).toInt(),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      triggerEvent: json['trigger_event'],
      entityType: json['entity_type'],
      entityId: json['entity_id'] != null
          ? (json['entity_id'] as num).toInt()
          : null,
      isRead: (json['is_read'] == 1 || json['is_read'] == true),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class NotificationService {
  final String _base = AppConstants.apiUrl;

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyApiToken) ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-API-Token': token,
    };
  }

  /// Restituisce la lista delle notifiche + unread_count
  Future<({List<CustomerNotification> notifications, int unreadCount})>
      fetchNotifications({int limit = 20, int page = 1}) async {
    try {
      final uri = Uri.parse(
          '$_base/customer/notifications?limit=$limit&page=$page');
      final res = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if (json['success'] == true) {
          final data = json['data'] as Map<String, dynamic>;
          final list = (data['notifications'] as List)
              .map((e) => CustomerNotification.fromJson(e))
              .toList();
          return (
            notifications: list,
            unreadCount: (data['unread_count'] as num?)?.toInt() ?? 0,
          );
        }
      }
    } catch (_) {}
    return (notifications: <CustomerNotification>[], unreadCount: 0);
  }

  /// Solo il conteggio non lette
  Future<int> fetchUnreadCount() async {
    try {
      final uri = Uri.parse('$_base/customer/notifications/count');
      final res = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if (json['success'] == true) {
          return (json['data']['unread_count'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (_) {}
    return 0;
  }

  /// Segna una o tutte le notifiche come lette
  Future<int> markRead({int? id}) async {
    try {
      final uri = Uri.parse('$_base/customer/notifications/read');
      final res = await http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode(id != null ? {'id': id} : {}),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if (json['success'] == true) {
          return (json['data']['unread_count'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (_) {}
    return 0;
  }
}
