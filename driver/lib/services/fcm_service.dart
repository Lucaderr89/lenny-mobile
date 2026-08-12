import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';
import '../models/notification_item.dart';
import 'notification_store.dart';

/// Handler per notifiche ricevute in background (top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 [FCM Background Driver] ${message.notification?.title}');
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  String? _token;

  // Canale Android con suono custom (identico al cliente)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'lenny_orders',
    'Consegne Lenny',
    description: 'Notifiche per nuove consegne e aggiornamenti',
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound('notifica'),
    enableVibration: true,
  );

  // Stream per notificare chi ascolta (es. HomeScreen) di un messaggio in foreground
  final _messageStreamController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onForegroundMessage =>
      _messageStreamController.stream;

  /// Su iOS il token FCM non esiste finche' APNs non ha consegnato il proprio
  /// device token alla SDK Firebase: chiamare getToken() subito dopo aver
  /// ottenuto il permesso fallisce con [firebase_messaging/apns-token-not-set].
  /// Su Android il token e' disponibile subito e l'attesa non serve.
  Future<void> _attendiApnsToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    for (var tentativo = 0; tentativo < 20; tentativo++) {
      if (await _messaging.getAPNSToken() != null) return;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    debugPrint('⚠️ APNs non ha consegnato il token entro 10s');
  }

  /// Il prompt di sistema al bootstrap e' il momento con il massimo tasso di
  /// rifiuto: la richiesta avviene dopo il login, insieme a quella della
  /// posizione e preceduta dal dialog che spiega a cosa servono, tramite
  /// [requestPermissionWithContext]. Qui si procede solo se il permesso
  /// risulta gia' concesso in passato.
  Future<void> initialize() async {
    final settings = await _messaging.getNotificationSettings();
    debugPrint('🔔 FCM Driver permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied ||
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      // Mai chiesto o negato: nessun prompt qui.
      return;
    }

    await _setupMessaging();
  }

  /// Chiede il permesso notifiche nel momento giusto: dopo il login, quando il
  /// driver ha appena accettato il dialog che spiega perche' servono.
  /// Ritorna true se concesso.
  Future<bool> requestPermissionWithContext() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      '🔔 FCM Driver permission (richiesta): ${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }

    await _setupMessaging();
    return true;
  }

  /// Token, handler e canale notifiche: eseguito solo a permesso concesso.
  Future<void> _setupMessaging() async {
    await _attendiApnsToken();

    try {
      _token = await _messaging.getToken();
      debugPrint('📱 FCM Driver Token: $_token');
      await _registerTokenOnBackend();
    } catch (e) {
      // initialize() non e' awaited in main: un throw qui diventerebbe un
      // errore asincrono non gestito, che runZonedGuarded segnalerebbe a
      // Crashlytics come crash fatale a ogni avvio.
      debugPrint('⚠️ FCM Driver token non ottenibile: $e');
    }

    _messaging.onTokenRefresh.listen((t) {
      _token = t;
      _registerTokenOnBackend();
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(initialMessage);

    // Inizializza flutter_local_notifications con canale custom
    // Icona di notifica dedicata: Android ne usa solo il canale alpha, quindi
    // deve essere una silhouette su trasparente. L'icona del launcher e' opaca
    // e verrebbe resa come un quadrato bianco.
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
    await _localNotifications.initialize(initSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // Su Android in foreground FCM non mostra nulla nativamente:
    // disabilitiamo il banner nativo e lo gestiremo noi con local notifications
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
  }

  String? get token => _token;

  Future<void> _registerTokenOnBackend() async {
    if (_token == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(AppConstants.keyApiToken);
      if (authToken == null) {
        debugPrint(
          '⚠️ FCM Driver: auth_token non disponibile, skip registrazione',
        );
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/driver/fcm-token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $authToken',
        },
        body: {'fcm_token': _token!},
      );
      debugPrint(
        response.statusCode == 200
            ? '✅ Driver FCM token registrato'
            : '⚠️ Errore: ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('❌ Errore FCM driver: $e');
    }
  }

  Future<void> onUserLoggedIn() async => _registerTokenOnBackend();

  Future<void> onUserLoggedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(AppConstants.keyApiToken);
      if (authToken == null) return;
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/driver/fcm-token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $authToken',
        },
        body: {'fcm_token': ''},
      );
    } catch (e) {
      debugPrint('❌ Errore rimozione FCM driver: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 [FCM Foreground Driver] ${message.notification?.title}');
    _saveToStore(message);
    // Mostra notifica di sistema con suono custom (come il cliente)
    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            sound: const RawResourceAndroidNotificationSound('notifica'),
            icon: '@drawable/ic_notification',
          ),
        ),
      );
    }
    // Notifica gli ascoltatori (es. HomeScreen) per ricaricare ordini in tempo reale
    _messageStreamController.add(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 [FCM Tap Driver] data: ${message.data}');
    _saveToStore(message);
    _pendingNavigation = message.data;
  }

  Map<String, dynamic>? _pendingNavigation;
  Map<String, dynamic>? consumePendingNavigation() {
    final nav = _pendingNavigation;
    _pendingNavigation = null;
    return nav;
  }

  /// Salva il messaggio nello store locale per lo storico notifiche
  void _saveToStore(RemoteMessage message) {
    final title =
        message.notification?.title ?? message.data['title'] ?? 'Notifica';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final event = message.data['event'] as String? ?? '';
    final orderId = message.data['order_id'] as String?;

    final item = NotificationItem(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      event: event,
      orderId: orderId,
      receivedAt: DateTime.now(),
    );
    NotificationStore().addNotification(item);
  }
}
