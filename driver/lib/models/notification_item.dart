import 'dart:convert';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String event;
  final String? orderId;
  final DateTime receivedAt;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.event,
    this.orderId,
    required this.receivedAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'event': event,
    'orderId': orderId,
    'receivedAt': receivedAt.toIso8601String(),
    'isRead': isRead,
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        event: json['event'] as String? ?? '',
        orderId: json['orderId'] as String?,
        receivedAt: DateTime.parse(json['receivedAt'] as String),
        isRead: json['isRead'] as bool? ?? false,
      );

  static List<NotificationItem> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<NotificationItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());
}
