import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'config/app_router.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';

/// Entry point dell'app Lenny Partner
void main() async {
  // runZonedGuarded cattura anche gli errori asincroni che sfuggono a Flutter:
  // sono i piu' comuni e, senza, resterebbero invisibili.
  runZonedGuarded<Future<void>>(() async {
    await _avvia();
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

Future<void> _avvia() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Poppins e' incluso nell'app (vedi la sezione fonts del pubspec): questo
  // impedisce a google_fonts di scaricarlo comunque dalla rete. Senza, in
  // assenza di connessione o prima che il download finisse, le schermate
  // uscivano nel font di sistema invece che in Poppins.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Inizializza Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── Crash reporting ────────────────────────────────────────────────────
  // Disattivato in debug: le prove di sviluppo non devono sporcare la
  // dashboard usata per monitorare i tablet in sala.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseCrashlytics.instance.setCustomKey('ambiente', AppConstants.baseUrl);
  FirebaseCrashlytics.instance.setCustomKey('app', 'partner');

  // Configurazione globale per gestire correttamente le barre di sistema
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Abilita edge-to-edge per gestire correttamente SafeArea
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // NB: nessuna inizializzazione stampante: su sunmi_printer_plus 4.x
  // initPrinter/bindingPrinter sono no-op deprecati; la disponibilita'
  // reale la da' SunmiConfig.getStatus() (vedi PrinterService).

  runApp(const LennyPartnerApp());

  // FCM DOPO il primo fotogramma e senza await: a permesso concesso
  // initialize() aspetta il device token, che puo' tardare decine di secondi.
  // Prima di runApp() teneva il tablet su uno schermo bianco per tutto quel
  // tempo, a ogni avvio. catchError e non try/catch perche' senza await un
  // errore diventerebbe un crash fatale segnalato da runZonedGuarded.
  FcmService().initialize().catchError((Object e) {
    debugPrint('⚠️ FCM non disponibile: $e');
  });
}

class LennyPartnerApp extends StatelessWidget {
  const LennyPartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
