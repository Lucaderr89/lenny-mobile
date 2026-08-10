import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driver/models/location_point.dart';
import 'package:driver/widgets/nav/nav_map_view.dart';

/// PNG trasparente 1x1: le tile OSM nei test non possono scaricarsi dalla
/// rete (bloccata), quindi si serve questa al posto loro.
final Uint8List _pngTrasparente = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FinteTileHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = _FakeHttpClient();
    return client;
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUrl ||
        invocation.memberName == #openUrl) {
      return Future.value(_FakeRequest());
    }
    return null;
  }
}

class _FakeRequest implements HttpClientRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #close) {
      return Future.value(_FakeResponse());
    }
    if (invocation.memberName == #headers) return _FakeHeaders();
    return null;
  }
}

class _FakeHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_pngTrasparente]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #statusCode) return 200;
    if (invocation.memberName == #contentLength) {
      return _pngTrasparente.length;
    }
    if (invocation.memberName == #compressionState) {
      return HttpClientResponseCompressionState.notCompressed;
    }
    return null;
  }
}

/// Distanza equirettangolare in metri (bastano per le tolleranze del test).
double _metri(LatLng a, LatLng b) {
  const mPerLat = 111320.0;
  final mPerLng = 111320.0 * math.cos(a.latitude * math.pi / 180);
  final dx = (b.longitude - a.longitude) * mPerLng;
  final dy = (b.latitude - a.latitude) * mPerLat;
  return math.sqrt(dx * dx + dy * dy);
}

/// Rotazione normalizzata in [-180, 180].
double _rotNorm(double gradi) {
  var r = gradi % 360;
  if (r > 180) r -= 360;
  if (r < -180) r += 360;
  return r;
}

void main() {
  testWidgets(
      'SIMULAZIONE TRAGITTO: la camera segue e ruota da sola a ogni fix GPS',
      (tester) async {
    HttpOverrides.global = _FinteTileHttpOverrides();
    SharedPreferences.setMockInitialValues({'vista_guida_driver': true});

    final posizione = ValueNotifier<LocationPoint?>(null);
    final controller = MapController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NavMapView(
            posizione: posizione,
            percorso: const [
              LatLng(43.9506, 12.4659),
              LatLng(43.9415, 12.4477),
            ],
            tappeMarkers: const [],
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Tragitto simulato: prima verso SUD (heading 180), poi svolta verso
    // OVEST (heading 270), poi verso NORD (heading 0). Velocita' da guida,
    // cosi' l'heading viene accettato e non congelato.
    final tappe = <(double lat, double lng, double heading)>[
      (43.9506, 12.4659, 180),
      (43.9490, 12.4655, 180),
      (43.9475, 12.4650, 270),
      (43.9473, 12.4620, 270),
      (43.9480, 12.4600, 0),
    ];

    LatLng? centroPrecedente;
    for (final (lat, lng, heading) in tappe) {
      // Il throttle camera (600 ms) usa l'orologio REALE, non quello finto
      // dei test: serve far passare tempo vero prima di ogni fix.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 650)),
      );
      posizione.value = LocationPoint(
        latitude: lat,
        longitude: lng,
        accuracy: 5,
        speed: 30, // km/h: heading valido
        heading: heading,
      );
      await tester.pump(const Duration(milliseconds: 50));

      final camera = controller.camera;
      final pos = LatLng(lat, lng);

      // 1. La camera SEGUE da sola: il centro sta ~150 m avanti al mezzo
      //    lungo la direzione di marcia (mai fermo dov'era prima).
      final distanzaDalMezzo = _metri(pos, camera.center);
      expect(
        distanzaDalMezzo,
        inInclusiveRange(100, 200),
        reason: 'camera a $distanzaDalMezzo m dal mezzo: non sta seguendo',
      );

      // 2. La mappa RUOTA da sola con la direzione di marcia
      //    (rotazione camera = -heading, come Google Maps in guida).
      expect(
        _rotNorm(camera.rotation - (-heading)),
        closeTo(0, 1),
        reason:
            'rotazione ${camera.rotation} per heading $heading: non ruota',
      );

      // 3. E si e' mossa rispetto al fix precedente: inseguimento continuo,
      //    nessun intervento manuale.
      if (centroPrecedente != null) {
        expect(
          _metri(centroPrecedente, camera.center),
          greaterThan(30),
          reason: 'camera ferma tra due fix: non insegue',
        );
      }
      centroPrecedente = camera.center;
    }

    // Chiusura pulita (tile e animazioni residue)
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
