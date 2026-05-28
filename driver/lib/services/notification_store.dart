import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_item.dart';

/// Singleton che persiste le notifiche ricevute in SharedPreferences.
/// Espone un [ValueNotifier] per il conteggio non-letti, così
/// la HomeScreen può aggiornare il badge senza polling.
class NotificationStore {
  static final NotificationStore _instance = NotificationStore._internal();
  factory NotificationStore() => _instance;
  NotificationStore._internal();

  static const _prefsKey = 'driver_notifications';
  static const _maxItems = 50; // conserva solo le ultime 50

  final ValueNotifier<int> unreadCount = ValueNotifier(0);

  List<NotificationItem> _items = [];
  bool _loaded = false;

  // ─── Caricamento iniziale ────────────────────────────────────────────────

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _items = NotificationItem.listFromJson(raw);
      } catch (_) {
        _items = [];
      }
    }
    _loaded = true;
    _refreshUnread();
  }

  // ─── Aggiunta ────────────────────────────────────────────────────────────

  Future<void> addNotification(NotificationItem item) async {
    await load();
    // Evita duplicati (stesso id)
    _items.removeWhere((e) => e.id == item.id);
    _items.insert(0, item); // più recente primo
    if (_items.length > _maxItems) {
      _items = _items.sublist(0, _maxItems);
    }
    await _save();
    _refreshUnread();
  }

  // ─── Lettura ─────────────────────────────────────────────────────────────

  Future<List<NotificationItem>> getAll() async {
    await load();
    return List.unmodifiable(_items);
  }

  // ─── Segna come lette ────────────────────────────────────────────────────

  Future<void> markAllAsRead() async {
    await load();
    for (final item in _items) {
      item.isRead = true;
    }
    await _save();
    _refreshUnread();
  }

  Future<void> markAsRead(String id) async {
    await load();
    for (final item in _items) {
      if (item.id == id) item.isRead = true;
    }
    await _save();
    _refreshUnread();
  }

  // ─── Cancella tutto ──────────────────────────────────────────────────────

  Future<void> clear() async {
    _items = [];
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _refreshUnread();
  }

  // ─── Privati ─────────────────────────────────────────────────────────────

  void _refreshUnread() {
    unreadCount.value = _items.where((e) => !e.isRead).length;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, NotificationItem.listToJson(_items));
  }
}
