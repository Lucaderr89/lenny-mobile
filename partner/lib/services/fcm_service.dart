import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';

/// Handler per notifiche ricevute in background (top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 [FCM Background Partner] ${message.notification?.title}');
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
    'Ordini Lenny',
    description: 'Notifiche per nuovi ordini e aggiornamenti',
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound('notifica'),
    enableVibration: true,
  );

  // Stream per notificare HomeScreen di messaggi FCM in foreground
  final _messageStreamController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onForegroundMessage =>
      _messageStreamController.stream;

  Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('🔔 FCM Partner permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    _token = await _messaging.getToken();
    debugPrint('📱 FCM Partner Token: $_token');

    await _registerTokenOnBackend();

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
    // L'app gira solo su tablet Sunmi, ma le impostazioni iOS restano
    // obbligatorie per il plugin: senza, initialize() solleverebbe "iOS
    // settings must be set when targeting iOS platform" appena qualcuno
    // provasse a compilarla per iOS, saltando tutto il resto del setup.
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(initSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // Su Android in foreground FCM non mostra nulla nativamente:
    // disabilitiamo il banner nativo e lo gestiremo noi con local notifications
    // badge: false apposta. Il server manda aps.badge = 1 in ogni push, e con
    // l'app gia' aperta iOS lo applicherebbe comunque - ma applicationDidBecomeActive,
    // che e' cio' che azzera il badge, e' gia' scattato all'apertura e non riscatta.
    // Il "1" resterebbe quindi appiccicato all'icona fino alla riapertura successiva.
    // Un contatore sull'icona mentre sei dentro l'app non serve comunque a nulla:
    // il segnale in foreground e' la notifica stessa, non il badge.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
  }

  String? get token => _token;

  Future<void> _registerTokenOnBackend() async {
    if (_token == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(AppConstants.keyApiToken);
      if (authToken == null) return;

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/restaurant/fcm-token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $authToken',
        },
        body: {'fcm_token': _token!},
      );
      debugPrint(
        response.statusCode == 200
            ? '✅ Partner FCM token registrato'
            : '⚠️ Errore: ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('❌ Errore FCM partner: $e');
    }
  }

  Future<void> onUserLoggedIn() async => _registerTokenOnBackend();

  Future<void> onUserLoggedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(AppConstants.keyApiToken);
      if (authToken == null) return;
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/restaurant/fcm-token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $authToken',
        },
        body: {'fcm_token': ''},
      );
    } catch (e) {
      debugPrint('❌ Errore rimozione FCM partner: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 [FCM Foreground Partner] ${message.notification?.title}');
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
    _messageStreamController.add(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 [FCM Tap Partner] data: ${message.data}');
    _pendingNavigation = message.data;
  }

  Map<String, dynamic>? _pendingNavigation;
  Map<String, dynamic>? consumePendingNavigation() {
    final nav = _pendingNavigation;
    _pendingNavigation = null;
    return nav;
  }
}
