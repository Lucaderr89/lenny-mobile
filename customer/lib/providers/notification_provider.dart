import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  int _unreadCount = 0;
  List<CustomerNotification> _notifications = [];
  bool _isLoading = false;
  Timer? _pollTimer;

  int get unreadCount => _unreadCount;
  List<CustomerNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;

  /// Avvia il provider: carica il count e inizia il polling ogni 60s.
  /// Per un ospite non parte nulla: non ha notifiche e ogni chiamata
  /// fallirebbe senza token.
  Future<void> start() async {
    if (!await AuthService().isLoggedIn()) return;

    refreshCount();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      refreshCount();
    });
  }

  /// Ferma il polling
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Aggiorna solo il conteggio (leggero, usato dal polling)
  Future<void> refreshCount() async {
    final count = await _service.fetchUnreadCount();
    if (count != _unreadCount) {
      _unreadCount = count;
      notifyListeners();
    }
  }

  /// Carica la lista completa (usata dallo screen notifiche)
  Future<void> loadNotifications({int page = 1}) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    final result = await _service.fetchNotifications(page: page);
    _notifications = result.notifications;
    _unreadCount = result.unreadCount;
    _isLoading = false;
    notifyListeners();
  }

  /// Aggiorna il badge dall'esterno (es. dopo ricezione FCM)
  void incrementUnread() {
    _unreadCount++;
    notifyListeners();
  }

  /// Segna una notifica come letta
  Future<void> markRead(int id) async {
    final newCount = await _service.markRead(id: id);
    _unreadCount = newCount;
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = CustomerNotification(
        id: _notifications[idx].id,
        title: _notifications[idx].title,
        body: _notifications[idx].body,
        triggerEvent: _notifications[idx].triggerEvent,
        entityType: _notifications[idx].entityType,
        entityId: _notifications[idx].entityId,
        isRead: true,
        createdAt: _notifications[idx].createdAt,
      );
    }
    notifyListeners();
  }

  /// Segna tutte come lette
  Future<void> markAllRead() async {
    final newCount = await _service.markRead();
    _unreadCount = newCount;
    _notifications = _notifications
        .map(
          (n) => CustomerNotification(
            id: n.id,
            title: n.title,
            body: n.body,
            triggerEvent: n.triggerEvent,
            entityType: n.entityType,
            entityId: n.entityId,
            isRead: true,
            createdAt: n.createdAt,
          ),
        )
        .toList();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
