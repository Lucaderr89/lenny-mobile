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
    // Gestisce sia error come stringa che come oggetto {"message","code"}
    String? errorMsg;
    if (json['error'] != null) {
      if (json['error'] is String) {
        errorMsg = json['error'] as String;
      } else if (json['error'] is Map) {
        errorMsg = (json['error'] as Map)['message']?.toString();
      }
    }
    return AuthResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? errorMsg ?? '',
      data: json['data'] != null
          ? AuthData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      error: errorMsg,
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
