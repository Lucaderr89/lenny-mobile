import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'config/app_router.dart';
import 'overlay/bolla_overlay.dart';
import 'services/fcm_service.dart';
import 'services/theme_controller.dart';

/// Entry point dell'app Lenny Driver
void main() async {
  // runZonedGuarded cattura anche gli errori asincroni che sfuggono a Flutter:
  // sono i piu' comuni e, senza, resterebbero invisibili.
  runZonedGuarded<Future<void>>(() async {
    await _avvia();
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  },
      // In release nessuna print() finisce nel log di sistema: nel codice ce ne
      // sono che stampano il corpo delle richieste di login e registrazione,
      // quindi password e IBAN in chiaro, e il token di sessione.
      // In debug restano, perche' li' servono.
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, riga) {
          if (kDebugMode) parent.print(zone, riga);
        },
      ));
}

/// Entry point della BOLLA overlay (engine separato, avviato dal
/// servizio Android di flutter_overlay_window). Deve stare in main.dart
/// e chiamarsi overlayMain.
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BollaOverlay());
}

Future<void> _avvia() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza Firebase (necessario prima di usare FCM; veloce, no rete)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ── Crash reporting ────────────────────────────────────────────────────
    // Disattivato in debug: le prove di sviluppo non devono sporcare la
    // dashboard usata per monitorare i driver sul campo.
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
    FirebaseCrashlytics.instance.setCustomKey('app', 'driver');
  } catch (e) {
    debugPrint('Firebase già inizializzato: $e');
  }

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

  // Tema (chiaro/notte): legge solo le prefs, non blocca l'avvio.
  await ThemeController().init();

  // Avvia SUBITO la UI: NON blocchiamo l'apertura dell'app sulle chiamate di
  // rete FCM (getToken + registrazione token sul backend). Era la causa del
  // "devo cliccare più volte la push": ad app chiusa il primo frame restava
  // in attesa di quelle chiamate, dando l'impressione che il tap non aprisse.
  runApp(const LennyDriverApp());

  // Inizializza FCM DOPO, in background (non-bloccante).
  FcmService().initialize();
}

class LennyDriverApp extends StatelessWidget {
  const LennyDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Il tema segue ThemeController: automatico col sole o fisso da
    // impostazioni. ValueListenableBuilder ricostruisce al cambio.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController().themeMode,
      builder: (context, mode, _) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,

          // Localizzazione italiana
          locale: const Locale('it', 'IT'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('it', 'IT')],

          routerConfig: AppRouter.router,
        );
      },
    );
  }
}
