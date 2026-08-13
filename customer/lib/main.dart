import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'config/app_router.dart';
import 'firebase_options.dart';
import 'providers/cart_provider.dart';
import 'providers/location_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/notification_provider.dart';
import 'services/fcm_service.dart';

/// Entry point dell'app Lenny Customer
void main() async {
  // runZonedGuarded cattura anche gli errori asincroni che sfuggono a Flutter
  // (Future senza catch, callback, isolate del main): senza, in beta resterebbero
  // invisibili.
  runZonedGuarded<Future<void>>(
    () async {
      await _avvia();
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
    // In release nessuna print() finisce nel log di sistema. Nel codice ce ne
    // sono centinaia che stampano corpi di risposta e di richiesta: contengono
    // token di sessione, dati personali dei clienti e, al login, la password.
    // Su logcat sarebbero leggibili da chi ha accesso al dispositivo via ADB.
    // In debug restano, perche' li' servono.
    // La profile e' inclusa perche' non viene distribuita e serve a
    // collaudare su dispositivo reale: senza log non si leggerebbe
    // nemmeno il token FCM. La release resta muta.
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, riga) {
        if (kDebugMode || kProfileMode) parent.print(zone, riga);
      },
    ),
  );
}

Future<void> _avvia() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Poppins e' incluso nell'app (vedi la sezione fonts del pubspec): questo
  // impedisce a google_fonts di scaricarlo comunque dalla rete. Senza, in
  // assenza di connessione o prima che il download finisse, le schermate
  // uscivano nel font di sistema invece che in Poppins.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Inizializza Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ── Crash reporting ────────────────────────────────────────────────────
    // In debug non si inviano segnalazioni: altrimenti ogni prova durante lo
    // sviluppo sporcherebbe la dashboard usata per la beta.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );

    // Errori del framework (build, layout, gesture)
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // Errori della piattaforma non gestiti
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    FirebaseCrashlytics.instance.setCustomKey('ambiente', AppConstants.baseUrl);
  } catch (e) {
    // Già inizializzato (hot-restart / debug) — ignorato
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

  runApp(const LennyCustomerApp());

  // FCM DOPO il primo fotogramma e senza await.
  //
  // A permesso concesso initialize() si mette ad aspettare il device token di
  // APNs, che puo' arrivare dopo decine di secondi o non arrivare affatto.
  // Farlo prima di runApp() significava tenere l'utente davanti a uno schermo
  // bianco per tutto quel tempo, a ogni singolo avvio: nemmeno lo splash
  // partiva. Qui invece l'app e' gia' a video e il token si registra da solo
  // quando arriva.
  //
  // catchError e non try/catch: senza await, un errore diventerebbe un errore
  // asincrono non gestito, che runZonedGuarded segnalerebbe a Crashlytics
  // come crash fatale a ogni avvio.
  FcmService().initialize().catchError((Object e) {
    debugPrint('⚠️ FCM non disponibile su questo dispositivo: $e');
  });
}

class LennyCustomerApp extends StatelessWidget {
  const LennyCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final cartProvider = CartProvider();
            cartProvider.loadCart(); // Carica il carrello salvato
            return cartProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final locationProvider = LocationProvider();
            locationProvider.initialize(); // Inizializza geolocalizzazione
            return locationProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final favoritesProvider = FavoritesProvider();
            favoritesProvider.loadFavorites(); // Carica i preferiti
            return favoritesProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,

        // 🇮🇹 Localizzazione italiana
        locale: const Locale('it', 'IT'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('it', 'IT')],

        routerConfig: AppRouter.router,
      ),
    );
  }
}
