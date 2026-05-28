/// Response model per l'autenticazione partner
class AuthResponse {
  final bool success;
  final String message;
  final String? token;
  final PartnerData? partner;

  AuthResponse({
    required this.success,
    required this.message,
    this.token,
    this.partner,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Il token e partner possono essere dentro 'data' oppure al livello root
    final data = json['data'] as Map<String, dynamic>?;

    return AuthResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? 'Errore sconosciuto',
      token: data?['token'] ?? json['token'],
      partner:
          (data?['partner'] ??
                  json['partner'] ??
                  data?['restaurant'] ??
                  json['restaurant']) !=
              null
          ? PartnerData.fromJson(
              (data?['partner'] ??
                      json['partner'] ??
                      data?['restaurant'] ??
                      json['restaurant'])
                  as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// Dati del partner
class PartnerData {
  final int id;
  final String name;
  final String email;
  final int? restaurantId;
  final String? restaurantName;

  PartnerData({
    required this.id,
    required this.name,
    required this.email,
    this.restaurantId,
    this.restaurantName,
  });

  factory PartnerData.fromJson(Map<String, dynamic> json) {
    return PartnerData(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      restaurantId: json['id'], // L'id del partner è l'id del ristorante
      restaurantName: json['name'], // Il nome del ristorante
    );
  }
}
