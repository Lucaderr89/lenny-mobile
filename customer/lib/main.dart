import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
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
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza Firebase
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Già inizializzato (hot-restart / debug) — ignorato
  }
  // Inizializza FCM push notifications
  try {
    await FcmService().initialize();
  } catch (e) {
    debugPrint('⚠️ FCM non disponibile su questo dispositivo: $e');
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
