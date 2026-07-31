import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen_v5.dart';
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
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          email: (state.extra as String?) ?? '',
        ),
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

          // Crea un Restaurant dai dati del CartProvider
          final restaurant = Restaurant(
            id: cartProvider.restaurantId ?? 0,
            name: cartProvider.restaurantName ?? 'Carrello',
            cuisine: '',
            rating: 0.0,
            deliveryTime: '30 min',
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
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
}
