import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Servizio per geocoding e reverse geocoding con Nominatim (OpenStreetMap)
///
/// IMPORTANTE: Nominatim ha un limite di 1 richiesta al secondo.
/// Assicurati di rispettare la policy: https://operations.osmfoundation.org/policies/nominatim/
class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'LucaDev Customer App/1.0';

  /// Ricerca indirizzi tramite testo (autocomplete)
  ///
  /// [query] - Testo da cercare (es: "Via Roma, Milano")
  /// [limit] - Numero massimo di risultati (default: 5)
  /// [countryCode] - Codice paese ISO 3166-1 (es: "it" per Italia, "sm,it" per San Marino + Italia)
  ///
  /// Ritorna una lista di risultati con coordinate
  Future<List<NominatimResult>> searchAddress(
    String query, {
    int limit = 10,
    String countryCode = 'sm,it',
  }) async {
    if (query.isEmpty) return [];

    try {
      print('🔍 [NOMINATIM] Ricerca: "$query" (paesi: $countryCode)');

      // Bounding box per San Marino + area circostante (priorità geografica)
      // San Marino: lat 43.93-43.98, lon 12.40-12.52
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'q': query,
          'format': 'json',
          'addressdetails': '1',
          'limit': limit.toString(),
          'countrycodes': countryCode,
          'accept-language': 'it',
          'viewbox':
              '12.40,43.98,12.52,43.93', // lon_min,lat_max,lon_max,lat_min (San Marino area)
          'bounded':
              '0', // 0 = preferisce viewbox ma non esclude altri risultati
        },
      );

      final response = await http
          .get(
            uri,
            headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final results = data
            .map(
              (json) => NominatimResult.fromJson(json as Map<String, dynamic>),
            )
            .toList();

        print('✅ [NOMINATIM] ${results.length} risultati trovati');
        return results;
      } else {
        print('❌ [NOMINATIM] Errore HTTP: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ [NOMINATIM] Eccezione: $e');
      return [];
    }
  }

  /// Reverse geocoding: coordinate → indirizzo
  ///
  /// [latitude] - Latitudine
  /// [longitude] - Longitudine
  ///
  /// Ritorna un indirizzo formattato o null se fallisce
  Future<NominatimResult?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      print('📍 [NOMINATIM] Reverse geocoding: $latitude, $longitude');

      final uri = Uri.parse('$_baseUrl/reverse').replace(
        queryParameters: {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'format': 'json',
          'addressdetails': '1',
        },
      );

      final response = await http
          .get(
            uri,
            headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = NominatimResult.fromJson(data);

        print('✅ [NOMINATIM] Indirizzo: ${result.displayName}');
        return result;
      } else {
        print('❌ [NOMINATIM] Errore HTTP: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [NOMINATIM] Eccezione: $e');
      return null;
    }
  }
}

/// Risultato da Nominatim con coordinate e dettagli indirizzo
class NominatimResult {
  final String displayName;
  final LatLng coordinates;
  final String? road;
  final String? houseNumber;
  final String? city;
  final String? postcode;
  final String? country;

  NominatimResult({
    required this.displayName,
    required this.coordinates,
    this.road,
    this.houseNumber,
    this.city,
    this.postcode,
    this.country,
  });

  factory NominatimResult.fromJson(Map<String, dynamic> json) {
    final lat = double.parse(json['lat'].toString());
    final lon = double.parse(json['lon'].toString());
    final address = json['address'] as Map<String, dynamic>?;

    return NominatimResult(
      displayName: json['display_name'] as String,
      coordinates: LatLng(lat, lon),
      road: address?['road'] as String?,
      houseNumber: address?['house_number'] as String?,
      city:
          address?['city'] as String? ??
          address?['town'] as String? ??
          address?['village'] as String?,
      postcode: address?['postcode'] as String?,
      country: address?['country'] as String?,
    );
  }

  /// Indirizzo formattato breve (Via, Città)
  String get shortAddress {
    final parts = <String>[];
    if (road != null) {
      parts.add(houseNumber != null ? '$road $houseNumber' : road!);
    }
    if (city != null) parts.add(city!);
    return parts.join(', ');
  }

  /// Indirizzo formattato completo (Via Civico, CAP Città, Paese)
  String get formattedAddress {
    final parts = <String>[];

    // Via + Civico
    if (road != null) {
      if (houseNumber != null) {
        parts.add('$road $houseNumber');
      } else {
        parts.add(road!);
      }
    }

    // CAP + Città
    final cityPart = <String>[];
    if (postcode != null) cityPart.add(postcode!);
    if (city != null) cityPart.add(city!);
    if (cityPart.isNotEmpty) {
      parts.add(cityPart.join(' '));
    }

    // Paese
    if (country != null) parts.add(country!);

    return parts.isNotEmpty ? parts.join(', ') : displayName;
  }

  /// Indirizzo completo per salvataggio
  String get fullAddress {
    return displayName;
  }

  @override
  String toString() => formattedAddress;
}
