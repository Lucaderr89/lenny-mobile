import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'config/app_router.dart';
import 'services/fcm_service.dart';

/// Entry point dell'app Lenny Driver
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza Firebase (necessario prima di usare FCM; veloce, no rete)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
    return MaterialApp.router(
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
    );
  }
}
