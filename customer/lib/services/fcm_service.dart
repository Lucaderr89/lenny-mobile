import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';

/// Handler per notifiche ricevute in background (top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    '🔔 [FCM Background] ${message.notification?.title}: ${message.notification?.body}',
  );
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  String? _token;

  // Canale Android con suono custom
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'lenny_orders',
    'Ordini Lenny',
    description: 'Notifiche per nuovi ordini e aggiornamenti',
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound('notifica'),
    enableVibration: true,
  );

  /// Inizializza FCM: handlers e token, SENZA chiedere il permesso.
  /// Il prompt di sistema al bootstrap (prima ancora di vedere l'app) e' il
  /// momento con il massimo tasso di rifiuto: la richiesta ora avviene dopo
  /// il primo ordine, con contesto ("ti avvisiamo quando arriva"), tramite
  /// [requestPermissionWithContext]. Qui si procede solo se il permesso
  /// risulta gia' concesso in passato.
  Future<void> initialize() async {
    final settings = await _messaging.getNotificationSettings();
    debugPrint('🔔 FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied ||
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      // Mai chiesto o negato: nessun prompt qui. Handlers e token verranno
      // attivati da requestPermissionWithContext() dopo il primo ordine.
      return;
    }

    await _setupMessaging();
  }

  /// Chiede il permesso notifiche NEL MOMENTO GIUSTO (dopo il primo ordine,
  /// da una UI che ha appena spiegato il beneficio). Ritorna true se concesso.
  Future<bool> requestPermissionWithContext() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('🔔 FCM permission (richiesta): ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }

    await _setupMessaging();
    return true;
  }

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

  /// Token, handlers e canale notifiche: eseguito solo a permesso concesso
  Future<void> _setupMessaging() async {
    await _attendiApnsToken();

    // 2. Ottieni token FCM
    try {
      _token = await _messaging.getToken();
      debugPrint('📱 FCM Token: $_token');
    } catch (e) {
      debugPrint('⚠️ FCM Token non ottenibile (APNs non configurato o account free): $e');
      return;
    }

    // 3. Registra token sul backend se l'utente è autenticato
    await _registerTokenOnBackend();

    // 4. Aggiorna token se cambia
    _messaging.onTokenRefresh.listen((newToken) {
      _token = newToken;
      debugPrint('🔄 FCM Token aggiornato: $newToken');
      _registerTokenOnBackend();
    });

    // 5. Handler notifiche in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 6. Handler tap notifica quando app è in background (ma aperta)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 7. Controlla se l'app è stata aperta da una notifica (app terminata)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // 8. Handler background (top-level)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 9. Inizializza flutter_local_notifications con canale custom
    // Icona di notifica dedicata: Android ne usa solo il canale alpha, quindi
    // deve essere una silhouette su trasparente. L'icona del launcher e' opaca
    // e verrebbe resa come un quadrato bianco.
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
    await _localNotifications.initialize(initSettings);

    // Crea il canale Android con suono custom (idempotente)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // 10. Su Android: FCM non mostra notifiche foreground nativamente,
    //     le mostriamo manualmente tramite flutter_local_notifications
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false, // disabilita il banner FCM nativo in foreground
      badge: true,
      sound: false, // gestiamo noi il suono tramite local notifications
    );
  }

  String? get token => _token;

  /// Registra il token FCM sul backend Lenny
  Future<void> _registerTokenOnBackend() async {
    if (_token == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(AppConstants.keyApiToken);
      if (authToken == null) return; // utente non autenticato

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/customer/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcm_token': _token!}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Token FCM registrato sul backend');
      } else {
        debugPrint(
          '⚠️ Errore registrazione token: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Errore registrazione FCM token: $e');
    }
  }

  /// Chiamato quando l'utente esegue il login — re-registra il token
  Future<void> onUserLoggedIn() async {
    await _registerTokenOnBackend();
  }

  /// Chiamato quando l'utente fa logout — rimuove token dal backend
  Future<void> onUserLoggedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(AppConstants.keyApiToken);
      if (authToken == null) return;

      await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/customer/fcm-token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $authToken',
        },
        body: {'fcm_token': ''},
      );
    } catch (e) {
      debugPrint('❌ Errore rimozione FCM token: $e');
    }
  }

  /// Gestisce notifiche ricevute con app in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 [FCM Foreground] ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    // Mostra notifica locale con il canale lenny_orders (suono custom)
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

  /// Gestisce il tap su una notifica
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 [FCM Tap] data: ${message.data}');
    final action = message.data['action'] ?? '';
    final orderId = message.data['order_id'];

    // La navigazione viene gestita tramite il navigator globale
    // che viene impostato in main.dart
    _pendingNavigation = {'action': action, 'order_id': orderId};
  }

  /// Navigazione pendente da notifica (consumata da main.dart)
  Map<String, dynamic>? _pendingNavigation;
  Map<String, dynamic>? consumePendingNavigation() {
    final nav = _pendingNavigation;
    _pendingNavigation = null;
    return nav;
  }
}
