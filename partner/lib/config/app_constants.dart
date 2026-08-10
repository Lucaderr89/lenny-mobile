/// Costanti dell'applicazione Lenny Partner
class AppConstants {
  // API Configuration
  static const String baseUrl = 'https://lenny-staging.com';
  static const String apiUrl = '$baseUrl/api';

  // API Endpoints
  static const String loginEndpoint = '$apiUrl/partner/login';
  static const String logoutEndpoint = '$apiUrl/partner/logout';
  static const String ordersEndpoint = '$apiUrl/partner/orders';
  static const String confirmPickupEndpoint =
      '$apiUrl/partner/orders/{id}/confirm-pickup';
  static const String orderHistoryEndpoint = '$apiUrl/partner/orders/history';

  // App Info
  static const String appName = 'Lenny Partner';
  static const String appTagline = 'Gestisci i tuoi ordini';
  static const String appVersion = '1.0.0';

  // SharedPreferences Keys
  static const String keyIsLoggedIn = 'partner_is_logged_in';
  static const String keyAccessToken = 'partner_access_token';
  static const String keyApiToken = 'partner_api_token';
  static const String keyPartnerId = 'partner_id';
  static const String keyPartnerName = 'partner_name';
  static const String keyPartnerEmail = 'partner_email';
  static const String keyRestaurantId = 'restaurant_id';
  static const String keyRestaurantName = 'restaurant_name';

  // Validation
  static const int minPasswordLength = 6;

  // UI
  static const double borderRadius = 12.0;
  static const double buttonHeight = 56.0;
  static const double inputHeight = 56.0;
  static const double spacing = 16.0;

  // Timeouts
  static const int apiTimeout = 30; // seconds
  // Splash breve: e' uno strumento di lavoro, non una presentazione.
  static const int splashDuration = 2; // seconds

  // Orders
  static const int ordersRefreshInterval = 20; // seconds
}
