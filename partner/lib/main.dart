import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'config/app_router.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';

/// Entry point dell'app Lenny Partner
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inizializza FCM push notifications
  await FcmService().initialize();

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
