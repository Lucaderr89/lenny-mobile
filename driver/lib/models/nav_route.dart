/// Percorso navigabile restituito da GET /api/driver/route.
///
/// Stessa shape del motore GraphHopper del progetto taxi: geometria GeoJSON
/// grezza [[lng,lat], ...] (niente polyline codificata) e istruzioni gia'
/// in italiano. `interval` di ogni istruzione = indici [inizio, fine] del
/// tratto nella geometria: e' il gancio che permette di far scalare i metri
/// localmente (NavGuidance) senza chiedere nulla al server.
class NavInstruction {
  final String text;
  final String streetName;
  final int distanceM; // metri del tratto
  final int timeS; // secondi del tratto
  final int sign; // codice manovra GraphHopper: -3..3, 4 arrivo, 6 rotonda, +-7
  final List<int> interval; // [idxInizio, idxFine] nella geometria

  NavInstruction({
    required this.text,
    required this.streetName,
    required this.distanceM,
    required this.timeS,
    required this.sign,
    required this.interval,
  });

  factory NavInstruction.fromJson(Map<String, dynamic> json) {
    return NavInstruction(
      text: json['text']?.toString() ?? '',
      streetName: json['street_name']?.toString() ?? '',
      distanceM: int.tryParse(json['distance']?.toString() ?? '0') ?? 0,
      timeS: int.tryParse(json['time']?.toString() ?? '0') ?? 0,
      sign: int.tryParse(json['sign']?.toString() ?? '0') ?? 0,
      interval: (json['interval'] is List)
          ? (json['interval'] as List)
                .map((v) => int.tryParse(v.toString()) ?? 0)
                .toList()
          : const [],
    );
  }
}

class NavRoute {
  final int distanceM;
  final int timeS;
  final List<List<double>> coordinates; // [[lng,lat], ...] cosi' come arriva
  final List<NavInstruction> instructions;

  NavRoute({
    required this.distanceM,
    required this.timeS,
    required this.coordinates,
    required this.instructions,
  });

  factory NavRoute.fromJson(Map<String, dynamic> json) {
    final coords = <List<double>>[];
    if (json['coordinates'] is List) {
      for (final c in json['coordinates'] as List) {
        if (c is List && c.length >= 2) {
          final lng = double.tryParse(c[0].toString());
          final lat = double.tryParse(c[1].toString());
          if (lng != null && lat != null) coords.add([lng, lat]);
        }
      }
    }
    return NavRoute(
      distanceM: int.tryParse(json['distance']?.toString() ?? '0') ?? 0,
      timeS: int.tryParse(json['time']?.toString() ?? '0') ?? 0,
      coordinates: coords,
      instructions: (json['instructions'] is List)
          ? (json['instructions'] as List)
                .whereType<Map>()
                .map((i) => NavInstruction.fromJson(Map<String, dynamic>.from(i)))
                .toList()
          : const [],
    );
  }
}
