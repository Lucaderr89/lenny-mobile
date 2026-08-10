import 'dart:math';

import '../models/nav_route.dart';

/// Proiezione della posizione GPS sulla geometria del percorso.
class ProiezioneRotta {
  final double distanzaDalPercorsoM; // scostamento laterale dal percorso
  final double metriPercorsi; // metri gia' percorsi lungo la rotta

  ProiezioneRotta({
    required this.distanzaDalPercorsoM,
    required this.metriPercorsi,
  });
}

/// Manovra in arrivo con la distanza REALE che scala a ogni fix GPS.
class ManovraCorrente {
  final NavInstruction istruzione;
  final int metriRestanti;

  ManovraCorrente({required this.istruzione, required this.metriRestanti});
}

/// Guida locale sopra una NavRoute: proietta il GPS sulla geometria per far
/// scalare i metri alla manovra SENZA chiamate di rete (il taxi, da cui viene
/// il porting, aggiornava il numero solo al refresh dal server ogni 18 s), e
/// riconosce l'uscita dal percorso.
///
/// Geometria: coordinate GeoJSON [[lng,lat], ...]. Distanze con proiezione
/// equirettangolare corretta per cos(lat): su tratte urbane di San Marino
/// (< 10 km, ~44 gradi nord) l'errore e' trascurabile. Poche centinaia di
/// vertici a ~1 Hz: il costo e' irrilevante.
class NavGuidance {
  /// Fuori percorso = scostamento oltre questa soglia...
  static const double sogliaFuoriPercorsoM = 40;

  /// ...per questo numero di fix consecutivi (un singolo fix storto non conta).
  static const int fixFuoriConsecutivi = 3;

  /// Fix con accuracy peggiore di cosi' non giudicano il fuori-percorso.
  static const double accuracyMassimaM = 30;

  final NavRoute route;

  /// Metri cumulati dall'inizio della rotta a ogni vertice della geometria.
  late final List<double> _cum;

  int _fixFuori = 0;

  NavGuidance(this.route) {
    final coords = route.coordinates;
    _cum = List<double>.filled(coords.length, 0);
    for (var i = 1; i < coords.length; i++) {
      _cum[i] =
          _cum[i - 1] +
          _distanzaM(
            coords[i - 1][1],
            coords[i - 1][0],
            coords[i][1],
            coords[i][0],
          );
    }
  }

  /// Lunghezza totale della geometria in metri.
  double get lunghezzaM => _cum.isEmpty ? 0 : _cum.last;

  /// Proietta il punto GPS sul segmento piu' vicino della rotta.
  /// UNA proiezione per fix: i metodi ...Da() sotto la riusano, cosi' la
  /// geometria si scandisce una volta sola per aggiornamento GPS.
  ProiezioneRotta proietta(double lat, double lng) {
    final coords = route.coordinates;
    if (coords.length < 2) {
      return ProiezioneRotta(distanzaDalPercorsoM: 0, metriPercorsi: 0);
    }

    // Piano locale in metri centrato sul punto GPS.
    final mPerLat = 111320.0;
    final mPerLng = 111320.0 * cos(lat * pi / 180);

    var migliorDist = double.infinity;
    var migliorPercorsi = 0.0;

    for (var i = 0; i < coords.length - 1; i++) {
      final ax = (coords[i][0] - lng) * mPerLng;
      final ay = (coords[i][1] - lat) * mPerLat;
      final bx = (coords[i + 1][0] - lng) * mPerLng;
      final by = (coords[i + 1][1] - lat) * mPerLat;

      final dx = bx - ax;
      final dy = by - ay;
      final len2 = dx * dx + dy * dy;
      // t = frazione [0,1] della proiezione del punto (origine) sul segmento
      final t = len2 == 0
          ? 0.0
          : max(0.0, min(1.0, -(ax * dx + ay * dy) / len2));
      final px = ax + dx * t;
      final py = ay + dy * t;
      final dist = sqrt(px * px + py * py);

      if (dist < migliorDist) {
        migliorDist = dist;
        migliorPercorsi = _cum[i] + (_cum[i + 1] - _cum[i]) * t;
      }
    }

    return ProiezioneRotta(
      distanzaDalPercorsoM: migliorDist,
      metriPercorsi: migliorPercorsi,
    );
  }

  /// Manovra in arrivo per la proiezione data.
  ///
  /// Semantica GraphHopper: l'istruzione i copre il tratto interval[0]..[1];
  /// il suo testo descrive cosa fare ALL'INIZIO del tratto. Quindi mentre si
  /// percorre il tratto dell'istruzione i, la manovra da annunciare e' la
  /// i+1, a distanza (fine tratto i - metri percorsi).
  ManovraCorrente? prossimaManovraDa(ProiezioneRotta p) {
    final istruzioni = route.instructions;
    if (istruzioni.isEmpty || _cum.isEmpty) return null;

    for (var i = 0; i < istruzioni.length - 1; i++) {
      final interval = istruzioni[i].interval;
      if (interval.length < 2) continue;
      final fineIdx = min(interval[1], _cum.length - 1);
      final fineCum = _cum[fineIdx];
      if (p.metriPercorsi <= fineCum + 1) {
        return ManovraCorrente(
          istruzione: istruzioni[i + 1],
          metriRestanti: max(0, (fineCum - p.metriPercorsi).round()),
        );
      }
    }
    // Oltre l'ultimo tratto intermedio: resta l'arrivo (sign 4).
    return ManovraCorrente(istruzione: istruzioni.last, metriRestanti: 0);
  }

  /// Metri mancanti alla fine della rotta (per ETA/riepilogo).
  int metriAllArrivoDa(ProiezioneRotta p) {
    return max(0, (lunghezzaM - p.metriPercorsi).round());
  }

  /// Da chiamare a OGNI fix con la proiezione gia' calcolata: true quando il
  /// driver e' stabilmente fuori dal percorso (oltre [sogliaFuoriPercorsoM]
  /// per [fixFuoriConsecutivi] fix, ignorando i fix con accuracy scarsa) →
  /// il chiamante ricalcola la rotta.
  bool registraProiezione(ProiezioneRotta p, {double? accuracy}) {
    if (accuracy != null && accuracy > accuracyMassimaM) return false;
    if (p.distanzaDalPercorsoM > sogliaFuoriPercorsoM) {
      _fixFuori++;
    } else {
      _fixFuori = 0;
    }
    return _fixFuori >= fixFuoriConsecutivi;
  }

  static double _distanzaM(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const mPerLat = 111320.0;
    final mPerLng = 111320.0 * cos(lat1 * pi / 180);
    final dx = (lng2 - lng1) * mPerLng;
    final dy = (lat2 - lat1) * mPerLat;
    return sqrt(dx * dx + dy * dy);
  }
}
