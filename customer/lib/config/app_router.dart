import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen_v5.dart';
import '../widgets/guest_gate.dart';
import '../screens/login_screen.dart';
import '../screens/registration_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/category_selection_screen.dart';
import '../screens/home_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../providers/cart_provider.dart';
import '../models/restaurant.dart';

/// Configurazione routing dell'app con GoRouter
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            NoTransitionPage(child: const SplashScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const OnboardingScreenV5(),
          fullscreenDialog: false,
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      // RegistrationScreen si disegna come un velo scuro con il pannello
      // bianco appoggiato in basso: sotto deve restare visibile la schermata
      // di partenza. Con una pagina opaca (il default) sotto non viene
      // disegnato piu' nulla e al posto della schermata precedente si vedeva
      // nero pieno. Da qui passano tutti gli ingressi: profilo, gate ospite
      // e il link "Registrati" del login.
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          opaque: false,
          barrierColor: Colors.transparent, // il velo lo disegna la schermata
          transitionsBuilder: (context, animation, _, child) => SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
          child: const RegistrationScreen(),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordScreen(email: (state.extra as String?) ?? ''),
      ),
      GoRoute(
        path: '/categories',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const CategorySelectionScreen(),
          fullscreenDialog: false,
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const HomeScreen(),
          fullscreenDialog: false,
        ),
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) {
          // Prende i dati dal CartProvider
          final cartProvider = Provider.of<CartProvider>(
            context,
            listen: false,
          );

          // Scheletro dai dati del CartProvider: il carrello carica da solo
          // i dati veri via API — niente "30 min" finti.
          final restaurant = Restaurant(
            id: cartProvider.restaurantId ?? 0,
            name: cartProvider.restaurantName ?? 'Carrello',
            cuisine: '',
            rating: 0.0,
            deliveryTime: '',
            deliveryCost: 'Gratis',
            minOrder: '€0',
            imageUrl: '',
            logoUrl: cartProvider.restaurantLogoUrl,
            description: '',
            address: '',
            phone: '',
          );

          return CartScreen(
            restaurant: restaurant,
            cartItems: cartProvider.items,
          );
        },
      ),
      // Sezioni personali: per l'ospite mostrano l'invito a registrarsi invece
      // di far partire chiamate che fallirebbero senza account.
      GoRoute(
        path: '/profile',
        builder: (context, state) => const SoloUtenti(
          schermata: ProfileScreen(),
          titolo: 'Il tuo profilo',
          messaggio:
              'Crea un account per salvare i tuoi indirizzi, vedere lo storico degli ordini e usare il portafoglio.',
          icona: 'assets/icons_svg/icons8-user-male-32.svg',
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const SoloUtenti(
          schermata: NotificationsScreen(),
          titolo: 'Le tue notifiche',
          messaggio:
              'Con un account ti avvisiamo a ogni passo del tuo ordine, dalla conferma alla consegna.',
          icona: 'assets/icons_svg/icons8-allarme-32.svg',
        ),
      ),
    ],
  );
}
