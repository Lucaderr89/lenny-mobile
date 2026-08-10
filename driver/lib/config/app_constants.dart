/// Costanti dell'applicazione Lenny Driver
class AppConstants {
  // API Configuration
  static const String baseUrl = 'https://lenny-staging.com';
  static const String apiUrl = '$baseUrl/api';

  // API Endpoints
  static const String loginEndpoint = '$apiUrl/driver/login';
  static const String registerEndpoint = '$apiUrl/driver/register';
  static const String logoutEndpoint = '$apiUrl/driver/logout';
  static const String meEndpoint = '$apiUrl/driver/me';
  static const String ordersEndpoint = '$apiUrl/driver/orders';
  static const String updateLocationEndpoint = '$apiUrl/driver/location';
  // Tracking GPS leggero (no sessione): attivo solo quando il driver ha ordini attivi
  static const String trackLocationEndpoint = '$apiUrl/driver/track-location';
  // Navigazione in-app: percorso GPS attuale -> tappa (geometria + istruzioni)
  static const String routeEndpoint = '$apiUrl/driver/route';

  // App Info
  static const String appName = 'Lenny Driver';
  static const String appTagline = 'Consegne intelligenti';
  static const String appVersion = '1.0.0';

  // SharedPreferences Keys
  static const String keyIsLoggedIn = 'driver_is_logged_in';
  static const String keyAccessToken = 'driver_access_token';
  static const String keyApiToken = 'driver_api_token';
  static const String keyDriverId = 'driver_id';
  static const String keyDriverName = 'driver_name';
  static const String keyDriverEmail = 'driver_email';
  static const String keyDriverPhone = 'driver_phone';
  static const String keyRememberMe = 'driver_remember_me';
  static const String keyLocationPermissionAsked =
      'driver_location_permission_asked';

  // Validation
  static const int minPasswordLength = 6;

  // UI
  static const double borderRadius = 12.0;
  static const double buttonHeight = 56.0;
  static const double inputHeight = 56.0;
  static const double spacing = 16.0;

  // Timeouts
  static const int apiTimeout = 30; // seconds
  static const int splashDuration = 3; // seconds

  // Location
  static const int locationUpdateInterval = 30; // seconds
  static const double locationAccuracyThreshold = 50.0; // meters
}
