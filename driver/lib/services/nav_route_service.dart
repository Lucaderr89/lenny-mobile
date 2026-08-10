import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';
import '../models/nav_route.dart';

/// Destinazione fuori dal grafo stradale (San Marino): il percorso non si
/// puo' calcolare, ma NON e' un guasto. L'app offre Google Maps.
class NavOutOfGraphException implements Exception {
  @override
  String toString() => 'Destinazione fuori dalla rete stradale coperta';
}

/// Motore stradale non raggiungibile o risposta rotta.
class NavUnavailableException implements Exception {
  @override
  String toString() => 'Motore stradale non disponibile';
}

/// Client di GET /api/driver/route: chiede al server geometria + istruzioni
/// per la gamba corrente (GPS attuale -> tappa). Il server cachea i percorsi
/// per ~2 minuti su posizioni arrotondate, quindi i ricalcoli ravvicinati
/// non costano nulla.
class NavRouteService {
  Future<NavRoute> fetchRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString(AppConstants.keyApiToken);
    if (apiToken == null) {
      throw NavUnavailableException();
    }

    final uri = Uri.parse(
      '${AppConstants.routeEndpoint}?from=$fromLat,$fromLng&to=$toLat,$toLng',
    );

    late http.Response response;
    try {
      response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiToken',
            },
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw NavUnavailableException();
    }

    if (response.statusCode == 422) {
      throw NavOutOfGraphException();
    }
    if (response.statusCode != 200) {
      throw NavUnavailableException();
    }

    try {
      final body = jsonDecode(response.body);
      dynamic route;
      if (body is Map) {
        final data = body['data'];
        if (data is Map) route = data['route'];
      }
      if (route is! Map) throw NavUnavailableException();
      return NavRoute.fromJson(Map<String, dynamic>.from(route));
    } on NavUnavailableException {
      rethrow;
    } catch (_) {
      throw NavUnavailableException();
    }
  }
}
