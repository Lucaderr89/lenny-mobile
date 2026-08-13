/// Costanti dell'applicazione Lenny Customer
class AppConstants {
  // API Configuration
  // NOTA: URL pubblico staging per testare pagamenti Nexi
  static const String baseUrl = 'https://lenny-staging.com';
  static const String apiUrl = '$baseUrl/api';

  // Informativa privacy servita dal nostro frontend (GDPR + Legge RSM 171/2018).
  // NON puntare a lenny.sm: quel sito verra' dismesso.
  static const String privacyPolicyUrl = '$baseUrl/website/privacy.html';
  static const String termsUrl = '$baseUrl/website/privacy.html';

  // API Endpoints
  static const String loginEndpoint = '$apiUrl/customer/login';
  static const String registerEndpoint = '$apiUrl/customer/register';
  static const String updateProfileEndpoint = '$apiUrl/customer/profile/update';
  // Il logout passa dall'endpoint del cliente e non da quello condiviso:
  // /auth/logout identifica l'utente dalla sessione PHP, che per l'app non
  // esiste (si autentica col token API), quindi non sapeva nemmeno chi stesse
  // uscendo. /customer/logout riconosce il token e cancella quello FCM.
  static const String logoutEndpoint = '$apiUrl/customer/logout';
  static const String meEndpoint = '$apiUrl/auth/me';
  static const String firebaseTokenEndpoint = '$apiUrl/auth/firebase-token';
  static const String forgotPasswordEndpoint = '$apiUrl/auth/forgot-password';
  static const String restaurantsEndpoint = '$apiUrl/restaurants';

  // App Info
  static const String appName = 'Lenny';
  static const String appTagline = 'Il delivery è di casa';
  static const String appVersion = '1.0.0';

  // SharedPreferences Keys
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyAccessToken = 'access_token';
  static const String keyApiToken = 'api_token';
  static const String keySessionId = 'session_id';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyUserFullname = 'user_fullname';
  static const String keyUserPhone = 'user_phone';
  static const String keyIsFirstLaunch = 'is_first_launch';
  static const String keyRememberMe = 'remember_me';
  static const String keyUserPassword = 'user_password';
  static const String keySpesaMagicHash = 'spesa_magic_hash';

  // Validation
  static const int minPasswordLength = 6;
  static const int smacLength = 6;
  static const int phoneMinLength = 10;

  // UI
  static const double borderRadius = 12.0;
  static const double buttonHeight = 56.0;
  static const double inputHeight = 56.0;
  static const double spacing = 16.0;

  // Timeouts
  static const int apiTimeout = 60; // seconds
  static const int splashDuration = 3; // seconds

  // Social Login (da implementare in futuro)
  static const String googleClientId = '';
  static const String facebookAppId = '';
  static const String appleClientId = '';
}
