import 'driver.dart';

/// Risposta dell'API di autenticazione driver
class AuthResponse {
  final bool success;
  final String message;
  final AuthData? data;
  final String? error;

  AuthResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? AuthData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data?.toJson(),
      'error': error,
    };
  }
}

/// Dati dell'autenticazione driver
class AuthData {
  final String? sessionId;
  final String? apiToken;
  final Driver? driver;
  final int? driverId;

  AuthData({this.sessionId, this.apiToken, this.driver, this.driverId});

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      sessionId: json['session_id'] as String?,
      apiToken: json['api_token'] as String?,
      driver: json['driver'] != null
          ? Driver.fromJson(json['driver'] as Map<String, dynamic>)
          : null,
      driverId: json['driver_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'api_token': apiToken,
      'driver': driver?.toJson(),
      'driver_id': driverId,
    };
  }
}
