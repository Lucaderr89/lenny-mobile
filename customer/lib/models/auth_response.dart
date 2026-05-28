/// Modello per la risposta API di autenticazione
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
    // Gestisce sia error come stringa che come oggetto
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
}

class AuthData {
  final CustomerData? customer;
  final String? firebaseToken;
  final String? sessionId;
  final String? apiToken;
  final int? customerId;
  final String? spesaMagicHash;

  AuthData({
    this.customer,
    this.firebaseToken,
    this.sessionId,
    this.apiToken,
    this.customerId,
    this.spesaMagicHash,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      customer: json['customer'] != null
          ? CustomerData.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      firebaseToken: json['firebase_token'] as String?,
      sessionId: json['session_id'] as String?,
      apiToken: json['api_token'] as String?,
      customerId: json['customer_id'] as int?,
      spesaMagicHash: json['spesa_magic_hash'] as String?,
    );
  }
}

class CustomerData {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String status;

  CustomerData({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    required this.status,
  });

  String get fullName => '$firstName $lastName';

  factory CustomerData.fromJson(Map<String, dynamic> json) {
    return CustomerData(
      id: json['id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      status: json['status'] as String? ?? 'active',
    );
  }
}
