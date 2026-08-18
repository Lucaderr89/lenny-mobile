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
    debugPrint(
      '🔔 FCM permission (richiesta): ${settings.authorizationStatus}',
    );

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
  ///
  /// L'attesa e' lunga di proposito: la primissima registrazione di un bundle
  /// id su un dispositivo puo' richiedere parecchi secondi, e arrendersi
  /// troppo presto lascia l'utente senza push per tutta la sessione.
  Future<bool> _attendiApnsToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;

    for (var tentativo = 0; tentativo < 60; tentativo++) {
      if (await _messaging.getAPNSToken() != null) {
        debugPrint('📮 APNs token ricevuto dopo ${tentativo * 500}ms');
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    debugPrint('⚠️ APNs non ha consegnato il token entro 30s');
    return false;
  }

  /// Token, handlers e canale notifiche: eseguito solo a permesso concesso
  Future<void> _setupMessaging() async {
    if (!await _attendiApnsToken()) {
      // Senza device token APNs, getToken() puo' solo fallire: inutile
      // chiamarlo e sporcare il log con un errore che non aggiunge nulla.
      debugPrint('⚠️ Push non attive: nessun device token da APNs');
      return;
    }

    // 2. Ottieni token FCM
    try {
      _token = await _messaging.getToken();
      debugPrint('📱 FCM Token: $_token');
    } catch (e) {
      debugPrint('⚠️ FCM Token non ottenibile: $e');
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
    // Le impostazioni iOS sono obbligatorie anche se qui non chiediamo nulla:
    // senza, initialize() solleva "iOS settings must be set when targeting iOS
    // platform" e tutto il resto del setup non viene eseguito. I permessi sono
    // gia' stati chiesti da firebase_messaging, quindi qui si disattivano per
    // non far comparire un secondo prompt di sistema.
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

    // Crea il canale Android con suono custom (idempotente)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // 10. Notifiche ad app aperta.
    //     Su Android FCM non le mostra da solo e le disegniamo noi con
    //     flutter_local_notifications, per avere il suono custom del canale.
    //     Su iOS il suono custom non passa da li' e replicare la notifica a
    //     mano la farebbe comparire due volte: si lascia fare al sistema.
    final bool suIos = defaultTargetPlatform == TargetPlatform.iOS;
    // badge: false apposta. Il server manda aps.badge = 1 in ogni push, e con
    // l'app gia' aperta iOS lo applicherebbe comunque - ma applicationDidBecomeActive,
    // che e' cio' che azzera il badge, e' gia' scattato all'apertura e non riscatta.
    // Il "1" resterebbe quindi appiccicato all'icona fino alla riapertura successiva.
    // Un contatore sull'icona mentre sei dentro l'app non serve comunque a nulla:
    // il segnale in foreground e' la notifica stessa, non il badge.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: suIos,
      badge: false,
      sound: suIos,
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

  /// Da chiamare subito dopo un login o una registrazione andati a buon fine.
  ///
  /// E' l'unico punto in cui si chiede il permesso notifiche. L'app e'
  /// guest-first e iOS mostra il prompt di sistema una volta sola per
  /// installazione: chiederlo prima, mentre l'utente sta ancora solo
  /// guardando, significa raccogliere rifiuti definitivi da persone che poi
  /// si registrano e non ricevono piu' nessun aggiornamento sull'ordine.
  /// Qui invece l'utente si e' appena iscritto ed e' il momento in cui le
  /// push iniziano davvero a servirgli.
  Future<void> onUserLoggedIn() async {
    final settings = await _messaging.getNotificationSettings();

    switch (settings.authorizationStatus) {
      case AuthorizationStatus.notDetermined:
        // Primo login: mostra il prompt di sistema. Se accetta,
        // requestPermissionWithContext registra gia' il token sul backend.
        await requestPermissionWithContext();
      case AuthorizationStatus.denied:
        // Rifiutato in passato: iOS non ripropone il prompt, inutile insistere.
        return;
      default:
        // Gia' concesso. Se il token non e' ancora stato preso in questa
        // sessione (es. permesso concesso dalle Impostazioni di sistema ad
        // app aperta) si completa qui il setup, che registra da solo.
        if (_token == null) {
          await _setupMessaging();
        } else {
          await _registerTokenOnBackend();
        }
    }
  }

  // NB: qui non esiste piu' un onUserLoggedOut(). Quello che c'era mandava
  // fcm_token vuoto a /customer/fcm-token, che lo rifiuta con 400 perche' il
  // campo e' obbligatorio: non avrebbe funzionato nemmeno se qualcuno lo
  // avesse chiamato, e nessuno lo chiamava. La cancellazione del token ora
  // avviene lato server dentro /customer/logout, che AuthService.logout()
  // invoca a ogni uscita.

  /// Gestisce notifiche ricevute con app in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 [FCM Foreground] ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    // Su iOS la mostra il sistema (vedi
    // setForegroundNotificationPresentationOptions): disegnarla anche qui la
    // farebbe comparire due volte. I dettagli sotto sono solo Android.
    if (defaultTargetPlatform == TargetPlatform.iOS) return;

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
